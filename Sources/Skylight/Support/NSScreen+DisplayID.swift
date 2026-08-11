import AppKit
import CoreGraphics

extension NSScreen {
    /// The CoreGraphics display this screen shows, or nil if AppKit exposes
    /// no NSScreenNumber for it.
    var displayID: CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let number = deviceDescription[key] as? NSNumber else { return nil }
        return CGDirectDisplayID(number.uint32Value)
    }

    static func screen(for displayID: CGDirectDisplayID) -> NSScreen? {
        screens.first { $0.displayID == displayID }
    }
}
