import AppKit
import CoreGraphics
import os

/// Presents a draggable, resizable selection border on the display under the
/// mouse cursor and reports the chosen `Region` back through a completion
/// handler — `nil` if the user cancels (Esc, or the panel closing without a
/// confirm).
@MainActor
final class SelectionOverlayController: NSObject {
    /// The capture filter (T4) excludes any window with this title, so the
    /// selection border never appears in the mirrored output.
    static let windowTitle = "Skylight Selection Overlay"

    private static let logger = Logger(subsystem: "com.anthony.skylight", category: "SelectionOverlay")
    private static let initialRectFraction: CGFloat = 0.5

    private var panel: OverlayPanel?
    private var overlayView: SelectionOverlayView?
    private var completion: ((Region?) -> Void)?
    private var targetScreen: NSScreen?

    /// Shows the overlay on the screen under the mouse cursor. Calls
    /// `completion` exactly once.
    func present(completion: @escaping (Region?) -> Void) {
        guard self.completion == nil else {
            Self.logger.error("present called while an overlay is already showing")
            return
        }
        guard let screen = Self.screenUnderMouse() else {
            Self.logger.error("no screen found under the mouse cursor")
            completion(nil)
            return
        }
        guard let displayID = Self.displayID(for: screen) else {
            Self.logger.error("screen under mouse has no CGDirectDisplayID")
            completion(nil)
            return
        }

        self.completion = completion
        targetScreen = screen

        let localBounds = CGRect(origin: .zero, size: screen.frame.size)
        let view = SelectionOverlayView(
            displayBounds: localBounds,
            initialRect: Self.initialSelectionRect(in: localBounds),
            onConfirm: { [weak self] localRect in self?.finish(with: localRect, displayID: displayID) },
            onCancel: { [weak self] in self?.finish(with: nil, displayID: displayID) }
        )
        overlayView = view

        let panel = Self.makePanel(frame: screen.frame, contentView: view)
        self.panel = panel

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func finish(with localRect: CGRect?, displayID: CGDirectDisplayID) {
        let region = localRect.map { rect -> Region in
            let cgRect = SelectionMath.globalCGRect(
                localRect: rect,
                panelFrame: targetScreen?.frame ?? .zero,
                primaryDisplayHeight: Self.primaryDisplayHeight()
            )
            return Region(displayID: displayID, rect: cgRect)
        }

        panel?.orderOut(nil)
        panel = nil
        overlayView = nil
        targetScreen = nil

        let completion = completion
        self.completion = nil
        completion?(region)
    }

    private static func initialSelectionRect(in bounds: CGRect) -> CGRect {
        let size = CGSize(
            width: bounds.width * initialRectFraction,
            height: bounds.height * initialRectFraction
        )
        let origin = CGPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2)
        return CGRect(origin: origin, size: size)
    }

    private static func screenUnderMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? NSScreen.main
    }

    private static func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        else {
            return nil
        }
        return CGDirectDisplayID(number.uint32Value)
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
