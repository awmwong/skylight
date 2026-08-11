import SwiftUI

enum AppInfo {
    static let name = "Skylight"
    static let virtualDisplayName = "Skylight Display"
}

@main
struct SkylightApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra(AppInfo.name, systemImage: "rectangle.dashed.badge.record") {
            MenuContent()
        }
    }
}

struct MenuContent: View {
    private let presetStore = RegionStore()

    var body: some View {
        PresetsMenuSection(
            presets: presetStore.load(),
            onRecall: { _ in },
            onDelete: { preset in try? presetStore.delete(named: preset.name) },
            currentRegionProvider: nil,
            onSaveCurrentRegion: { _ in }
        )

        Divider()

        Button("Quit \(AppInfo.name)") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {}

    func applicationWillTerminate(_ notification: Notification) {}
}
