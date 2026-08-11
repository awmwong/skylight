import AppKit
import CoreMedia

enum MirrorError: Error, Equatable {
    /// The virtual display never showed up in `NSScreen.screens` — AppKit
    /// did not pick up the new display within the polling window.
    case screenNotFound(CGDirectDisplayID)
}

/// What `ShareSession` needs from the mirror output. `DisplayMirror` is the
/// real implementation; tests use a fake.
@MainActor
protocol MirrorPresenting: AnyObject {
    func present(onDisplayID displayID: CGDirectDisplayID) async throws
    func enqueue(_ sampleBuffer: CMSampleBuffer)
    func dismiss()
}

/// Puts the mirror window on the virtual display and feeds it frames. A
/// freshly created CGVirtualDisplay reaches `NSScreen.screens` asynchronously,
/// so `present` polls for it briefly instead of failing on the first miss.
@MainActor
final class DisplayMirror: MirrorPresenting {
    private static let pollInterval: Duration = .milliseconds(50)
    private static let pollAttempts = 60 // 3 seconds total

    private let windowController = MirrorWindowController()

    func present(onDisplayID displayID: CGDirectDisplayID) async throws {
        let screen = try await waitForScreen(displayID: displayID)
        windowController.show(on: screen)
    }

    func enqueue(_ sampleBuffer: CMSampleBuffer) {
        windowController.rendererView.enqueue(sampleBuffer)
    }

    func dismiss() {
        windowController.hide()
    }

    private func waitForScreen(displayID: CGDirectDisplayID) async throws -> NSScreen {
        for _ in 0 ..< Self.pollAttempts {
            if let screen = Self.screen(for: displayID) {
                return screen
            }
            try await Task.sleep(for: Self.pollInterval)
        }
        throw MirrorError.screenNotFound(displayID)
    }

    private static func screen(for displayID: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first { screen in
            let key = NSDeviceDescriptionKey("NSScreenNumber")
            guard let number = screen.deviceDescription[key] as? NSNumber else { return false }
            return CGDirectDisplayID(number.uint32Value) == displayID
        }
    }
}
