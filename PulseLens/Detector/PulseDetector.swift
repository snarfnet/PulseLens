import AVFoundation
import CoreVideo
import Combine
import UIKit

/// 背面カメラ＋フラッシュ（トーチ）を使った光電容積脈波（PPG）方式の脈拍計。
///
/// 原理: レンズにそっと指を当ててフラッシュを点けると、光が指を透過してカメラに届く。
/// 心臓が拍動するたびに指先の血流量が変わり、透過光（とくに赤成分）の明るさが周期的に変動する。
/// この明るさの波を1フレームずつ拾い、山（拍動）の間隔から1分あたりの脈拍数（BPM）を求める。
///
/// ★これは医療機器ではない。安静時のおおよその脈拍を知るための参考・エンタメ用途。
///  体を動かすと大きくずれる。診断・治療には使えない。
final class PulseDetector: NSObject, ObservableObject {

    // MARK: - 公開状態（UIが監視）
    @Published private(set) var isRunning = false
    @Published private(set) var bpm: Int = 0                 // 0 = 計測中／未確定
    @Published private(set) var fingerDetected = false
    @Published private(set) var confidence: Double = 0       // 0–1（拍動間隔の安定度）
    @Published private(set) var permissionDenied = false
    @Published private(set) var torchUnavailable = false

    /// 波形表示用（-1…1に正規化した直近サンプル）。UIがそのまま折れ線に描く。
    @Published private(set) var waveform: [CGFloat] = Array(repeating: 0, count: PulseDetector.waveCount)

    /// 拍動が起きた瞬間に更新（ハートのアニメーション用トリガ）。
    @Published private(set) var beatTick: Int = 0

    /// タイマー計測モードの状態。
    @Published private(set) var isMeasuring = false
    @Published private(set) var measureProgress: Double = 0  // 0–1

    /// 計測完了時に確定BPMを渡す（履歴保存はUI側）。
    var onMeasureComplete: ((_ bpm: Int, _ confidence: Double) -> Void)?

    static let waveCount = 180

    // MARK: - 内部（カメラ）
    private let session = AVCaptureSession()
    private let videoQueue = DispatchQueue(label: "pulselens.video", qos: .userInitiated)
    private let output = AVCaptureVideoDataOutput()
    private var device: AVCaptureDevice?

    // MARK: - 内部（信号処理）
    /// 2本の指数移動平均の差でバンドパスを近似する（速い平滑 − 遅いベースライン）。
    private var emaFast = 0.0
    private var emaSlow = 0.0
    private var envelope = 1.0          // 振幅の目安（波形正規化＆しきい値に使う）
    private var prevBandpass = 0.0
    private var initialized = false
    private var lastTime: CFTimeInterval = 0
    private var startTime: CFTimeInterval = 0

    private var lastBeatTime: CFTimeInterval = 0
    private var intervals: [Double] = []    // 直近の拍動間隔（秒）

    private var waveBuffer = [CGFloat](repeating: 0, count: PulseDetector.waveCount)
    private var wasFingerOn = false

    /// タイマー計測
    private var measuring = false
    private var measureStart: CFTimeInterval = 0
    private let measureSeconds: CFTimeInterval = 15
    private var measureBpms: [Double] = []

    // 平滑の時定数（秒）。fast=拍動を残す、slow=ゆっくりしたベースライン。
    private let tauFast = 0.12
    private let tauSlow = 0.80
    private let refractory = 0.33           // これ以内の連続検出は無視（≒最大180BPM）

    override init() { super.init() }

    /// スクリーンショット用のダミー表示（シミュレータではカメラが動かない）。
    func loadDemoState() {
        isRunning = true
        fingerDetected = true
        bpm = 72
        confidence = 0.86
        beatTick = 1
        var w = [CGFloat](repeating: 0, count: PulseDetector.waveCount)
        for i in 0..<w.count {
            let t = Double(i) / Double(w.count) * 6 * .pi
            w[i] = CGFloat(sin(t) * 0.6 + sin(t * 2) * 0.15)
        }
        waveform = w
    }

    // MARK: - 起動 / 停止
    func start() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self else { return }
            if !granted {
                DispatchQueue.main.async { self.permissionDenied = true }
                return
            }
            self.videoQueue.async { self.configureAndRun() }
        }
    }

    func stop() {
        videoQueue.async {
            self.setTorch(false)
            if self.session.isRunning { self.session.stopRunning() }
            DispatchQueue.main.async { self.isRunning = false }
        }
    }

    private func configureAndRun() {
        if session.isRunning { return }
        session.beginConfiguration()
        session.sessionPreset = .vga640x480

        guard let cam = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: cam),
              session.canAddInput(input) else {
            session.commitConfiguration()
            DispatchQueue.main.async { self.permissionDenied = true }
            return
        }
        session.addInput(input)
        device = cam

        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: videoQueue)
        if session.canAddOutput(output) { session.addOutput(output) }

        session.commitConfiguration()

        configureCamera(cam)
        setTorch(true)
        resetSignal()
        session.startRunning()
        DispatchQueue.main.async { self.isRunning = true }
    }

    /// フォーカスとホワイトバランスを固定（自動調整で明るさが揺れるのを防ぐ）。
    private func configureCamera(_ cam: AVCaptureDevice) {
        do {
            try cam.lockForConfiguration()
            if cam.isFocusModeSupported(.locked) { cam.focusMode = .locked }
            if cam.isWhiteBalanceModeSupported(.locked) { cam.whiteBalanceMode = .locked }
            // 露出は指を当てた明るさに合わせて後で固定する。まずは自動で追従。
            if cam.isExposureModeSupported(.continuousAutoExposure) {
                cam.exposureMode = .continuousAutoExposure
            }
            cam.unlockForConfiguration()
        } catch { }
    }

    /// 指を当てた瞬間の露出で固定する（拍動の微小変化を潰さないため）。
    private func lockExposure() {
        guard let cam = device else { return }
        do {
            try cam.lockForConfiguration()
            if cam.isExposureModeSupported(.locked) { cam.exposureMode = .locked }
            cam.unlockForConfiguration()
        } catch { }
    }

    private func setTorch(_ on: Bool) {
        guard let cam = device, cam.hasTorch, cam.isTorchAvailable else {
            if on { DispatchQueue.main.async { self.torchUnavailable = true } }
            return
        }
        do {
            try cam.lockForConfiguration()
            if on {
                try cam.setTorchModeOn(level: min(0.7, AVCaptureDevice.maxAvailableTorchLevel))
            } else {
                cam.torchMode = .off
            }
            cam.unlockForConfiguration()
        } catch { }
    }

    private func resetSignal() {
        initialized = false
        emaFast = 0; emaSlow = 0; envelope = 1; prevBandpass = 0
        lastBeatTime = 0; startTime = 0
        intervals.removeAll()
        waveBuffer = [CGFloat](repeating: 0, count: PulseDetector.waveCount)
    }

    // MARK: - タイマー計測（15秒平均）
    func startMeasurement() {
        videoQueue.async {
            self.measureBpms.removeAll()
            self.measureStart = CACurrentMediaTime()
            self.measuring = true
            DispatchQueue.main.async {
                self.isMeasuring = true
                self.measureProgress = 0
            }
        }
    }

    func cancelMeasurement() {
        videoQueue.async {
            self.measuring = false
            DispatchQueue.main.async {
                self.isMeasuring = false
                self.measureProgress = 0
            }
        }
    }

    // MARK: - フレーム解析
    private func analyze(_ pixelBuffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let stride = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let ptr = base.assumingMemoryBound(to: UInt8.self)

        // 中央のROIだけを平均（周辺は指の当たりムラが大きい）。BGRA順。
        let rx0 = width * 3 / 8, rx1 = width * 5 / 8
        let ry0 = height * 3 / 8, ry1 = height * 5 / 8
        let step = 3
        var sumR: UInt64 = 0, sumG: UInt64 = 0, sumB: UInt64 = 0, n: UInt64 = 0
        var y = ry0
        while y < ry1 {
            let row = y * stride
            var x = rx0
            while x < rx1 {
                let p = row + x * 4
                sumB &+= UInt64(ptr[p])
                sumG &+= UInt64(ptr[p + 1])
                sumR &+= UInt64(ptr[p + 2])
                n &+= 1
                x += step
            }
            y += step
        }
        guard n > 0 else { return }
        let r = Double(sumR) / Double(n)
        let g = Double(sumG) / Double(n)
        let b = Double(sumB) / Double(n)

        handle(red: r, green: g, blue: b)
    }

    private func handle(red r: Double, green g: Double, blue b: Double) {
        let now = CACurrentMediaTime()

        // 指が当たっているか（フラッシュ光が指を透過すると赤が支配的で十分明るい）
        let fingerOn = r > 90 && r > b * 1.5 && r > g * 1.3

        if fingerOn != wasFingerOn {
            wasFingerOn = fingerOn
            if fingerOn {
                resetSignal()
                startTime = now
                lockExposure()
            }
            DispatchQueue.main.async { self.fingerDetected = fingerOn }
        }

        guard fingerOn else {
            DispatchQueue.main.async {
                self.confidence = 0
                if self.bpm != 0 { self.bpm = 0 }
            }
            return
        }

        // バンドパス（fast − slow のEMA）
        if !initialized {
            emaFast = r; emaSlow = r; lastTime = now; initialized = true
            return
        }
        let dt = max(1.0 / 120.0, min(0.1, now - lastTime))
        lastTime = now
        emaFast += (dt / (dt + tauFast)) * (r - emaFast)
        emaSlow += (dt / (dt + tauSlow)) * (r - emaSlow)
        let bp = emaFast - emaSlow

        // 振幅エンベロープ（ゆっくり減衰しつつ最大に追従）
        let mag = abs(bp)
        if mag > envelope { envelope += 0.3 * (mag - envelope) }
        else { envelope += 0.02 * (mag - envelope) }
        envelope = max(envelope, 0.5)

        // 波形バッファへ（-1…1）
        let norm = CGFloat(max(-1.5, min(1.5, bp / envelope)))
        waveBuffer.removeFirst()
        waveBuffer.append(norm)

        // 立ち上がりゼロ交差で拍動を検出（最初の2秒はウォームアップ）
        var beat = false
        let warmedUp = (now - startTime) > 2.0
        let threshold = envelope * 0.15
        if warmedUp,
           prevBandpass <= 0, bp > 0, mag > threshold,
           (now - lastBeatTime) > refractory {
            if lastBeatTime > 0 {
                let iv = now - lastBeatTime
                if iv > 0.3 && iv < 2.0 {          // 30–200 BPM の範囲だけ採用
                    intervals.append(iv)
                    if intervals.count > 8 { intervals.removeFirst() }
                    beat = true
                }
            }
            lastBeatTime = now
        }
        prevBandpass = bp

        // BPMと信頼度
        var currentBpm = 0
        var conf = 0.0
        if intervals.count >= 3 {
            let sorted = intervals.sorted()
            let median = sorted[sorted.count / 2]
            currentBpm = Int((60.0 / median).rounded())
            let mean = intervals.reduce(0, +) / Double(intervals.count)
            let variance = intervals.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(intervals.count)
            let cv = mean > 0 ? sqrt(variance) / mean : 1        // 変動係数（小さいほど安定）
            conf = max(0, min(1, 1 - cv * 3))
        }

        // タイマー計測の集計
        if measuring {
            if currentBpm > 0 && conf > 0.3 { measureBpms.append(Double(currentBpm)) }
            let elapsed = now - measureStart
            let progress = min(1, elapsed / measureSeconds)
            if elapsed >= measureSeconds {
                measuring = false
                let result = finalizeMeasurement()
                DispatchQueue.main.async {
                    self.isMeasuring = false
                    self.measureProgress = 1
                    if let (finalBpm, finalConf) = result {
                        self.onMeasureComplete?(finalBpm, finalConf)
                    }
                }
            } else {
                DispatchQueue.main.async { self.measureProgress = progress }
            }
        }

        let wave = waveBuffer
        DispatchQueue.main.async {
            self.waveform = wave
            if currentBpm > 0 { self.bpm = currentBpm }
            self.confidence = conf
            if beat { self.beatTick &+= 1 }
        }
    }

    /// 計測ウィンドウ内のBPM群から外れ値を除いた中央値を確定値にする。
    private func finalizeMeasurement() -> (Int, Double)? {
        guard measureBpms.count >= 3 else { return nil }
        let sorted = measureBpms.sorted()
        let median = sorted[sorted.count / 2]
        // 中央値から±15%以内のものだけで平均
        let kept = measureBpms.filter { abs($0 - median) <= median * 0.15 }
        guard !kept.isEmpty else { return nil }
        let avg = kept.reduce(0, +) / Double(kept.count)
        let conf = min(1, Double(kept.count) / Double(measureBpms.count))
        return (Int(avg.rounded()), conf)
    }
}

extension PulseDetector: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        analyze(pb)
    }
}
