import SwiftUI

@main
struct TransitStudioApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1040, minHeight: 720)
                .environmentObject(appState)
        }
        .windowStyle(.titleBar)

        Settings {
            AppSettingsView()
                .environmentObject(appState)
        }
    }
}
