import SwiftUI

/// 一条健身日志（自己手动填，不经过 AI）。
struct WorkoutEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    var date: Date
    var title: String        // 训练内容，如“陈教练胸器械 椭圆机”
    var minutes: Double?     // 时长（分钟，可选）
    var hasCoach: Bool       // 是否有教练参与
    var note: String?        // 备注，如“晚上吃了烧烤”“休息一天”

    init(id: UUID = UUID(),
         date: Date = Date(),
         title: String = "",
         minutes: Double? = nil,
         hasCoach: Bool = false,
         note: String? = nil) {
        self.id = id
        self.date = date
        self.title = title
        self.minutes = minutes
        self.hasCoach = hasCoach
        self.note = note
    }

    static func empty() -> WorkoutEntry { WorkoutEntry() }
}

/// 健身日志的本地存储（JSON 存 Documents，与体脂记录分开）。
@MainActor
final class WorkoutStore: ObservableObject {
    @Published private(set) var entries: [WorkoutEntry] = []

    private var fileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("workouts.json")
    }

    init() {
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let decoded = try? decoder.decode([WorkoutEntry].self, from: data) else { return }
        entries = decoded.sorted { $0.date > $1.date }
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(entries) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    func upsert(_ entry: WorkoutEntry) {
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[idx] = entry
        } else {
            entries.append(entry)
        }
        entries.sort { $0.date > $1.date }
        save()
    }

    func delete(_ entry: WorkoutEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }
}

/// “健身日志”页：手动记录每天练了什么、有没有教练带。
struct WorkoutView: View {
    @EnvironmentObject private var readings: RecordStore

    @StateObject private var store = WorkoutStore()
    @State private var editing: WorkoutEntry?
    @State private var showNew = false

    var body: some View {
        NavigationStack {
            Group {
                if store.entries.isEmpty {
                    emptyHint
                } else {
                    list
                }
            }
            .navigationTitle("健身日志")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNew = true
                    } label: {
                        Label("新增", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $editing) { entry in
                WorkoutEditView(entry: entry, store: store)
            }
            .sheet(isPresented: $showNew) {
                WorkoutEditView(entry: .empty(), store: store)
            }
        }
    }

    // MARK: - 列表

    private var list: some View {
        List {
            Section("统计") {
                HStack {
                    summaryItem("总次数", value: "\(store.entries.count)")
                    Divider()
                    summaryItem("本周", value: "\(thisWeekCount)")
                    Divider()
                    summaryItem("教练带练", value: "\(coachCount)")
                }
                .padding(.vertical, 2)
            }

            Section("日志（\(store.entries.count)）") {
                ForEach(store.entries) { entry in
                    row(entry)
                        .contentShape(Rectangle())
                        .onTapGesture { editing = entry }
                        .swipeActions(edge: .trailing) {
                            Button("删除", role: .destructive) {
                                store.delete(entry)
                            }
                        }
                }
            }
        }
    }

    private func summaryItem(_ title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var coachCount: Int {
        store.entries.filter { $0.hasCoach }.count
    }

    private var thisWeekCount: Int {
        let calendar = Calendar.current
        return store.entries.filter {
            calendar.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear)
        }.count
    }

    private func row(_ entry: WorkoutEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .fontWeight(.medium)
                if entry.hasCoach {
                    Text("教练")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                }
                Spacer()
                if let minutes = entry.minutes {
                    Text("\(Format.plain(minutes)) 分钟")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !entry.title.isEmpty {
                Text(entry.title)
                    .font(.footnote)
            }

            HStack(spacing: 10) {
                if let weight = weightOnSameDay(entry.date) {
                    Text("体重 \(Format.plain(weight)) kg")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if let note = entry.note, !note.isEmpty {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 2)
    }

    /// 同一天如果称过体重，就带出来显示
    private func weightOnSameDay(_ date: Date) -> Double? {
        readings.readings.first {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }?.weightKg
    }

    private var emptyHint: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.run")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("还没有健身日志")
                .font(.headline)
            Text("点右上角“+”添加一条：\n练了什么、多少分钟、今天有没有教练带。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

/// 新增/编辑一条健身日志。
struct WorkoutEditView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var entry: WorkoutEntry
    @ObservedObject var store: WorkoutStore

    private let suggestions = ["泰坦椭圆机", "体适能", "椭圆机", "器械", "休息一天", "没去"]

    init(entry: WorkoutEntry, store: WorkoutStore) {
        _entry = State(initialValue: entry)
        _store = ObservedObject(wrappedValue: store)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("日期", selection: $entry.date, displayedComponents: .date)
                }

                Section("训练内容") {
                    TextField("例如：陈教练胸器械 椭圆机", text: $entry.title, axis: .vertical)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(suggestions, id: \.self) { text in
                                Button(text) { appendSuggestion(text) }
                                    .font(.caption)
                                    .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    HStack {
                        Text("时长")
                        Spacer()
                        TextField("分钟", text: Binding(
                            get: { entry.minutes.map { Format.plain($0) } ?? "" },
                            set: { entry.minutes = Format.parse($0) }
                        ))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 100)
                        Text("分钟")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Toggle("有教练参与", isOn: $entry.hasCoach)
                } footer: {
                    Text("勾上表示这天是教练带练：列表里会显示“教练”标签，统计里也会单独计数。没教练就别勾。")
                }

                Section("备注") {
                    TextField("例如：晚上吃了烧烤 / 休息一天 / 没去", text: Binding(
                        get: { entry.note ?? "" },
                        set: { entry.note = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                }

                Section {
                    Button("保存日志") { save() }
                        .frame(maxWidth: .infinity)
                } footer: {
                    Text("只保存在本机（不上传、不走 AI）。内容随便写，可以像这样：泰坦椭圆机 L8 30min。")
                }
            }
            .navigationTitle(entry.title.isEmpty ? "新增日志" : "编辑日志")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func appendSuggestion(_ text: String) {
        let trimmed = entry.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            entry.title = text
        } else if !entry.title.contains(text) {
            entry.title += " " + text
        }
    }

    private func save() {
        var toSave = entry
        toSave.title = entry.title.trimmingCharacters(in: .whitespacesAndNewlines)
        store.upsert(toSave)
        dismiss()
    }
}
