import Foundation
import Combine

/// 本地记录仓库：JSON 持久化到 Documents。
@MainActor
final class RecordStore: ObservableObject {
    @Published private(set) var readings: [ScaleReading] = []

    private var fileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("readings.json")
    }

    init() {
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let decoded = try? decoder.decode([ScaleReading].self, from: data) else { return }
        readings = decoded.sorted { $0.date > $1.date }
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(readings) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    /// 新增或按 id 覆盖。
    func upsert(_ reading: ScaleReading) {
        if let idx = readings.firstIndex(where: { $0.id == reading.id }) {
            readings[idx] = reading
        } else {
            readings.append(reading)
        }
        readings.sort { $0.date > $1.date }
        save()
    }

    func delete(_ reading: ScaleReading) {
        readings.removeAll { $0.id == reading.id }
        save()
    }

    func deleteAll() {
        readings.removeAll()
        save()
    }

    /// 按时间升序，供趋势图使用。
    var ascending: [ScaleReading] {
        readings.sorted { $0.date < $1.date }
    }
}
