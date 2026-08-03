import SwiftUI

/// メイン計測画面。波形＋大きなBPM＋拍動ハート＋15秒計測ボタン。
struct MeasureScreen: View {
    @ObservedObject var detector: PulseDetector
    @ObservedObject var store: PulseStore

    var body: some View {
        ZStack {
            Monitor.bg.ignoresSafeArea()
            VStack(spacing: 18) {
                header

                WaveformView(samples: detector.waveform,
                             color: detector.fingerDetected ? bpmColor : Monitor.line.opacity(0.5))
                    .frame(height: 150)
                    .padding(.horizontal)

                bpmDisplay

                statusLine

                Spacer()

                controls
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                disclaimer
            }
            .padding(.top, 8)

            if detector.permissionDenied { permissionOverlay }
        }
        .onAppear {
            detector.onMeasureComplete = { bpm, conf in
                store.add(bpm: bpm, confidence: conf)
            }
            if !detector.isRunning { detector.start() }
        }
    }

    private var bpmColor: Color { Monitor.bpmColor(detector.bpm) }

    private var header: some View {
        HStack {
            Text("PULSE LENS")
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(Monitor.line)
                .tracking(3)
            Spacer()
            HeartView(beatTick: detector.beatTick, color: Monitor.heart)
                .frame(width: 26, height: 26)
        }
        .padding(.horizontal)
    }

    private var bpmDisplay: some View {
        VStack(spacing: 2) {
            Text(detector.bpm > 0 ? "\(detector.bpm)" : "– –")
                .font(.system(size: 92, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(detector.fingerDetected ? bpmColor : Color.gray)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.25), value: detector.bpm)
            Text("BPM")
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundStyle(.gray)
                .tracking(4)
        }
    }

    @ViewBuilder private var statusLine: some View {
        if detector.torchUnavailable {
            label(L10n.t("この端末はフラッシュが使えません", "Flash is unavailable on this device"), Monitor.amber)
        } else if !detector.fingerDetected {
            label(L10n.t("背面カメラとフラッシュに指をそっと当ててください",
                          "Gently cover the rear camera and flash with your finger"), Monitor.amber)
        } else if detector.isMeasuring {
            label(L10n.t("計測中… 動かさないで", "Measuring… hold still"), Monitor.line)
        } else {
            confidenceBar
        }
    }

    private func label(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(color)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .frame(minHeight: 34)
    }

    private var confidenceBar: some View {
        VStack(spacing: 4) {
            Text(L10n.t("信号の安定度", "Signal quality"))
                .font(.system(size: 11))
                .foregroundStyle(.gray)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Monitor.lineDim)
                    Capsule().fill(bpmColor)
                        .frame(width: geo.size.width * detector.confidence)
                }
            }
            .frame(width: 160, height: 6)
        }
        .frame(minHeight: 34)
    }

    private var controls: some View {
        Group {
            if detector.isMeasuring {
                Button(role: .cancel) { detector.cancelMeasurement() } label: {
                    measureButtonLabel(
                        title: "\(Int((1 - detector.measureProgress) * 15) + 1)",
                        subtitle: L10n.t("キャンセル", "Cancel"),
                        progress: detector.measureProgress,
                        color: Monitor.amber)
                }
            } else {
                Button { detector.startMeasurement() } label: {
                    measureButtonLabel(
                        title: L10n.t("計測", "Measure"),
                        subtitle: L10n.t("15秒で記録", "15s & save"),
                        progress: 0,
                        color: detector.fingerDetected ? Monitor.line : Color.gray)
                }
                .disabled(!detector.fingerDetected)
            }
        }
    }

    private func measureButtonLabel(title: String, subtitle: String, progress: Double, color: Color) -> some View {
        ZStack {
            Circle().stroke(Monitor.lineDim, lineWidth: 6)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.2), value: progress)
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.gray)
            }
        }
        .frame(width: 128, height: 128)
    }

    private var disclaimer: some View {
        Text(L10n.t("※医療機器ではありません。安静時の参考値です。",
                    "Not a medical device. For reference at rest only."))
            .font(.system(size: 10))
            .foregroundStyle(.gray.opacity(0.7))
            .padding(.bottom, 4)
    }

    private var permissionOverlay: some View {
        ZStack {
            Monitor.bg.opacity(0.96).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "camera.fill").font(.system(size: 44)).foregroundStyle(Monitor.amber)
                Text(L10n.t("カメラの利用が許可されていません",
                            "Camera access is not allowed"))
                    .font(.headline).foregroundStyle(.white)
                Text(L10n.t("設定 > プライバシー > カメラ から許可してください。",
                            "Enable it in Settings > Privacy > Camera."))
                    .font(.subheadline).foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                Button(L10n.t("設定を開く", "Open Settings")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Monitor.line)
            }
            .padding(32)
        }
    }
}
