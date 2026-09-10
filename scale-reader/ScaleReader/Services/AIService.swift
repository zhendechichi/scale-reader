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
    /// 发给视觉模型的提示词。
    private static let prompt = """
    你是欧姆龙 HBF-701（中文版，Karada Scan 体组成计）屏幕读数识别助手。这台秤测完后要按键逐屏翻页，一轮测量约 10 屏。我会给你这一轮拍下的所有屏幕照片（一屏一张），请把全部读数汇总成一轮结果。

    第 1~6 屏，每屏只有一个大数字：
    - 体重：单位 kg
    - 体脂肪率：单位 %
    - 身体年龄：单位 岁
    - BMI：无单位
    - 基础代谢：单位 kcal
    - 内脏脂肪等级：无单位整数，如 1~30

    第 7~10 屏，每屏**同时显示两个值**：一边是「皮下脂肪率」，另一边是「骨骼肌率」，单位都是 %。
    这 4 屏分别对应 4 个部位，请按屏幕上的人体图示判断部位，把两个数分别填到对应字段：
    - 全身 → subcutaneousFatPct / skeletalMusclePct
    - 双臂（手臂）→ armsSubcutaneousFatPct / armsSkeletalMusclePct
    - 躯干（身躯、身体中段）→ trunkSubcutaneousFatPct / trunkSkeletalMusclePct
    - 双脚（腿部）→ legsSubcutaneousFatPct / legsSkeletalMusclePct

    判断部位的依据（两者结合看）：
    1. 人体图示中被高亮/点亮的部位：整个人形=全身；双臂伸出并有一条横杠=双臂；只有躯干部分=躯干；只有腿部=双脚。
    2. 图示上方标签行「全身 / 双臂 / 躯干 / 双脚」中被选中（加括号或高亮）的那个词。

    另外：第 7~10 屏上方可能仍显示「内脏脂肪等级」和同一个数字，这个值只算一次，填进 visceralFatLevel。

    标签语言：界面以中文为主；若某张照片上出现日文标签，按同义理解——
    体重=体重 / 体脂肪率=体脂肪率 / 体年齢=身体年龄 / 基礎代謝=基础代谢 /
    内臓脂肪レベル=内脏脂肪等级 / 骨格筋率=骨骼肌率 / 腕=双臂 / 体幹=躯干 / 脚=双脚。

    要求：
    1. 仔细辨认大数字和它上方/旁边的小标签文字，不要把标签或图标当成读数，也不要漏掉任何一项。
    2. 只看照片里的内容，不要猜测或推算。
    3. 只输出一个 JSON 对象，不要输出任何解释文字，不要用 ``` 代码块包裹。
    4. 某字段若在所有照片中都没出现或看不清，填 null。
    5. 不要混淆「体脂肪率」（全身总体脂）与「皮下脂肪率」（按部位）。
    6. 严格使用这个格式（字段名完全一致）：
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
            let b64 = jpg.base64EncodedString()
            content.append([
                "type": "image_url",
                "image_url": ["url": "data:image/jpeg;base64,\(b64)"]
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
        request.timeoutInterval = 90
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
