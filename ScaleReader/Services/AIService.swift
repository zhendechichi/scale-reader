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
    你是欧姆龙 HBF-701（中文版，Karada Scan 体组成计）的屏幕读数识别助手。这台秤测完后按键逐屏翻页，一轮约 10 屏。我是**按顺序**一屏拍了一张照片，请把全部读数汇总成一轮结果。

    照片顺序与屏幕对应关系：
    第 1 张=体重 ｜ 第 2 张=体脂肪率 ｜ 第 3 张=身体年龄 ｜ 第 4 张=BMI ｜
    第 5 张=基础代谢 ｜ 第 6 张=内脏脂肪等级 ｜
    第 7 张=全身 ｜ 第 8 张=双臂 ｜ 第 9 张=躯干 ｜ 第 10 张=双脚

    前 6 张每张只有一个大数字：
    - 体重：单位 kg；体脂肪率：单位 %；身体年龄：单位 岁；
      BMI：无单位；基础代谢：单位 kcal；内脏脂肪等级：无单位
    后 4 张（第 7~10 张）每张**同时显示两个百分数**：一个是「皮下脂肪率」、一个是「骨骼肌率」。
    请把第 7~10 张的两个数分别填入 全身 / 双臂 / 躯干 / 双脚 对应的字段
    （也可以结合屏幕上人体图示的高亮部位、以及标签行中被选中的「全身 / 双臂 / 躯干 / 双脚」来确认）。

    读数规则：
    1. 【小数点是重点】屏幕上的小数点是两个数字之间一个很小的点，很容易被忽略：
       · 「1.0」不是「10」 ·「17.4」不是「174」
       · **内脏脂肪等级这一屏尤其注意**：如果数字右下角有一个小点，那就是带小数的值（例如 1.0），不要读成整数 10
       · 请逐位确认；实在看不清就填 null，不要猜。
    2. 只读大数字，不要把中文标签、人体图示、图标当成读数。
    3. 合理范围（明显超出说明看错了，请重新确认）：
       体重 20~200 kg｜体脂肪率 3~60%｜身体年龄 5~90 岁｜BMI 10~50｜
       基础代谢 500~4000 kcal｜内脏脂肪等级 1~30｜皮下脂肪率与骨骼肌率 3~70%
    4. 部位屏的两个百分数不要搞反：一个「皮下脂肪率」、一个「骨骼肌率」。
    5. 不要把「体脂肪率」（第 2 张，全身总体脂）和「皮下脂肪率」（第 7~10 张部位屏）搞混。
    6. 某字段在所有照片中都没出现或看不清，填 null。

    另外：请在 note 字段里写一句你实际读到的原文（例如「内脏脂肪=1.0；全身 皮下18.1/骨骼29.3」），方便我核对。

    只输出一个 JSON 对象，不要任何解释文字，不要用 ``` 包裹，字段名必须完全一致：
    {"weightKg": null,"bodyFatPct": null,"bodyAge": null,"bmi": null,"basalMetabolismKcal": null,"visceralFatLevel": null,"subcutaneousFatPct": null,"skeletalMusclePct": null,"armsSubcutaneousFatPct": null,"armsSkeletalMusclePct": null,"trunkSubcutaneousFatPct": null,"trunkSkeletalMusclePct": null,"legsSubcutaneousFatPct": null,"legsSkeletalMusclePct": null,"note": ""}
    """

    /// 把若干张屏幕照片交给视觉模型，解析成一条记录（照片需按屏幕顺序）。
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
