import SwiftUI

/// AI 识别结果的确认/编辑页，也用作“手动记录”。
/// 按 HBF-701 的 10 屏结构分组：6 项单项 + 4 个部位（全身/双臂/躯干/双脚）。
struct ResultEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: RecordStore
    @EnvironmentObject private var settings: AppSettings

    @State private var reading: ScaleReading
    @State private var outcomeText = ""
    @State private var showOutcome = false

    private let health = HealthService()

    init(reading: ScaleReading) {
        _reading = State(initialValue: reading)
    }

    private var hasAnyValue: Bool { reading.hasAnyValue }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("测量时间", selection: $reading.date)
                }

                Section {
                    NumberField(title: "体重", unit: "kg", value: $reading.weightKg)
                    NumberField(title: "体脂肪率", unit: "%", value: $reading.bodyFatPct)
                    NumberField(title: "身体年龄", unit: "岁", value: $reading.bodyAge)
                    NumberField(title: "BMI", unit: "", value: $reading.bmi)
                    NumberField(title: "基础代谢", unit: "kcal", value: $reading.basalMetabolismKcal)
                    NumberField(title: "内脏脂肪等级", unit: "", value: $reading.visceralFatLevel)
                } header: {
                    Text(hasAnyValue ? "识别结果（可直接修改）" : "手动填写")
                }

                Section {
                    NumberField(title: "皮下脂肪率", unit: "%", value: $reading.subcutaneousFatPct)
                    NumberField(title: "骨骼肌率", unit: "%", value: $reading.skeletalMusclePct)
                    if let kg = reading.computedSkeletalMuscleKg {
                        HStack {
                            Text("骨骼肌（换算）")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Format.plain(kg)) kg")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("全身")
                } footer: {
                    Text("骨骼肌 = 体重 × 全身骨骼肌率。苹果健康不支持“骨骼肌率”，只按换算后的 kg 写入“去脂体重”。")
                }

                Section("双臂") {
                    NumberField(title: "皮下脂肪率", unit: "%", value: $reading.armsSubcutaneousFatPct)
                    NumberField(title: "骨骼肌率", unit: "%", value: $reading.armsSkeletalMusclePct)
                }

                Section("躯干") {
                    NumberField(title: "皮下脂肪率", unit: "%", value: $reading.trunkSubcutaneousFatPct)
                    NumberField(title: "骨骼肌率", unit: "%", value: $reading.trunkSkeletalMusclePct)
                }

                Section("双脚") {
                    NumberField(title: "皮下脂肪率", unit: "%", value: $reading.legsSubcutaneousFatPct)
                    NumberField(title: "骨骼肌率", unit: "%", value: $reading.legsSkeletalMusclePct)
                }

                Section("备注") {
                    TextField("备注（可选）", text: Binding(
                        get: { reading.note ?? "" },
                        set: { reading.note = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                }

                Section {
                    Button("保存记录") { save() }
                        .frame(maxWidth: .infinity)
                        .disabled(!hasAnyValue)
                } footer: {
                    Text("保存后写入本地历史。健康写入：体重、体脂肪率、骨骼肌(kg)、BMI、基础代谢（后两项可在设置里关闭）；内脏脂肪等级、身体年龄、各部位皮下脂肪率/骨骼肌率只保存在本 App。")
                }
            }
            .navigationTitle(hasAnyValue ? "确认读数" : "手动记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
            .alert("保存结果", isPresented: $showOutcome) {
                Button("完成") { dismiss() }
            } message: {
                Text(outcomeText)
            }
        }
    }

    private func save() {
        guard hasAnyValue else { return }
        store.upsert(reading)
        let weightOn = settings.writeWeight
        let fatOn = settings.writeBodyFat
        let muscleOn = settings.writeMuscleKg
        let bmiOn = settings.writeBMI
        let basalOn = settings.writeBasalEnergy
        let toSave = reading
        Task {
            let results = await health.save(toSave,
                                            writeWeight: weightOn,
                                            writeBodyFat: fatOn,
                                            writeMuscleKg: muscleOn,
                                            writeBMI: bmiOn,
                                            writeBasalEnergy: basalOn)
            if results.isEmpty {
                outcomeText = "已保存到本地历史。"
            } else {
                outcomeText = results.map { ($0.ok ? "✓ " : "✗ ") + $0.label + "：" + $0.message }
                    .joined(separator: "\n")
            }
            showOutcome = true
        }
    }
}

/// 一个数值输入行。
private struct NumberField: View {
    let title: String
    let unit: String
    @Binding var value: Double?

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("未识别", text: Binding(
                get: { value.map(Format.plain) ?? "" },
                set: { value = Format.parse($0) }
            ))
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 150)
            if !unit.isEmpty {
                Text(unit)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
