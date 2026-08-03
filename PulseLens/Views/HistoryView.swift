import SwiftUI

/// 計測履歴の一覧＋簡単な棒グラフ。
struct HistoryView: View {
    @ObservedObject var store: PulseStore

    var body: some View {
        NavigationStack {
            ZStack {
                Monitor.bg.ignoresSafeArea()
                if store.records.isEmpty {
                    empty
                } else {
                    List {
                        if let s = store.summary {
                            Section {
                                summaryRow(s)
                            }
                            .listRowBackground(Monitor.panel)
                        }
                        Section(L10n.t("記録", "Records")) {
                            ForEach(store.records) { r in row(r) }
                                .onDelete { idx in
                                    idx.map { store.records[$0] }.forEach(store.delete)
                                }
                        }
                        .listRowBackground(Monitor.panel)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle(L10n.t("履歴", "History"))
            .toolbar {
                if !store.records.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(L10n.t("消去", "Clear"), role: .destructive) { store.clear() }
                            .tint(Monitor.heart)
                    }
                }
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.path.ecg").font(.system(size: 48)).foregroundStyle(Monitor.line.opacity(0.5))
            Text(L10n.t("まだ記録がありません", "No records yet"))
                .foregroundStyle(.gray)
        }
    }

    private func summaryRow(_ s: (avg: Int, min: Int, max: Int)) -> some View {
        HStack {
            stat(L10n.t("平均", "Avg"), s.avg)
            Divider().overlay(Monitor.bezel)
            stat(L10n.t("最小", "Min"), s.min)
            Divider().overlay(Monitor.bezel)
            stat(L10n.t("最大", "Max"), s.max)
        }
        .frame(height: 56)
    }

    private func stat(_ title: String, _ value: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Monitor.bpmColor(value))
            Text(title).font(.caption).foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity)
    }

    private func row(_ r: PulseRecord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(r.date, format: .dateTime.year().month().day().hour().minute())
                    .font(.system(size: 14)).foregroundStyle(.white)
                Text(confidenceText(r.confidence))
                    .font(.caption).foregroundStyle(.gray)
            }
            Spacer()
            Text("\(r.bpm)")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(Monitor.bpmColor(r.bpm))
            Text("BPM").font(.caption2).foregroundStyle(.gray)
        }
    }

    private func confidenceText(_ c: Double) -> String {
        let pct = Int(c * 100)
        return L10n.t("信号 \(pct)%", "Signal \(pct)%")
    }
}
