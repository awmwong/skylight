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
    var body: some View {
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
