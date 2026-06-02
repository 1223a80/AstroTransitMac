import SwiftUI

@main
struct TransitStudioApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1040, minHeight: 720)
        }
        .windowStyle(.titleBar)

        Settings {
            AppSettingsView()
        }
    }
}
