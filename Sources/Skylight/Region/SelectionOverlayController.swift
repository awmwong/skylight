import AppKit
import CoreGraphics
import os

/// Presents a draggable, resizable selection border on the display under the
/// mouse cursor and reports the chosen `Region` back through a completion
/// handler — `nil` if the user cancels (Esc, or the panel closing without a
/// confirm). After a confirm the overlay stays up until `ShareSession`
/// dismisses it: on success once the share is live, or on failure.
@MainActor
final class SelectionOverlayController: NSObject, RegionSelecting {
    /// Debug/accessibility label for the panel. Capture exclusion does not
    /// use it: `CaptureConfig.isOwnWindow` excludes every Skylight window
    /// from the capture by bundle identifier, which is what keeps this
    /// border out of the mirrored output.
    static let windowTitle = "Skylight Selection Overlay"

    private static let logger = Logger(subsystem: "ng.awo.skylight", category: "SelectionOverlay")

    private let initialRegionProvider: () -> Region?

    private var panel: OverlayPanel?
    private var overlayView: SelectionOverlayView?
    private var completion: ((Region?) -> Void)?
    private var targetScreen: NSScreen?
    private var presentedDisplayID: CGDirectDisplayID?

    /// `initialRegionProvider` supplies the last shared region (if any) so
    /// the overlay opens with the previous viewport preselected.
    init(initialRegionProvider: @escaping () -> Region? = { nil }) {
        self.initialRegionProvider = initialRegionProvider
        super.init()
    }

    /// Shows the overlay on the screen under the mouse cursor. Calls
    /// `completion` exactly once.
    func present(completion: @escaping (Region?) -> Void) {
        guard panel == nil else {
            Self.logger.error("present called while an overlay is already showing")
            return
        }
        guard let screen = Self.screenUnderMouse() else {
            Self.logger.error("no screen found under the mouse cursor")
            completion(nil)
            return
        }
        guard let displayID = screen.displayID else {
            Self.logger.error("screen under mouse has no CGDirectDisplayID")
            completion(nil)
            return
        }

        self.completion = completion
        targetScreen = screen
        presentedDisplayID = displayID

        let localBounds = CGRect(origin: .zero, size: screen.frame.size)
        let initialRect = SelectionMath.initialSelectionRect(
            lastRegion: initialRegionProvider(),
            displayID: displayID,
            panelFrame: screen.frame,
            primaryDisplayHeight: Self.primaryDisplayHeight(),
            localBounds: localBounds
        )
        let view = SelectionOverlayView(
            displayBounds: localBounds,
            initialRect: initialRect,
            onConfirm: { [weak self] localRect in self?.handleConfirm(localRect) },
            onCancel: { [weak self] in self?.handleCancel() }
        )
        overlayView = view

        let panel = Self.makePanel(frame: screen.frame, contentView: view)
        self.panel = panel

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
        overlayView = nil
        targetScreen = nil
        presentedDisplayID = nil
        completion = nil
    }

    private func handleConfirm(_ localRect: CGRect) {
        guard let completion else { return }
        self.completion = nil
        // The panel deliberately stays up: the session dismisses it once the
        // share is live, or when the share fails to start.
        completion(region(fromLocalRect: localRect))
    }

    private func handleCancel() {
        guard completion != nil else {
            // Confirm already fired and the share is starting up; the
            // session owns the overlay's fate now, so Esc is ignored.
            // Stopping a live share is the menu's and hotkey's job.
            return
        }
        let completion = completion
        dismiss()
        completion?(nil)
    }

    private func region(fromLocalRect localRect: CGRect) -> Region? {
        guard let presentedDisplayID, let targetScreen else { return nil }
        let cgRect = SelectionMath.globalCGRect(
            localRect: localRect,
            panelFrame: targetScreen.frame,
            primaryDisplayHeight: Self.primaryDisplayHeight()
        )
        return Region(displayID: presentedDisplayID, rect: cgRect)
    }

    private static func screenUnderMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? NSScreen.main
    }

    /// AppKit's global coordinate space is anchored to the primary display's
    /// bottom-left, so its height is what `Geometry`'s flip needs.
    private static func primaryDisplayHeight() -> CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    private static func makePanel(frame: CGRect, contentView: NSView) -> OverlayPanel {
        let panel = OverlayPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = windowTitle
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .screenSaver
        panel.ignoresMouseEvents = false
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.contentView = contentView
        return panel
    }
}

/// A borderless `NSPanel` normally never becomes key, which would swallow
/// the Esc/Return key events the overlay depends on. Overriding
/// `canBecomeKey` is the documented way to opt back in.
private final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }
}
