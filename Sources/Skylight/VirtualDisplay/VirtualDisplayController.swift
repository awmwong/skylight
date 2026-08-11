import CoreGraphics
import Dispatch
import Foundation

/// Wraps the private CGVirtualDisplay SPI (declared in
/// Sources/SkylightSPI/CGVirtualDisplaySPI.h). Per SPEC.md, all
/// CGVirtualDisplay usage is confined to this file and the SPI header.
final class VirtualDisplayController: VirtualDisplayProviding {
    // Arbitrary, unregistered vendor/product IDs — CGVirtualDisplay doesn't
    // validate these against any real registry.
    private static let vendorID: UInt32 = 0xF0F0
    private static let productID: UInt32 = 0x0001

    private let queue = DispatchQueue(label: "com.anthony.skylight.virtualdisplay")

    // CGVirtualDisplay has no explicit teardown call: releasing the last
    // strong reference is what makes the display disappear. Holding it here
    // is what keeps it alive.
    private var liveDisplays: [CGDirectDisplayID: CGVirtualDisplay] = [:]
    private var nextSerialNumber: UInt32 = 1

    deinit {
        liveDisplays.removeAll()
    }

    func createDisplay(
        name: String,
        widthPixels: Int,
        heightPixels: Int,
        scale: Int
    ) throws -> VirtualDisplayHandle {
        guard widthPixels > 0, heightPixels > 0, scale > 0 else {
            throw VirtualDisplayError.invalidDimensions(widthPixels: widthPixels, heightPixels: heightPixels)
        }

        let descriptor = CGVirtualDisplayDescriptor()
        descriptor.setDispatchQueue(queue)
        descriptor.name = name
        descriptor.maxPixelsWide = UInt32(widthPixels)
        descriptor.maxPixelsHigh = UInt32(heightPixels)
        descriptor.sizeInMillimeters = Self.physicalSize(widthPixels: widthPixels, heightPixels: heightPixels)
        descriptor.productID = Self.productID
        descriptor.vendorID = Self.vendorID
        descriptor.serialNum = nextSerialNumber
        nextSerialNumber += 1

        let display = CGVirtualDisplay(descriptor: descriptor)
        try apply(scale: scale, widthPixels: widthPixels, heightPixels: heightPixels, to: display)

        let displayID = display.displayID
        guard displayID != kCGNullDirectDisplay else {
            throw VirtualDisplayError.creationFailed
        }

        liveDisplays[displayID] = display
        return VirtualDisplayHandle(displayID: displayID)
    }

    func destroyDisplay(_ handle: VirtualDisplayHandle) throws {
        guard liveDisplays.removeValue(forKey: handle.displayID) != nil else {
            throw VirtualDisplayError.displayNotFound(handle.displayID)
        }
    }

    /// Releases every live display. Call on app quit so a crash mid-share
    /// can't leave a phantom display (see SPEC.md Boundaries).
    func destroyAll() {
        liveDisplays.removeAll()
    }

    private func apply(scale: Int, widthPixels: Int, heightPixels: Int, to display: CGVirtualDisplay) throws {
        // CGVirtualDisplayMode takes point dimensions. CoreGraphics doubles
        // them into the pixel framebuffer when hiDPI is set, so passing
        // pixels/scale here is what makes the resulting display exactly
        // widthPixels x heightPixels.
        let mode = CGVirtualDisplayMode(
            width: UInt(widthPixels / scale),
            height: UInt(heightPixels / scale),
            refreshRate: 60
        )
        let settings = CGVirtualDisplaySettings()
        settings.hiDPI = scale >= 2 ? 1 : 0
        settings.modes = [mode]

        guard display.apply(settings) else {
            throw VirtualDisplayError.settingsRejected
        }
    }

    private static func physicalSize(widthPixels: Int, heightPixels: Int) -> CGSize {
        // Only affects the proportions System Settings draws for the
        // display icon; not tied to any real panel.
        let assumedPixelsPerInch: CGFloat = 110
        let millimetersPerInch: CGFloat = 25.4
        let widthInches = CGFloat(widthPixels) / assumedPixelsPerInch
        let heightInches = CGFloat(heightPixels) / assumedPixelsPerInch
        return CGSize(width: widthInches * millimetersPerInch, height: heightInches * millimetersPerInch)
    }
}
