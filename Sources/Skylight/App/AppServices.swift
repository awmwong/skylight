import AppKit
import CoreGraphics
import KeyboardShortcuts
import os

/// Composition root: builds the real `ShareSession` wiring (ScreenCaptureKit
/// engine, selection overlay, mirror window) and owns the pieces the menu and
/// app delegate share.
@MainActor
final class AppServices {
    static let shared = AppServices()

    let presetStore = RegionStore()
    let session: ShareSession

    private init() {
        session = ShareSession(
            selector: SelectionOverlayController(initialRegionProvider: { Preferences.lastSharedRegion }),
            mirror: MirrorWindowController(),
            captureFactory: { region, info, options in
                CaptureEngine(
                    region: region,
                    displayOrigin: info.originCG,
                    displayScale: info.scale,
                    options: options
                )
            },
            sourceDisplayInfo: Self.sourceDisplayInfo,
            hasScreenRecordingPermission: { CGPreflightScreenCaptureAccess() },
            requestScreenRecordingPermission: { CGRequestScreenCaptureAccess() },
            captureOptions: { CaptureOptions(showsCursor: Preferences.showsCursor) },
            persistLastRegion: { Preferences.lastSharedRegion = $0 }
        )
        session.onUserFacingError = { [weak self] message in self?.presentError(message) }

        KeyboardShortcuts.onKeyUp(for: .toggleSharing) { [weak self] in
            self?.handleHotkey()
        }
    }

    /// Ask for Screen Recording at launch, so the grant-and-relaunch dance
    /// happens before the first share attempt instead of interrupting it.
    /// `ShareSession.preflight` still guards every share for the denied case.
    func requestScreenRecordingPermissionAtLaunch() {
        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
        }
    }

    private func handleHotkey() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            // Fall back to the persisted region so the hotkey can re-share
            // right after a relaunch, before any share ran this session.
            let lastRegion = session.currentRegion ?? Preferences.lastSharedRegion
            switch HotkeyController.action(state: session.state, lastRegion: lastRegion) {
            case .stopSharing:
                await session.stopSharing()
            case let .startSharing(region):
                await session.startSharing(with: region)
            case .beginSelection:
                session.beginSelection()
            }
        }
    }

    func presentError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Skylight"
        alert.informativeText = message
        alert.alertStyle = .warning
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    /// Modal name prompt for "Save Current Region…". Returns nil when the
    /// user cancels or leaves the name empty.
    func promptForPresetName() -> String? {
        let alert = NSAlert()
        alert.messageText = "Save Region Preset"
        alert.informativeText = "Name for the current region:"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: CGRect(x: 0, y: 0, width: 240, height: 24))
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let name = field.stringValue.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? nil : name
    }

    private static func sourceDisplayInfo(for displayID: CGDirectDisplayID) -> SourceDisplayInfo? {
        let bounds = CGDisplayBounds(displayID)
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        return SourceDisplayInfo(bounds: bounds, scale: backingScale(for: displayID))
    }

    private static func backingScale(for displayID: CGDirectDisplayID) -> CGFloat {
        NSScreen.screen(for: displayID)?.backingScaleFactor ?? 1
    }
}

/// User preferences shared between the menu and the capture pipeline.
/// `defaults` is var, not let, so tests can point it at an isolated
/// `UserDefaults` suite instead of touching the user's real preferences.
enum Preferences {
    private static let showsCursorKey = "showsCursor"
    private static let lastSharedRegionKey = "lastSharedRegion"
    private static let logger = Logger(subsystem: "ng.awo.skylight", category: "Preferences")

    static var defaults: UserDefaults = .standard

    static var showsCursor: Bool {
        get {
            defaults.object(forKey: showsCursorKey) as? Bool ?? true
        }
        set {
            defaults.set(newValue, forKey: showsCursorKey)
        }
    }

    /// The last region a share actually started with. The selection overlay
    /// opens with it preselected, and the hotkey can re-share it after a
    /// relaunch. Stored values cross a trust boundary on read, like presets,
    /// so invalid regions are dropped.
    static var lastSharedRegion: Region? {
        get {
            guard let stored = defaults.data(forKey: lastSharedRegionKey) else { return nil }
            do {
                let region = try JSONDecoder().decode(Region.self, from: stored)
                return region.isValid ? region : nil
            } catch {
                logger.error("Failed to decode last shared region: \(error, privacy: .public)")
                return nil
            }
        }
        set {
            guard let newValue else {
                defaults.removeObject(forKey: lastSharedRegionKey)
                return
            }
            do {
                try defaults.set(JSONEncoder().encode(newValue), forKey: lastSharedRegionKey)
            } catch {
                logger.error("Failed to encode last shared region: \(error, privacy: .public)")
            }
        }
    }
}
