import Foundation

/// 一轮称重记录。字段对应欧姆龙 HBF-701 的显示项：
/// 体重、体脂肪率、骨骼肌率、皮下脂肪率。
struct ScaleReading: Codable, Identifiable, Equatable {
    var id = UUID()
    var date: Date
    var weightKg: Double?
    var bodyFatPct: Double?
    var skeletalMusclePct: Double? // 骨骼肌率 %
    var subcutaneousFatPct: Double? // 皮下脂肪率 %
    var note: String?

    init(id: UUID = UUID(),
         date: Date = Date(),
         weightKg: Double? = nil,
         bodyFatPct: Double? = nil,
         skeletalMusclePct: Double? = nil,
         subcutaneousFatPct: Double? = nil,
         note: String? = nil) {
        self.id = id
        self.date = date
        self.weightKg = weightKg
        self.bodyFatPct = bodyFatPct
        self.skeletalMusclePct = skeletalMusclePct
        self.subcutaneousFatPct = subcutaneousFatPct
        self.note = note
    }

    private enum CodingKeys: String, CodingKey {
        case id, date, weightKg, bodyFatPct, skeletalMusclePct, subcutaneousFatPct, note
    }

    /// 容错解码：AI 返回的 JSON 只含数值字段，id/date 缺失时用默认值。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        date = try c.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        weightKg = try c.decodeIfPresent(Double.self, forKey: .weightKg)
        bodyFatPct = try c.decodeIfPresent(Double.self, forKey: .bodyFatPct)
        skeletalMusclePct = try c.decodeIfPresent(Double.self, forKey: .skeletalMusclePct)
        subcutaneousFatPct = try c.decodeIfPresent(Double.self, forKey: .subcutaneousFatPct)
        note = try c.decodeIfPresent(String.self, forKey: .note)
    }

    static func empty() -> ScaleReading {
        ScaleReading(date: Date())
    }

    /// 计算骨骼肌（kg）= 体重 × 骨骼肌率。
    /// 苹果健康没有“骨骼肌率”，只支持写入质量类指标，因此换算成 kg 写入。
    var computedSkeletalMuscleKg: Double? {
        guard let weight = weightKg, let rate = skeletalMusclePct else { return nil }
        return weight * rate / 100.0
    }
}

/// 数字显示/解析辅助。
enum Format {
    /// 把数值显示成尽量短的字符串（整数不带小数）。
    static func plain(_ value: Double?) -> String {
        guard let value = value else { return "—" }
        if abs(value - value.rounded()) < 0.000_001 && abs(value) < 1e8 {
            return String(Int(value.rounded()))
        }
        return String(format: "%.1f", value)
    }

    /// 把用户输入解析成 Double，兼容中文/全角标点。
    static func parse(_ text: String) -> Double? {
        var cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "，", with: ".")
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "。", with: ".")
        let fullwidth = "０１２３４５６７８９"
        let halfwidth = "0123456789"
        for (f, h) in zip(fullwidth, halfwidth) {
            cleaned = cleaned.replacingOccurrences(of: String(f), with: String(h))
        }
        guard !cleaned.isEmpty else { return nil }
        return Double(cleaned)
    }

    /// 历史列表里的一行摘要。
    static func listLine(_ r: ScaleReading) -> String {
        var parts: [String] = []
        if let w = r.weightKg { parts.append("体重 \(plain(w)) kg") }
        if let f = r.bodyFatPct { parts.append("体脂 \(plain(f))%") }
        if let m = r.skeletalMusclePct { parts.append("骨骼肌 \(plain(m))%") }
        if let s = r.subcutaneousFatPct { parts.append("皮下脂肪 \(plain(s))%") }
        return parts.isEmpty ? "（无数据）" : parts.joined(separator: " · ")
    }
}
