import SwiftUI

/// 仕組みの説明とアプリ情報。
struct InfoView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Monitor.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        section(L10n.t("仕組み（PPG）", "How it works (PPG)"),
                                L10n.t("フラッシュの光が指を透過すると、心臓の拍動に合わせて血流量が変わり、透過光の明るさがわずかに周期変動します。カメラでこの明るさの波を捉え、山と山の間隔から脈拍数を計算します。Apple Watchの心拍センサーと同じ光電容積脈波（PPG）の原理です。",
                                       "When flash light passes through your finger, blood volume changes with each heartbeat, slightly modulating the brightness of the transmitted light. The camera captures this wave and computes your pulse from the interval between peaks. This is photoplethysmography (PPG), the same principle as the Apple Watch heart sensor."))

                        section(L10n.t("精度について", "About accuracy"),
                                L10n.t("安静時に正しく指を当てれば、誤差はおおむね数BPM程度です。ただし体を動かす、指が冷えている、外光が入るなどの条件で大きくずれます。運動中の測定には向きません。",
                                       "At rest with proper finger placement, the error is typically a few BPM. It can deviate significantly with movement, cold fingers, or leaking ambient light. It is not suited for measurement during exercise."))

                        section(L10n.t("プライバシー", "Privacy"),
                                L10n.t("カメラ映像は端末内で明るさの解析だけに使い、保存も送信も一切しません。計測結果は端末内にのみ保存されます。",
                                       "Camera frames are used only for on-device brightness analysis and are never saved or transmitted. Results are stored on your device only."))

                        Divider().overlay(Monitor.bezel)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(L10n.t("免責", "Disclaimer")).font(.headline).foregroundStyle(Monitor.heart)
                            Text(L10n.t("本アプリは医療機器ではありません。表示される値は参考情報であり、健康状態の診断・治療を目的としたものではありません。",
                                        "This app is not a medical device. Displayed values are for reference and are not intended to diagnose or treat any health condition."))
                                .font(.footnote).foregroundStyle(.gray)
                        }

                        Text(L10n.t("バージョン 1.0", "Version 1.0"))
                            .font(.caption).foregroundStyle(.gray.opacity(0.6))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 8)
                    }
                    .padding()
                }
            }
            .navigationTitle(L10n.t("情報", "Info"))
        }
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline).foregroundStyle(Monitor.line)
            Text(body).font(.subheadline).foregroundStyle(.gray)
        }
    }
}
