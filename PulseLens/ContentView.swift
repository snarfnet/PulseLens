import SwiftUI

struct ContentView: View {
    @StateObject private var detector = PulseDetector()
    @StateObject private var store = PulseStore()
    @State private var selection = 0

    /// スクリーンショット撮影モード（起動引数 SCREENSHOT_MODE_N）。1=計測 2=履歴 3=使い方 4=情報
    private static var screenshotMode: Int? {
        for arg in CommandLine.arguments {
            if arg.hasPrefix("SCREENSHOT_MODE_"), let n = Int(arg.dropFirst("SCREENSHOT_MODE_".count)) {
                return n
            }
        }
        return nil
    }

    var body: some View {
        TabView(selection: $selection) {
            MeasureScreen(detector: detector, store: store)
                .tabItem { Label(L10n.t("計測", "Measure"), systemImage: "heart.text.square") }
                .tag(0)

            HistoryView(store: store)
                .tabItem { Label(L10n.t("履歴", "History"), systemImage: "chart.xyaxis.line") }
                .tag(1)

            GuideView()
                .tabItem { Label(L10n.t("使い方", "Guide"), systemImage: "book") }
                .tag(2)

            InfoView()
                .tabItem { Label(L10n.t("情報", "Info"), systemImage: "info.circle") }
                .tag(3)
        }
        .tint(Monitor.line)
        .preferredColorScheme(.dark)
        .onAppear {
            guard let mode = Self.screenshotMode else { return }
            detector.loadDemoState()
            store.loadDemoState()
            selection = min(max(mode - 1, 0), 3)
        }
        .onDisappear { detector.stop() }
    }
}
