import SwiftUI

/// 设置：AI 服务商/参数、写入健康开关、说明与数据管理。
struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: RecordStore

    @State private var apiKeyInput = ""
    @State private var keyMessage = ""
    @State private var showClearConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                aiSection
                healthSection
                helpSection
                dataSection
                versionSection
            }
            .navigationTitle("设置")
            .onAppear {
                apiKeyInput = settings.apiKey ?? ""
            }
            .confirmationDialog("确定清空所有本地记录？此操作不可恢复（“健康”里的数据不会被删除）。",
                                isPresented: $showClearConfirm,
                                titleVisibility: .visible) {
                Button("清空全部记录", role: .destructive) {
                    store.deleteAll()
                }
            }
        }
    }

    // MARK: - AI 服务

    @ViewBuilder
    private var aiSection: some View {
        Section {
            ForEach(AppSettings.Preset.all, id: \.name) { preset in
                Button {
                    settings.apply(preset: preset)
                    keyMessage = ""
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preset.name)
                            Text(preset.note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if settings.apiBaseURL == preset.baseURL && settings.apiModel == preset.model {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
                .foregroundStyle(.primary)
            }
        } header: {
            Text("AI 识别服务商")
        } footer: {
            Text("拍照识别依赖云端多模态大模型。默认已选“硅基流动”（国内直连，注册有免费额度），也可换成 OpenAI 等任意 OpenAI 兼容接口。")
        }

        Section {
            TextField("API 地址（Base URL）", text: $settings.apiBaseURL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("模型名称", text: $settings.apiModel)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            SecureField("API Key", text: $apiKeyInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("保存 API Key") {
                settings.setAPIKey(apiKeyInput)
                keyMessage = settings.apiKey == nil ? "已清除 Key" : "已保存 ✓"
            }
            if !keyMessage.isEmpty {
                Text(keyMessage)
                    .font(.footnote)
                    .foregroundStyle(.green)
            }
        } header: {
            Text("服务参数")
        } footer: {
            Text("API Key 只保存在本机钥匙串（Keychain），不会上传。")
        }
    }

    // MARK: - 健康

    private var healthSection: some View {
        Section {
            Toggle("体重 → 健康", isOn: $settings.writeWeight)
            Toggle("体脂肪率 → 健康", isOn: $settings.writeBodyFat)
            Toggle("骨骼肌 → 健康", isOn: $settings.writeMuscleKg)
            Toggle("BMI → 健康", isOn: $settings.writeBMI)
            Toggle("基础代谢 → 健康（静息能量）", isOn: $settings.writeBasalEnergy)
        } header: {
            Text("写入苹果健康")
        } footer: {
            Text("骨骼肌按 体重×骨骼肌率 换算成 kg 写入“去脂体重”（健康没有“骨骼肌率”）。基础代谢写入“静息能量”，默认关闭以免与手表数据混淆。内脏脂肪等级、身体年龄、皮下脂肪率健康里没有对应项，只保存在本 App。侧载环境下若授权异常，本地记录不受影响。")
        }
    }

    // MARK: - 说明

    private var helpSection: some View {
        Section("使用说明") {
            VStack(alignment: .leading, spacing: 6) {
                Text("1. 站上 HBF-701 完成测量")
                Text("2. 测完后每按一下翻一屏，每屏拍一张照片（共 8 项左右）")
                Text("3. 点“开始 AI 识别”，在结果页核对/修改后保存")
                Text("4. 数据写入本地历史，同时按需写入苹果健康")
            }
            .font(.footnote)
        }
    }

    // MARK: - 数据

    private var dataSection: some View {
        Section("数据") {
            Button("清空全部本地记录", role: .destructive) {
                showClearConfirm = true
            }
        }
    }

    private var versionSection: some View {
        Section {
            Text("体脂拍照记录 v1.0.0")
                .foregroundStyle(.secondary)
        }
    }
}
