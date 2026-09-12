import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            CaptureView()
                .tabItem { Label("拍照记录", systemImage: "camera") }
            HistoryView()
                .tabItem { Label("历史与趋势", systemImage: "chart.xyaxis.line") }
            WorkoutView()
                .tabItem { Label("健身日志", systemImage: "figure.run") }
            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
    }
}
