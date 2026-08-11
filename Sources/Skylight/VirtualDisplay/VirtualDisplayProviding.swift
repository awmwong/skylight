import CoreGraphics

/// A live virtual display. Opaque outside VirtualDisplay/ — consumers only
/// need the display ID to hand to ScreenCaptureKit or CGGetOnlineDisplayList.
struct VirtualDisplayHandle: Equatable {
    let displayID: CGDirectDisplayID
}

enum VirtualDisplayError: Error, Equatable {
    /// widthPixels/heightPixels/scale must all be positive.
    case invalidDimensions(widthPixels: Int, heightPixels: Int)
    /// The SPI produced a display with no usable display ID.
    case creationFailed
    /// CGVirtualDisplay.applySettings returned false.
    case settingsRejected
    /// destroyDisplay was called with a handle that is not currently live
    /// (already destroyed, or never created by this provider).
    case displayNotFound(CGDirectDisplayID)
}

/// Isolates CGVirtualDisplay SPI usage so callers are testable with a fake.
protocol VirtualDisplayProviding: AnyObject {
    func createDisplay(name: String, widthPixels: Int, heightPixels: Int, scale: Int) throws
        -> VirtualDisplayHandle
    func destroyDisplay(_ handle: VirtualDisplayHandle) throws
}
