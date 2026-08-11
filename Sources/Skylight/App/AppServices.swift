import AppKit
import CoreGraphics
import KeyboardShortcuts
import os

/// Composition root: builds the real `ShareSession` wiring (CGVirtualDisplay
/// provider, ScreenCaptureKit engine, overlay, mirror) and owns the pieces
/// the menu and app delegate share.
@MainActor
final class AppServices {
    static let shared = AppServices()

    let presetStore = RegionStore()
    let session: ShareSession

    private let displayProvider = VirtualDisplayController()

    private init() {
        session = ShareSession(
            displayProvider: displayProvider,
            selector: SelectionOverlayController(),
            mirror: DisplayMirror(),
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
            captureOptions: { CaptureOptions(showsCursor: Preferences.showsCursor) }
        )
        session.onUserFacingError = { [weak self] message in self?.presentError(message) }

        KeyboardShortcuts.onKeyUp(for: .toggleSharing) { [weak self] in
            self?.handleHotkey()
        }
    }

    private func handleHotkey() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch HotkeyController.action(state: session.state, lastRegion: session.currentRegion) {
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

    static var defaults: UserDefaults = .standard

    static var showsCursor: Bool {
        get {
            defaults.object(forKey: showsCursorKey) as? Bool ?? true
        }
        set {
            defaults.set(newValue, forKey: showsCursorKey)
        }
    }
}
