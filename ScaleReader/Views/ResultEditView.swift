import SwiftUI

/// AI 识别结果的确认/编辑页，也用作“手动记录”。
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

    private var hasAnyValue: Bool {
        reading.weightKg != nil
            || reading.bodyFatPct != nil
            || reading.skeletalMusclePct != nil
            || reading.subcutaneousFatPct != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("测量时间", selection: $reading.date)
                }

                Section(hasAnyValue ? "识别结果（可直接修改）" : "手动填写") {
                    NumberField(title: "体重", unit: "kg", value: $reading.weightKg)
                    NumberField(title: "体脂肪率", unit: "%", value: $reading.bodyFatPct)
                    NumberField(title: "骨骼肌率", unit: "%", value: $reading.skeletalMusclePct)
                    NumberField(title: "皮下脂肪率", unit: "%", value: $reading.subcutaneousFatPct)
                    if let kg = reading.computedSkeletalMuscleKg {
                        HStack {
                            Text("骨骼肌（换算）")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Format.plain(kg)) kg")
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text("骨骼肌 = 体重 × 骨骼肌率。苹果健康不支持“骨骼肌率”，只按换算后的 kg 写入“去脂体重”。")
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
                    Text("保存后写入本地历史；体重/体脂肪率直接写入健康，骨骼肌按换算 kg 写入；皮下脂肪率仅保存在本 App。")
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
        let toSave = reading
        Task {
            let results = await health.save(toSave,
                                            writeWeight: weightOn,
                                            writeBodyFat: fatOn,
                                            writeMuscleKg: muscleOn)
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
