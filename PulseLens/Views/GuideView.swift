import SwiftUI

/// 使い方＋コツ＋免責。
struct GuideView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Monitor.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        step(1, "camera.fill",
                             L10n.t("指を当てる", "Cover the lens"),
                             L10n.t("背面カメラのレンズとフラッシュを、人差し指の腹でそっと覆います。強く押しすぎないでください。",
                                    "Gently cover the rear camera lens and flash with the pad of your finger. Do not press too hard."))
                        step(2, "hand.raised.fill",
                             L10n.t("動かさない", "Hold still"),
                             L10n.t("画面に波形が出たら、腕と指を動かさず数秒待ちます。座って安静にすると精度が上がります。",
                                    "Once the waveform appears, keep your arm and finger still for a few seconds. Sitting at rest improves accuracy."))
                        step(3, "waveform.path.ecg",
                             L10n.t("計測ボタン", "Tap Measure"),
                             L10n.t("「計測」を押すと15秒間平均して結果を履歴に保存します。",
                                    "Tap Measure to average over 15 seconds and save the result to history."))

                        Divider().overlay(Monitor.bezel)

                        tip(L10n.t("うまく測れないとき", "If it doesn't work"),
                            L10n.t("・指が冷えていると信号が弱くなります。温めてから試してください。\n・明るい部屋では外光が入らないよう、しっかり覆ってください。\n・爪ではなく指の腹で当ててください。",
                                   "• Cold fingers give a weak signal—warm them first.\n• In bright rooms, cover fully so outside light does not leak in.\n• Use the finger pad, not the nail."))

                        disclaimer
                    }
                    .padding()
                }
            }
            .navigationTitle(L10n.t("使い方", "How to use"))
        }
    }

    private func step(_ n: Int, _ icon: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(Monitor.lineDim).frame(width: 40, height: 40)
                Image(systemName: icon).foregroundStyle(Monitor.line)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("\(n). \(title)").font(.headline).foregroundStyle(.white)
                Text(body).font(.subheadline).foregroundStyle(.gray)
            }
        }
    }

    private func tip(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline).foregroundStyle(Monitor.amber)
            Text(body).font(.subheadline).foregroundStyle(.gray)
        }
    }

    private var disclaimer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.t("ご注意", "Important")).font(.headline).foregroundStyle(Monitor.heart)
            Text(L10n.t("このアプリは医療機器ではありません。測定値はあくまで参考で、診断・治療には使えません。体調に不安があるときは医療機関を受診してください。",
                        "This app is not a medical device. Readings are for reference only and cannot be used for diagnosis or treatment. If you feel unwell, consult a medical professional."))
                .font(.footnote).foregroundStyle(.gray)
        }
    }
}
