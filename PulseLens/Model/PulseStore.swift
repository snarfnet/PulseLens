import Foundation
import Combine

/// 1回の計測結果。
struct PulseRecord: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var bpm: Int
    var confidence: Double
}

/// 計測履歴をUserDefaultsに永続化する。
final class PulseStore: ObservableObject {
    @Published private(set) var records: [PulseRecord] = []

    private let key = "pulse.records.v1"

    init() { load() }

    func add(bpm: Int, confidence: Double) {
        let r = PulseRecord(date: Date(), bpm: bpm, confidence: confidence)
        records.insert(r, at: 0)
        if records.count > 200 { records.removeLast(records.count - 200) }
        save()
    }

    func delete(_ record: PulseRecord) {
        records.removeAll { $0.id == record.id }
        save()
    }

    func clear() {
        records.removeAll()
        save()
    }

    /// 直近の平均・最小・最大（表示用）。
    var summary: (avg: Int, min: Int, max: Int)? {
        guard !records.isEmpty else { return nil }
        let bpms = records.map(\.bpm)
        return (bpms.reduce(0, +) / bpms.count, bpms.min()!, bpms.max()!)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([PulseRecord].self, from: data) else { return }
        records = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    /// スクリーンショット用のダミー履歴。
    func loadDemoState() {
        let now = Date()
        records = [
            PulseRecord(date: now.addingTimeInterval(-3600), bpm: 72, confidence: 0.9),
            PulseRecord(date: now.addingTimeInterval(-7200), bpm: 68, confidence: 0.85),
            PulseRecord(date: now.addingTimeInterval(-90000), bpm: 81, confidence: 0.7),
            PulseRecord(date: now.addingTimeInterval(-176400), bpm: 75, confidence: 0.88)
        ]
    }
}
