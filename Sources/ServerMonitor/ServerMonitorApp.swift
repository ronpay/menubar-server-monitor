import AppKit
import SwiftUI

@main
@MainActor
struct ServerMonitorApp: App {
    @State private var state = AppState.shared
    @Environment(\.openWindow) private var openWindow

    private static let settingsWindowID = "settings"

    init() {
        AppState.shared.startAllPollers()
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverRootView(state: state, openSettings: showSettings)
                .frame(width: 380)
                .menuBarWindowAutoSize()
        } label: {
            MenuBarLabel(state: state)
        }
        .menuBarExtraStyle(.window)

        Window("Server Monitor — Settings", id: Self.settingsWindowID) {
            SettingsView(state: state)
                .frame(minWidth: 520, minHeight: 380)
        }
        .windowResizability(.contentSize)
    }

    /// Opens settings and pulls the window in front of whatever the user is
    /// looking at. This is an accessory (`LSUIElement`) app, so it is never the
    /// active app while the menu bar popover is up — `openWindow` on its own
    /// leaves the settings window buried behind other apps' windows.
    private func showSettings() {
        openWindow(id: Self.settingsWindowID)
        NSApp.activate(ignoringOtherApps: true)
        Task { @MainActor in
            // The NSWindow may not exist yet on the first pass after openWindow.
            for _ in 0..<10 {
                if let window = Self.settingsWindow {
                    if window.isMiniaturized { window.deminiaturize(nil) }
                    window.makeKeyAndOrderFront(nil)
                    window.orderFrontRegardless()
                    return
                }
                try? await Task.sleep(nanoseconds: 30_000_000)
            }
        }
    }

    private static var settingsWindow: NSWindow? {
        NSApp.windows.first { window in
            window.identifier?.rawValue.contains(settingsWindowID) == true
                || window.title.hasSuffix("Settings")
        }
    }
}
