import UIKit
import Foundation

/// AI 服务配置（OpenAI 兼容 chat/completions，支持多图）。
struct AIConfig {
    var baseURL: String
    var model: String
    var apiKey: String
}

enum AIServiceError: LocalizedError {
    case emptyKey
    case badURL
    case network(String)
    case httpStatus(Int, String)
    case noContent
    case badResponse(String)

    var errorDescription: String? {
        switch self {
        case .emptyKey:
            return "还没有配置 API Key，请先到“设置”里填写并保存。"
        case .badURL:
            return "API 地址格式不正确。"
        case .network(let s):
            return "网络请求失败：\(s)"
        case .httpStatus(let code, let body):
            return "AI 服务返回错误(\(code))：\(body)"
        case .noContent:
            return "AI 服务没有返回可识别的内容，请重试。"
        case .badResponse(let s):
            return "识别结果解析失败，请重试或手动填写。AI 原文：\(s)"
        }
    }
}

struct AIService {
    /// 发给视觉模型的提示词（按实测的中文版 HBF-701 界面撰写）。
    private static let prompt = """
    你是欧姆龙 HBF-701（中文版，Karada Scan 体组成计）的屏幕读数识别助手。这台秤测完后按键逐屏翻页，我会给你这一轮拍下的多张屏幕照片（一屏一张），请把全部读数汇总成一轮结果。

    【屏幕布局】每张照片上大致有两块数字：
    (A) 中间的大数字，它的中文标签在数字上方或右侧；
    (B) 画面下方固定有两个小数字：左边标签是「皮下脂肪率」，右边标签是「肌肉率」（单位都是 %）。

    (A) 大数字可能是下面六项之一（按它旁边的标签判断）：
    - 体重：单位 kg
    - 身体年龄：单位 岁
    - BMI：无单位
    - 基础代谢：单位 kcal
    - 身体脂肪率：单位 %（标签是“身体脂肪率”，它不是下方的“皮下脂肪率”）
    - 内脏脂肪指数：无单位，**固定显示为“整数.一位小数”的格式**，例如 14.0、9.0、1.0

    (B) 下方那两个小数属于**当前被高亮/框选的部位**。部位名称在屏幕上就是四个词：
        全身 、上肢 、躯干 、下肢
    其中被框选（加深边框/高亮）的那一个就是当前部位。请据此填写：
    - 框选「全身」的照片 → subcutaneousFatPct / skeletalMusclePct
    - 框选「上肢」的照片 → armsSubcutaneousFatPct / armsSkeletalMusclePct
    - 框选「躯干」的照片 → trunkSubcutaneousFatPct / trunkSkeletalMusclePct
    - 框选「下肢」的照片 → legsSubcutaneousFatPct / legsSkeletalMusclePct

    【重要】判断部位一律以屏幕上**被框选的那个词**为准，不要按照片先后顺序去猜；若某张照片看不出框选了哪个部位，就跳过它，不要硬填。

    读数规则：
    1. 【小数点是重中之重】屏幕上的小数点是两个数字之间一个很小的点：
       · 内脏脂肪指数一定是“整数.一位小数”，如「14.0」；若只看到「14」，请再仔细找小数点
       · 「1.0」不是「10」；「14.0」不是「140」；「25.8」不是「258」
       · 实在看不清小数位就填 null，不要猜。
    2. 不要把大数字和下方两个小数字搞混；也不要把中文标签、图示、图标当成读数。
    3. 合理范围（明显超出说明看错了）：
       体重 20~200 kg｜身体脂肪率 3~60%｜身体年龄 5~90 岁｜BMI 10~50｜
       基础代谢 500~4000 kcal｜内脏脂肪指数 1~30｜皮下脂肪率 3~60%｜肌肉率 10~70%
    4. 「身体脂肪率」（大数字，全身总体脂）与「皮下脂肪率」（下方小数字，按部位）是两个不同指标，不要混。
    5. 内脏脂肪指数会在多张照片里重复出现且数值相同，只记一次。
    6. 某字段在所有照片里都没出现或看不清，填 null。

    另外：请在 note 字段里写一句你实际读到的原文（例如「内脏14.0；全身 皮下18.7/肌肉32.8；上肢 23.4/36.3」），方便我核对。

    只输出一个 JSON 对象，不要任何解释文字，不要用 ``` 包裹，字段名必须完全一致：
    {"weightKg": null,"bodyFatPct": null,"bodyAge": null,"bmi": null,"basalMetabolismKcal": null,"visceralFatLevel": null,"subcutaneousFatPct": null,"skeletalMusclePct": null,"armsSubcutaneousFatPct": null,"armsSkeletalMusclePct": null,"trunkSubcutaneousFatPct": null,"trunkSkeletalMusclePct": null,"legsSubcutaneousFatPct": null,"legsSkeletalMusclePct": null,"note": ""}
    """

    /// 把若干张屏幕照片交给视觉模型，解析成一条记录。
    func readReading(images: [UIImage], config: AIConfig) async throws -> ScaleReading {
        guard !config.apiKey.isEmpty else { throw AIServiceError.emptyKey }
        let base = config.baseURL.hasSuffix("/") ? config.baseURL : config.baseURL + "/"
        guard let url = URL(string: base + "chat/completions") else { throw AIServiceError.badURL }

        var content: [[String: Any]] = [
            ["type": "text", "text": Self.prompt]
        ]
        for image in images {
            guard let jpg = image.jpegDataForAI() else { continue }
            content.append([
                "type": "image_url",
                "image_url": ["url": "data:image/jpeg;base64,\(jpg.base64EncodedString())"]
            ])
        }
        guard content.count > 1 else { throw AIServiceError.noContent }

        let payload: [String: Any] = [
            "model": config.model,
            "temperature": 0.1,
            "messages": [["role": "user", "content": content]]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AIServiceError.network(error.localizedDescription)
        }

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let raw = String(data: data, encoding: .utf8) ?? ""
            let snippet = raw.count > 300 ? String(raw.prefix(300)) : raw
            throw AIServiceError.httpStatus(http.statusCode, snippet)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let text = message["content"] as? String,
              !text.isEmpty
        else {
            throw AIServiceError.noContent
        }

        let decoder = JSONDecoder()
        if let object = Self.extractJSONObject(from: text),
           let objectData = object.data(using: .utf8),
           let reading = try? decoder.decode(ScaleReading.self, from: objectData) {
            return reading
        }
        throw AIServiceError.badResponse(String(text.prefix(300)))
    }

    /// 从模型输出里抠出第一个 { ... } 片段（容忍前后废话与 ``` 围栏）。
    private static func extractJSONObject(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}"),
              start < end else { return nil }
        return String(text[start...end])
    }
}
