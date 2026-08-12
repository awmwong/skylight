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
///
/// A conferencing app captures the window at its current backing-pixel size,
/// so that size *is* the shared resolution. The title shows it live, and
/// `snapToActualSize` sets the window so its backing pixels equal the region's
/// native capture resolution (1:1, best fidelity).
@MainActor
final class MirrorWindowController: NSWindowController, MirrorPresenting, NSWindowDelegate {
    var onClose: (() -> Void)?

    let rendererView = FrameRendererView(frame: .zero)

    private var presentedContentSize = CGSize(width: 640, height: 360)

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
        presentedContentSize = contentSize
        let size = Self.initialContentSize(for: contentSize)
        window.contentAspectRatio = size
        window.setContentSize(size)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        updateTitle()
    }

    func enqueue(_ sampleBuffer: CMSampleBuffer) {
        rendererView.enqueue(sampleBuffer)
    }

    func dismiss() {
        window?.orderOut(nil)
    }

    /// Resizes the window so its backing pixels equal the region's native
    /// capture resolution — a 1:1 share with no scaling. Uses the live buffer
    /// size once frames flow, or the region's point size before then.
    func snapToActualSize() {
        guard let window else { return }
        let scale = window.backingScaleFactor
        let points: CGSize = if let pixels = rendererView.sourcePixelSize {
            Self.actualSizeContentPoints(pixelSize: pixels, backingScale: scale)
        } else {
            presentedContentSize
        }
        window.contentAspectRatio = points
        window.setContentSize(points)
        updateTitle()
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }

    func windowDidResize(_ notification: Notification) {
        updateTitle()
    }

    // MARK: - Helpers

    /// The window content size, in points, whose backing pixels equal
    /// `pixelSize` on a `backingScale` display.
    nonisolated static func actualSizeContentPoints(pixelSize: CGSize, backingScale: CGFloat) -> CGSize {
        let scale = backingScale > 0 ? backingScale : 1
        return CGSize(width: pixelSize.width / scale, height: pixelSize.height / scale)
    }

    /// Shows the shared resolution — the window's content in backing pixels,
    /// which is exactly what a conferencing app captures.
    private func updateTitle() {
        guard let window else { return }
        let backing = rendererView.convertToBacking(rendererView.bounds).size
        let width = Int(backing.width.rounded())
        let height = Int(backing.height.rounded())
        window.title = "\(AppInfo.sharedWindowTitle) · \(width)×\(height)"
    }

    /// The region at 1:1, but never larger than half the main screen, so a
    /// full-display region does not open a window that fills the screen. The
    /// user can resize from there, or hit Actual Size; `FrameRendererView`
    /// letterboxes.
    private static func initialContentSize(for content: CGSize) -> NSSize {
        guard content.width > 0, content.height > 0 else {
            return NSSize(width: 640, height: 360)
        }
        let maxWidth = (NSScreen.main?.visibleFrame.width ?? 1440) * 0.5
        let scale = min(1, maxWidth / content.width)
        return NSSize(width: content.width * scale, height: content.height * scale)
    }
}
