import Foundation
import Combine

/// 应用设置：AI 服务参数与“写入健康”开关。
final class AppSettings: ObservableObject {
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let baseURL = "apiBaseURL"
        static let model = "apiModel"
        static let writeWeight = "writeWeight"
        static let writeBodyFat = "writeBodyFat"
        static let writeMuscleKg = "writeMuscleKg"
        static let writeBMI = "writeBMI"
        static let writeBasalEnergy = "writeBasalEnergy"
        static let apiKeyAccount = "apiKey"
    }

    @Published var apiBaseURL: String {
        didSet { defaults.set(apiBaseURL, forKey: Keys.baseURL) }
    }
    @Published var apiModel: String {
        didSet { defaults.set(apiModel, forKey: Keys.model) }
    }
    @Published var writeWeight: Bool {
        didSet { defaults.set(writeWeight, forKey: Keys.writeWeight) }
    }
    @Published var writeBodyFat: Bool {
        didSet { defaults.set(writeBodyFat, forKey: Keys.writeBodyFat) }
    }
    @Published var writeMuscleKg: Bool {
        didSet { defaults.set(writeMuscleKg, forKey: Keys.writeMuscleKg) }
    }
    @Published var writeBMI: Bool {
        didSet { defaults.set(writeBMI, forKey: Keys.writeBMI) }
    }
    @Published var writeBasalEnergy: Bool {
        didSet { defaults.set(writeBasalEnergy, forKey: Keys.writeBasalEnergy) }
    }

    init() {
        let d = defaults
        let preset = Preset.siliconflow
        apiBaseURL = d.string(forKey: Keys.baseURL) ?? preset.baseURL
        apiModel = d.string(forKey: Keys.model) ?? preset.model
        writeWeight = (d.object(forKey: Keys.writeWeight) as? Bool) ?? true
        writeBodyFat = (d.object(forKey: Keys.writeBodyFat) as? Bool) ?? true
        writeMuscleKg = (d.object(forKey: Keys.writeMuscleKg) as? Bool) ?? true
        writeBMI = (d.object(forKey: Keys.writeBMI) as? Bool) ?? true
        writeBasalEnergy = (d.object(forKey: Keys.writeBasalEnergy) as? Bool) ?? false
    }

    // MARK: - API Key（存应用本地 UserDefaults）
    // TrollStore/侧载环境下 Keychain 写入会失败，因此改用 UserDefaults 持久化。

    var apiKey: String? {
        defaults.string(forKey: Keys.apiKeyAccount)
    }

    func setAPIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            defaults.removeObject(forKey: Keys.apiKeyAccount)
        } else {
            defaults.set(trimmed, forKey: Keys.apiKeyAccount)
        }
    }

    func apply(preset: Preset) {
        apiBaseURL = preset.baseURL
        apiModel = preset.model
    }

    // MARK: - 提供商预设

    struct Preset {
        let name: String
        let baseURL: String
        let model: String
        let note: String

        static let deepseek = Preset(
            name: "DeepSeek（视觉）",
            baseURL: "https://api.deepseek.com/v1",
            model: "deepseek-v4-flash-vision-exp",
            note: "需用支持视觉的模型；Key 在 platform.deepseek.com 申请"
        )
        static let openai = Preset(
            name: "OpenAI",
            baseURL: "https://api.openai.com/v1",
            model: "gpt-4o-mini",
            note: "模型需支持 vision，需海外网络/支付"
        )
        static let siliconflow = Preset(
            name: "硅基流动 SiliconFlow",
            baseURL: "https://api.siliconflow.cn/v1",
            model: "Qwen/Qwen2.5-VL-7B-Instruct",
            note: "国内直连；注册实名后有免费/低价额度"
        )
        static let zhipu = Preset(
            name: "智谱 GLM-4V-Flash",
            baseURL: "https://open.bigmodel.cn/api/paas/v4",
            model: "glm-4v-flash",
            note: "国内直连；有免费档，注意限量"
        )

        static let all: [Preset] = [deepseek, openai, siliconflow, zhipu]
    }
}
