import AppKit
import KeyboardShortcuts
import SwiftUI

extension KeyboardShortcuts.Name {
    static let toggleSharing = Self("toggleSharing")
}

/// Hotkey recorder + cursor toggle. A plain SwiftUI view hosted in an
/// AppKit window rather than a SwiftUI `Settings` scene, because
/// `MenuBarExtra`-only apps have no window group to hang one off.
struct SettingsView: View {
    @State private var showsCursor = Preferences.showsCursor

    var body: some View {
        Form {
            KeyboardShortcuts.Recorder("Toggle sharing:", name: .toggleSharing)
            Toggle("Show cursor in shared output", isOn: $showsCursor)
                .onChange(of: showsCursor) { _, newValue in
                    Preferences.showsCursor = newValue
                }
        }
        .padding(20)
        .frame(width: 320)
    }
}

/// Owns the single settings window instance so repeat menu clicks refocus
/// it instead of stacking duplicates.
@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    func show() {
        NSApp.activate(ignoringOtherApps: true)

        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 140),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Skylight Settings"
        window.contentView = NSHostingView(rootView: SettingsView())
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window

        window.makeKeyAndOrderFront(nil)
    }
}
