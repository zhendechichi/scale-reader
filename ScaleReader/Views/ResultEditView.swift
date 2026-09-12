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

                Section("部位分布（核对用）") {
                    BodyMapView(reading: reading)
                        .padding(.vertical, 6)
                        .listRowSeparator(.hidden)
                }

                Section {
                    NumberField(title: "体重", unit: "kg", value: $reading.weightKg)
                    NumberField(title: "身体脂肪率", unit: "%", value: $reading.bodyFatPct)
                    NumberField(title: "身体年龄", unit: "岁", value: $reading.bodyAge)
                    NumberField(title: "BMI", unit: "", value: $reading.bmi)
                    NumberField(title: "基础代谢", unit: "kcal", value: $reading.basalMetabolismKcal)
                    NumberField(title: "内脏脂肪指数", unit: "", value: $reading.visceralFatLevel)
                } header: {
                    Text(hasAnyValue ? "识别结果（可直接修改）" : "手动填写")
                }

                Section {
                    NumberField(title: "皮下脂肪率", unit: "%", value: $reading.subcutaneousFatPct)
                    NumberField(title: "肌肉率", unit: "%", value: $reading.skeletalMusclePct)
                    if let kg = reading.computedSkeletalMuscleKg {
                        HStack {
                            Text("肌肉量（换算）")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Format.plain(kg)) kg")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("全身")
                } footer: {
                    Text("肌肉量 = 体重 × 全身肌肉率。苹果健康没有“肌肉率/骨骼肌率”，只按换算后的 kg 写入“去脂体重”。")
                }

                Section("上肢") {
                    NumberField(title: "皮下脂肪率", unit: "%", value: $reading.armsSubcutaneousFatPct)
                    NumberField(title: "肌肉率", unit: "%", value: $reading.armsSkeletalMusclePct)
                }

                Section("躯干") {
                    NumberField(title: "皮下脂肪率", unit: "%", value: $reading.trunkSubcutaneousFatPct)
                    NumberField(title: "肌肉率", unit: "%", value: $reading.trunkSkeletalMusclePct)
                }

                Section("下肢") {
                    NumberField(title: "皮下脂肪率", unit: "%", value: $reading.legsSubcutaneousFatPct)
                    NumberField(title: "肌肉率", unit: "%", value: $reading.legsSkeletalMusclePct)
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
                    Text("保存后写入本地历史。健康写入：体重、身体脂肪率、肌肉量(kg)、BMI、基础代谢（后两项可在设置里关闭）；内脏脂肪指数、身体年龄、各部位皮下脂肪率/肌肉率只保存在本 App。")
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

/// 人体示意图：把 全身 / 上肢 / 躯干 / 下肢 的皮下脂肪率与肌肉率直接标在身上。
struct BodyMapView: View {
    let reading: ScaleReading

    private var hasWholeBody: Bool {
        reading.subcutaneousFatPct != nil || reading.skeletalMusclePct != nil
    }
    private var hasArms: Bool {
        reading.armsSubcutaneousFatPct != nil || reading.armsSkeletalMusclePct != nil
    }
    private var hasTrunk: Bool {
        reading.trunkSubcutaneousFatPct != nil || reading.trunkSkeletalMusclePct != nil
    }
    private var hasLegs: Bool {
        reading.legsSubcutaneousFatPct != nil || reading.legsSkeletalMusclePct != nil
    }

    private func tint(_ hasData: Bool) -> Color {
        hasData ? Color.accentColor : Color.secondary.opacity(0.25)
    }

    private func pct(_ value: Double?) -> String {
        guard let value = value else { return "—" }
        return "\(Format.plain(value))%"
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let trunkColor = tint(hasTrunk)
            let armsColor = tint(hasArms)
            let legsColor = tint(hasLegs)
            let drawWholeBody = hasWholeBody
            ZStack {
                Canvas { context, size in
                    let W = size.width
                    let H = size.height
                    func box(_ x: CGFloat, _ y: CGFloat,
                             _ bw: CGFloat, _ bh: CGFloat,
                             _ radius: CGFloat) -> Path {
                        Path(roundedRect: CGRect(x: x * W, y: y * H,
                                                 width: bw * W, height: bh * H),
                             cornerRadius: radius * W)
                    }

                    // 全身：有数据时给整个人形描一圈高亮
                    if drawWholeBody {
                        context.stroke(
                            Path(roundedRect: CGRect(x: 0.27 * W, y: 0.005 * H,
                                                     width: 0.46 * W, height: 0.99 * H),
                                 cornerRadius: 0.09 * W),
                            with: .color(Color.accentColor.opacity(0.5)),
                            lineWidth: 1.5
                        )
                    }

                    // 头
                    context.fill(
                        Path(ellipseIn: CGRect(x: 0.462 * W, y: 0.02 * H,
                                               width: 0.076 * W, height: 0.076 * W)),
                        with: .color(Color.secondary.opacity(0.35))
                    )
                    // 躯干
                    context.fill(box(0.425, 0.13, 0.15, 0.29, 0.05), with: .color(trunkColor))
                    // 上肢
                    context.fill(box(0.290, 0.15, 0.115, 0.30, 0.05), with: .color(armsColor))
                    context.fill(box(0.595, 0.15, 0.115, 0.30, 0.05), with: .color(armsColor))
                    // 下肢
                    context.fill(box(0.4275, 0.42, 0.070, 0.52, 0.035), with: .color(legsColor))
                    context.fill(box(0.5025, 0.42, 0.070, 0.52, 0.035), with: .color(legsColor))
                }

                regionLabel("全身", subcutaneous: reading.subcutaneousFatPct,
                            muscle: reading.skeletalMusclePct, width: w * 0.26)
                    .position(x: w * 0.14, y: h * 0.12)
                regionLabel("躯干", subcutaneous: reading.trunkSubcutaneousFatPct,
                            muscle: reading.trunkSkeletalMusclePct, width: w * 0.26)
                    .position(x: w * 0.86, y: h * 0.24)
                regionLabel("上肢", subcutaneous: reading.armsSubcutaneousFatPct,
                            muscle: reading.armsSkeletalMusclePct, width: w * 0.26)
                    .position(x: w * 0.14, y: h * 0.48)
                regionLabel("下肢", subcutaneous: reading.legsSubcutaneousFatPct,
                            muscle: reading.legsSkeletalMusclePct, width: w * 0.26)
                    .position(x: w * 0.86, y: h * 0.78)
            }
        }
        .frame(height: 300)
    }

    private func regionLabel(_ title: String,
                             subcutaneous: Double?,
                             muscle: Double?,
                             width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.caption2)
                .fontWeight(.semibold)
            Text("皮下 \(pct(subcutaneous))")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text("肌肉 \(pct(muscle))")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(width: width, alignment: .leading)
    }
}
