import CoreGraphics
import CoreMedia

/// What `ShareSession` needs from the mirror output: a window that shows the
/// live region and that the user shares in a conferencing app.
/// `MirrorWindowController` is the real implementation; tests use a fake.
@MainActor
protocol MirrorPresenting: AnyObject {
    /// The user closed the mirror window. The session treats this as "stop
    /// sharing".
    var onClose: (() -> Void)? { get set }

    /// Shows the mirror window, sized from the region's point size.
    func present(contentSize: CGSize)
    func enqueue(_ sampleBuffer: CMSampleBuffer)
    func dismiss()
}
