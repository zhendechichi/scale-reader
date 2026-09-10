import Foundation

/// 一轮称重记录。字段对应欧姆龙 HBF-701（Karada Scan）按键逐屏显示的 10 屏数据：
/// 1 体重 / 2 体脂肪率 / 3 身体年龄 / 4 BMI / 5 基础代谢 / 6 内脏脂肪等级
/// 7~10 为「部位」屏：全身、双臂、躯干、双脚，每屏同时显示 皮下脂肪率 + 骨骼肌率。
struct ScaleReading: Codable, Identifiable, Equatable {
    var id = UUID()
    var date: Date

    // 单项屏
    var weightKg: Double?
    var bodyFatPct: Double?
    var bodyAge: Double? // 身体年龄（岁）
    var bmi: Double?
    var basalMetabolismKcal: Double? // 基础代谢 kcal
    var visceralFatLevel: Double? // 内脏脂肪等级

    // 部位屏 —— 全身
    var subcutaneousFatPct: Double? // 皮下脂肪率 %
    var skeletalMusclePct: Double? // 骨骼肌率 %

    // 部位屏 —— 双臂（日文显示「腕」）
    var armsSubcutaneousFatPct: Double?
    var armsSkeletalMusclePct: Double?

    // 部位屏 —— 躯干（日文显示「体幹」）
    var trunkSubcutaneousFatPct: Double?
    var trunkSkeletalMusclePct: Double?

    // 部位屏 —— 双脚（日文显示「脚」）
    var legsSubcutaneousFatPct: Double?
    var legsSkeletalMusclePct: Double?

    var note: String?

    init(id: UUID = UUID(),
         date: Date = Date(),
         weightKg: Double? = nil,
         bodyFatPct: Double? = nil,
         bodyAge: Double? = nil,
         bmi: Double? = nil,
         basalMetabolismKcal: Double? = nil,
         visceralFatLevel: Double? = nil,
         subcutaneousFatPct: Double? = nil,
         skeletalMusclePct: Double? = nil,
         armsSubcutaneousFatPct: Double? = nil,
         armsSkeletalMusclePct: Double? = nil,
         trunkSubcutaneousFatPct: Double? = nil,
         trunkSkeletalMusclePct: Double? = nil,
         legsSubcutaneousFatPct: Double? = nil,
         legsSkeletalMusclePct: Double? = nil,
         note: String? = nil) {
        self.id = id
        self.date = date
        self.weightKg = weightKg
        self.bodyFatPct = bodyFatPct
        self.bodyAge = bodyAge
        self.bmi = bmi
        self.basalMetabolismKcal = basalMetabolismKcal
        self.visceralFatLevel = visceralFatLevel
        self.subcutaneousFatPct = subcutaneousFatPct
        self.skeletalMusclePct = skeletalMusclePct
        self.armsSubcutaneousFatPct = armsSubcutaneousFatPct
        self.armsSkeletalMusclePct = armsSkeletalMusclePct
        self.trunkSubcutaneousFatPct = trunkSubcutaneousFatPct
        self.trunkSkeletalMusclePct = trunkSkeletalMusclePct
        self.legsSubcutaneousFatPct = legsSubcutaneousFatPct
        self.legsSkeletalMusclePct = legsSkeletalMusclePct
        self.note = note
    }

    private enum CodingKeys: String, CodingKey {
        case id, date, weightKg, bodyFatPct, bodyAge, bmi, basalMetabolismKcal, visceralFatLevel
        case subcutaneousFatPct, skeletalMusclePct
        case armsSubcutaneousFatPct, armsSkeletalMusclePct
        case trunkSubcutaneousFatPct, trunkSkeletalMusclePct
        case legsSubcutaneousFatPct, legsSkeletalMusclePct
        case note
    }

    /// 容错解码：AI 返回的 JSON 只含数值字段，id/date 缺失时用默认值。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        date = try c.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        weightKg = try c.decodeIfPresent(Double.self, forKey: .weightKg)
        bodyFatPct = try c.decodeIfPresent(Double.self, forKey: .bodyFatPct)
        bodyAge = try c.decodeIfPresent(Double.self, forKey: .bodyAge)
        bmi = try c.decodeIfPresent(Double.self, forKey: .bmi)
        basalMetabolismKcal = try c.decodeIfPresent(Double.self, forKey: .basalMetabolismKcal)
        visceralFatLevel = try c.decodeIfPresent(Double.self, forKey: .visceralFatLevel)
        subcutaneousFatPct = try c.decodeIfPresent(Double.self, forKey: .subcutaneousFatPct)
        skeletalMusclePct = try c.decodeIfPresent(Double.self, forKey: .skeletalMusclePct)
        armsSubcutaneousFatPct = try c.decodeIfPresent(Double.self, forKey: .armsSubcutaneousFatPct)
        armsSkeletalMusclePct = try c.decodeIfPresent(Double.self, forKey: .armsSkeletalMusclePct)
        trunkSubcutaneousFatPct = try c.decodeIfPresent(Double.self, forKey: .trunkSubcutaneousFatPct)
        trunkSkeletalMusclePct = try c.decodeIfPresent(Double.self, forKey: .trunkSkeletalMusclePct)
        legsSubcutaneousFatPct = try c.decodeIfPresent(Double.self, forKey: .legsSubcutaneousFatPct)
        legsSkeletalMusclePct = try c.decodeIfPresent(Double.self, forKey: .legsSkeletalMusclePct)
        note = try c.decodeIfPresent(String.self, forKey: .note)
    }

    static func empty() -> ScaleReading {
        ScaleReading(date: Date())
    }

    /// 是否至少有一项数据（用于启用保存按钮）。
    var hasAnyValue: Bool {
        weightKg != nil || bodyFatPct != nil || bodyAge != nil || bmi != nil
            || basalMetabolismKcal != nil || visceralFatLevel != nil
            || subcutaneousFatPct != nil || skeletalMusclePct != nil
            || armsSubcutaneousFatPct != nil || armsSkeletalMusclePct != nil
            || trunkSubcutaneousFatPct != nil || trunkSkeletalMusclePct != nil
            || legsSubcutaneousFatPct != nil || legsSkeletalMusclePct != nil
    }

    /// 计算骨骼肌（kg）= 体重 × 全身骨骼肌率。
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

    /// 历史列表里的一行摘要（只放主要几项，避免过长）。
    static func listLine(_ r: ScaleReading) -> String {
        var parts: [String] = []
        if let v = r.weightKg { parts.append("体重 \(plain(v)) kg") }
        if let v = r.bodyFatPct { parts.append("体脂 \(plain(v))%") }
        if let v = r.skeletalMusclePct { parts.append("骨骼肌 \(plain(v))%") }
        if let v = r.subcutaneousFatPct { parts.append("皮下脂肪 \(plain(v))%") }
        if let v = r.visceralFatLevel { parts.append("内脏脂肪 \(plain(v))") }
        if let v = r.bmi { parts.append("BMI \(plain(v))") }
        if let v = r.basalMetabolismKcal { parts.append("基础代谢 \(plain(v)) kcal") }
        if let v = r.bodyAge { parts.append("身体年龄 \(plain(v)) 岁") }
        return parts.isEmpty ? "（无数据）" : parts.joined(separator: " · ")
    }
}
