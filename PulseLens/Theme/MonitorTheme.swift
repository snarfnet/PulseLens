import SwiftUI

/// 医療モニター風の配色。黒背景に発光するグリーンの波形＋赤い心拍。
enum Monitor {
    static let bg        = Color(red: 0.03, green: 0.04, blue: 0.05)
    static let panel     = Color(red: 0.07, green: 0.09, blue: 0.10)
    static let panelEdge = Color(red: 0.01, green: 0.02, blue: 0.02)
    static let bezel     = Color(red: 0.14, green: 0.16, blue: 0.17)

    static let line      = Color(red: 0.30, green: 0.98, blue: 0.62)   // 波形グリーン
    static let lineDim   = Color(red: 0.30, green: 0.98, blue: 0.62).opacity(0.14)
    static let grid      = Color(red: 0.20, green: 0.55, blue: 0.40).opacity(0.22)
    static let heart     = Color(red: 0.98, green: 0.28, blue: 0.36)   // 赤い心臓
    static let amber     = Color(red: 0.98, green: 0.74, blue: 0.28)

    /// BPMごとのおおまかな色（安静時の目安・参考）
    static func bpmColor(_ bpm: Int) -> Color {
        switch bpm {
        case ..<50:   return Color(red: 0.45, green: 0.75, blue: 0.98)   // 低い
        case ..<100:  return Color(red: 0.30, green: 0.98, blue: 0.62)   // 正常域
        case ..<120:  return Color(red: 0.98, green: 0.74, blue: 0.28)   // やや高い
        default:      return Color(red: 0.98, green: 0.35, blue: 0.32)   // 高い
        }
    }
}

/// 二言語（日本語／英語）の簡易ローカライズ。
enum L10n {
    static func t(_ ja: String, _ en: String) -> String {
        let code = Locale.preferredLanguages.first ?? "en"
        return code.hasPrefix("ja") ? ja : en
    }
}
