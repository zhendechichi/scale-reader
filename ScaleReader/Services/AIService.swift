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
    你是欧姆龙 HBF-701 体脂秤屏幕读数识别助手。我会给你一张或多张该体脂秤液晶屏的照片（同一轮测量，屏幕会循环显示不同的读数，可能一屏一项或一屏多项）。请把这轮测量里所有出现过的读数都找出来并合并去重。

    可能显示的测量项：
    - 体重：单位 kg
    - 体脂肪率：单位 %
    - 骨骼肌率：单位 %（也可能显示为“骨格筋率”或“肌肉率”）
    - 皮下脂肪率：单位 %

    要求：
    1. 仔细辨认大数字和它上方/旁边的小标签文字，不要把标签或图标当成读数，也不要漏掉任何一项。
    2. 只看照片里的内容，不要猜测或推算。
    3. 只输出一个 JSON 对象，不要输出任何解释文字，不要用 ``` 代码块包裹。
    4. 某字段若在所有照片中都没出现或看不清，填 null。
    5. 严格使用这个格式（字段名完全一致）：
    {"weightKg": null,"bodyFatPct": null,"skeletalMusclePct": null,"subcutaneousFatPct": null,"note": ""}
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
