import SwiftUI

@main
@MainActor
struct ServerMonitorApp: App {
    @State private var state = AppState.shared
    @Environment(\.openWindow) private var openWindow

    init() {
        AppState.shared.startAllPollers()
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverRootView(state: state, openSettings: { openWindow(id: "settings") })
                .frame(width: 380)
        } label: {
            MenuBarLabel(state: state)
        }
        .menuBarExtraStyle(.window)

        Window("Server Monitor — Settings", id: "settings") {
            SettingsView(state: state)
                .frame(minWidth: 520, minHeight: 380)
        }
        .windowResizability(.contentSize)
    }
}
