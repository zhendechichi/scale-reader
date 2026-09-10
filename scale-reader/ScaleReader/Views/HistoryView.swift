import SwiftUI
import Charts

/// 历史与趋势：记录列表 + 趋势图 + 手动新增/删除。
struct HistoryView: View {
    @EnvironmentObject private var store: RecordStore

    @State private var metric: Metric = .weight
    @State private var editing: ScaleReading?
    @State private var showManual = false

    enum Metric: String, CaseIterable, Identifiable {
        case weight = "体重"
        case bodyFat = "体脂肪率"
        case muscle = "骨骼肌率"
        case subcutaneousFat = "皮下脂肪率"
        case visceralFat = "内脏脂肪等级"
        case bmi = "BMI"
        case basalMetabolism = "基础代谢"
        case bodyAge = "身体年龄"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.readings.isEmpty {
                    emptyState
                } else {
                    content
                }
            }
            .navigationTitle("历史与趋势")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showManual = true
                    } label: {
                        Label("新增", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $editing) { reading in
                ResultEditView(reading: reading)
            }
            .sheet(isPresented: $showManual) {
                ResultEditView(reading: .empty())
            }
        }
    }

    private var content: some View {
        List {
            Section("趋势") {
                Picker("趋势指标", selection: $metric) {
                    ForEach(Metric.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.menu)
                .listRowSeparator(.hidden)

                chartView
                    .frame(height: 210)
            }

            Section("记录（\(store.readings.count)）") {
                ForEach(store.readings) { reading in
                    row(reading)
                        .contentShape(Rectangle())
                        .onTapGesture { editing = reading }
                        .swipeActions(edge: .trailing) {
                            Button("删除", role: .destructive) {
                                store.delete(reading)
                            }
                        }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("还没有记录")
                .font(.headline)
            Text("去“拍照记录”页拍摄体脂秤屏幕，或用右上角“+”手动添加一条。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private func row(_ reading: ScaleReading) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(reading.date.formatted(date: .abbreviated, time: .shortened))
                .font(.subheadline)
                .fontWeight(.medium)
            Text(Format.listLine(reading))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    // MARK: - 趋势图

    private struct TrendPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    private var chartPoints: [TrendPoint] {
        store.ascending.compactMap { reading in
            let value: Double?
            switch metric {
            case .weight: value = reading.weightKg
            case .bodyFat: value = reading.bodyFatPct
            case .muscle: value = reading.skeletalMusclePct
            case .subcutaneousFat: value = reading.subcutaneousFatPct
            case .visceralFat: value = reading.visceralFatLevel
            case .bmi: value = reading.bmi
            case .basalMetabolism: value = reading.basalMetabolismKcal
            case .bodyAge: value = reading.bodyAge
            }
            return value.map { TrendPoint(date: reading.date, value: $0) }
        }
    }

    @ViewBuilder
    private var chartView: some View {
        if chartPoints.count >= 2 {
            Chart(chartPoints) { point in
                LineMark(
                    x: .value("日期", point.date, unit: .day),
                    y: .value(metric.rawValue, point.value)
                )
                PointMark(
                    x: .value("日期", point.date, unit: .day),
                    y: .value(metric.rawValue, point.value)
                )
                .symbolSize(24)
            }
            .chartYAxisLabel(metric.rawValue)
        } else {
            Text("至少需要两条记录才会显示趋势")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
    }
}
