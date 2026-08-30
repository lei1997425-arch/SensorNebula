import SwiftUI

@main
struct SensorNebulaApp: App {
    @StateObject private var store = SensorStore()
    @AppStorage("appearance.lightMode") private var lightMode = false

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .frame(minWidth: 1180, minHeight: 760)
                .preferredColorScheme(lightMode ? .light : .dark)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1380, height: 860)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
