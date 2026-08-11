import AppKit

/// Borderless window that fills a given `NSScreen` (the virtual display) and
/// hosts the `FrameRendererView`. Click-through and excluded from Cmd-Tab and
/// Mission Control window cycling so it never intercepts input or shows up as
/// a stray window.
///
/// `sharingType` is deliberately left at its default (`.readOnly`): a
/// conferencing app shares "Skylight Display" as a whole-screen capture, and
/// setting `.none` would make this window's content invisible to that
/// capture too, defeating the entire point of the app.
@MainActor
final class MirrorWindowController: NSWindowController {
    let rendererView = FrameRendererView(frame: .zero)

    init() {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .normal
        panel.isOpaque = true
        panel.hasShadow = false
        panel.isFloatingPanel = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.ignoresMouseEvents = true
        panel.isExcludedFromWindowsMenu = true
        panel.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle, .stationary]

        super.init(window: panel)
        panel.contentView = rendererView
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Resizes the window to exactly cover `screen` and brings it on-screen
    /// without stealing key/main status or activating the app.
    func show(on screen: NSScreen) {
        guard let window else { return }
        window.setFrame(screen.frame, display: true)
        window.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
    }
}
