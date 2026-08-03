import SwiftUI

/// 心電図モニター風の波形。detector.waveform（-1…1）を左から右へ流れる折れ線で描く。
struct WaveformView: View {
    let samples: [CGFloat]
    var color: Color = Monitor.line

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // 背景グリッド
                Path { p in
                    let cols = 12, rows = 4
                    for c in 0...cols {
                        let x = w * CGFloat(c) / CGFloat(cols)
                        p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: h))
                    }
                    for r in 0...rows {
                        let y = h * CGFloat(r) / CGFloat(rows)
                        p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: w, y: y))
                    }
                }
                .stroke(Monitor.grid, lineWidth: 0.5)

                // 波形（下方向に振れると山になるよう反転）
                Path { p in
                    guard samples.count > 1 else { return }
                    let dx = w / CGFloat(samples.count - 1)
                    for (i, v) in samples.enumerated() {
                        let x = CGFloat(i) * dx
                        let y = h * 0.5 - v * h * 0.42
                        if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                        else { p.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                .shadow(color: color.opacity(0.7), radius: 4)
            }
        }
        .background(Monitor.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Monitor.bezel, lineWidth: 1))
    }
}
