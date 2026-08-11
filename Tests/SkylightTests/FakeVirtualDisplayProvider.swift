import CoreGraphics
@testable import Skylight

/// In-memory stand-in for VirtualDisplayController — no CGVirtualDisplay
/// SPI call, so consumers of VirtualDisplayProviding are unit-testable
/// without a GUI session.
final class FakeVirtualDisplayProvider: VirtualDisplayProviding {
    private(set) var liveDisplayIDs: Set<CGDirectDisplayID> = []
    private var nextDisplayID: CGDirectDisplayID = 1000

    func createDisplay(
        name: String,
        widthPixels: Int,
        heightPixels: Int,
        scale: Int
    ) throws -> VirtualDisplayHandle {
        guard widthPixels > 0, heightPixels > 0, scale > 0 else {
            throw VirtualDisplayError.invalidDimensions(widthPixels: widthPixels, heightPixels: heightPixels)
        }

        let displayID = nextDisplayID
        nextDisplayID += 1
        liveDisplayIDs.insert(displayID)
        return VirtualDisplayHandle(displayID: displayID)
    }

    func destroyDisplay(_ handle: VirtualDisplayHandle) throws {
        guard liveDisplayIDs.remove(handle.displayID) != nil else {
            throw VirtualDisplayError.displayNotFound(handle.displayID)
        }
    }
}
