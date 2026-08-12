import SwiftUI

enum AppInfo {
    static let name = "Skylight"
    static let sharedWindowTitle = "Skylight — Shared Region"
}

@main
struct SkylightApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra(AppInfo.name, systemImage: "rectangle.dashed.badge.record") {
            MenuContent(services: AppServices.shared)
        }
    }
}

struct MenuContent: View {
    let services: AppServices

    var body: some View {
        let session = services.session

        switch session.state {
        case .idle:
            Button("Start Sharing…") { session.beginSelection() }
        case .selecting:
            Button("Selecting Region…") {}.disabled(true)
        case .sharing:
            Button("Stop Sharing") { Task { await session.stopSharing() } }
            Button("Shared Window: Actual Size") { services.mirrorWindow.snapToActualSize() }
        }

        Divider()

        PresetsMenuSection(
            presets: services.presetStore.load(),
            onRecall: { preset in Task { await session.startSharing(with: preset.region) } },
            onDelete: { preset in deletePreset(preset) },
            currentRegionProvider: session.state == .sharing ? { session.currentRegion } : nil,
            onSaveCurrentRegion: { region in savePreset(region) }
        )

        Divider()

        Button("Settings…") { SettingsWindowController.shared.show() }

        Divider()

        Button("Quit \(AppInfo.name)") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private func savePreset(_ region: Region) {
        guard let name = services.promptForPresetName() else { return }
        do {
            try services.presetStore.save(RegionPreset(name: name, region: region))
        } catch {
            services.presentError("Saving the preset failed: \(error.localizedDescription)")
        }
    }

    private func deletePreset(_ preset: RegionPreset) {
        do {
            try services.presetStore.delete(named: preset.name)
        } catch {
            services.presentError("Deleting the preset failed: \(error.localizedDescription)")
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            AppServices.shared.requestScreenRecordingPermissionAtLaunch()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated {
            AppServices.shared.session.terminate()
        }
    }
}
