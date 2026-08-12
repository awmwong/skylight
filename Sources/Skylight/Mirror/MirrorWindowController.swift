import AppKit
import CoreMedia

/// A normal titled, resizable window that shows the live region. The user
/// shares this window ("A window" in Meet/Zoom); viewers see only the region.
///
/// It is a real, movable window on purpose — you can park it anywhere, and a
/// window share keeps capturing it even while it is occluded or on another
/// Space. `CaptureConfig.isOwnWindow` excludes it from Skylight's own
/// ScreenCaptureKit capture, so dragging it over the captured region never
/// produces a recursive "hall of mirrors".
@MainActor
final class MirrorWindowController: NSWindowController, MirrorPresenting, NSWindowDelegate {
    var onClose: (() -> Void)?

    let rendererView = FrameRendererView(frame: .zero)

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 360),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = AppInfo.sharedWindowTitle
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.contentAspectRatio = NSSize(width: 16, height: 9)
        window.contentView = rendererView

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func present(contentSize: CGSize) {
        guard let window else { return }
        let size = Self.initialContentSize(for: contentSize)
        window.contentAspectRatio = size
        window.setContentSize(size)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func enqueue(_ sampleBuffer: CMSampleBuffer) {
        rendererView.enqueue(sampleBuffer)
    }

    func dismiss() {
        window?.orderOut(nil)
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }

    /// The region at 1:1, but never larger than half the main screen, so a
    /// full-display region does not open a window that fills the screen. The
    /// user can resize from there; `FrameRendererView` letterboxes.
    private static func initialContentSize(for content: CGSize) -> NSSize {
        guard content.width > 0, content.height > 0 else {
            return NSSize(width: 640, height: 360)
        }
        let maxWidth = (NSScreen.main?.visibleFrame.width ?? 1440) * 0.5
        let scale = min(1, maxWidth / content.width)
        return NSSize(width: content.width * scale, height: content.height * scale)
    }
}
