import SwiftUI

@main
struct ScaleReaderApp: App {
    @StateObject private var store = RecordStore()
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(settings)
        }
    }
}
