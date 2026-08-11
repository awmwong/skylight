import CoreGraphics
import Foundation
@testable import Skylight
import XCTest

final class VirtualDisplayControllerTests: XCTestCase {
    // MARK: - Fake-backed tests (no GUI session or SPI needed)

    func testCreateDisplayReturnsHandleWithLiveDisplayID() throws {
        let provider = FakeVirtualDisplayProvider()

        let handle = try provider.createDisplay(name: "Test", widthPixels: 1280, heightPixels: 720, scale: 1)

        XCTAssertTrue(provider.liveDisplayIDs.contains(handle.displayID))
    }

    func testDestroyDisplayRemovesIt() throws {
        let provider = FakeVirtualDisplayProvider()
        let handle = try provider.createDisplay(name: "Test", widthPixels: 1280, heightPixels: 720, scale: 1)

        try provider.destroyDisplay(handle)

        XCTAssertFalse(provider.liveDisplayIDs.contains(handle.displayID))
    }

    func testDestroyDisplayTwiceThrowsDisplayNotFound() throws {
        let provider = FakeVirtualDisplayProvider()
        let handle = try provider.createDisplay(name: "Test", widthPixels: 1280, heightPixels: 720, scale: 1)
        try provider.destroyDisplay(handle)

        XCTAssertThrowsError(try provider.destroyDisplay(handle)) { error in
            XCTAssertEqual(error as? VirtualDisplayError, .displayNotFound(handle.displayID))
        }
    }

    func testCreateDisplayRejectsNonPositiveDimensions() {
        let provider = FakeVirtualDisplayProvider()

        XCTAssertThrowsError(try provider.createDisplay(
            name: "Test",
            widthPixels: 0,
            heightPixels: 720,
            scale: 1
        )) { error in
            XCTAssertEqual(
                error as? VirtualDisplayError,
                .invalidDimensions(widthPixels: 0, heightPixels: 720)
            )
        }
    }

    func testCreateDisplayRejectsDimensionsBeyondUInt32() {
        // The guard runs before any SPI call, so the real controller is safe
        // to use here. Without it, UInt32(widthPixels) traps.
        let controller = VirtualDisplayController()

        XCTAssertThrowsError(try controller.createDisplay(
            name: "Test",
            widthPixels: Int(UInt32.max) + 1,
            heightPixels: 720,
            scale: 1
        )) { error in
            XCTAssertEqual(
                error as? VirtualDisplayError,
                .invalidDimensions(widthPixels: Int(UInt32.max) + 1, heightPixels: 720)
            )
        }
    }

    // MARK: - Real SPI integration test

    /// Exercises the real CGVirtualDisplay SPI end to end: create a display,
    /// confirm macOS lists it online, destroy it, confirm it's gone. This is
    /// the highest-risk validation in the plan — if CGVirtualDisplay doesn't
    /// work on this macOS version, this test fails and that must be treated
    /// as a blocker, not something to skip or delete.
    func testRealVirtualDisplayLifecycle() throws {
        let controller = VirtualDisplayController()
        let handle = try controller.createDisplay(
            name: "Skylight SPI Test Display",
            widthPixels: 1280,
            heightPixels: 720,
            scale: 1
        )

        let appeared = waitUntil(timeout: 5) { onlineDisplayIDs().contains(handle.displayID) }
        XCTAssertTrue(
            appeared,
            "virtual display \(handle.displayID) never appeared in CGGetOnlineDisplayList"
        )

        try controller.destroyDisplay(handle)

        // Teardown is async: the display disappears shortly after the last
        // strong reference is released, not synchronously with it.
        let disappeared = waitUntil(timeout: 5) { !onlineDisplayIDs().contains(handle.displayID) }
        XCTAssertTrue(disappeared, "virtual display \(handle.displayID) is still online after destroy")
    }
}

private func onlineDisplayIDs(maxDisplays: UInt32 = 32) -> [CGDirectDisplayID] {
    var displayIDs = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
    var actualCount: UInt32 = 0
    CGGetOnlineDisplayList(maxDisplays, &displayIDs, &actualCount)
    return Array(displayIDs.prefix(Int(actualCount)))
}

private func waitUntil(
    timeout: TimeInterval,
    pollInterval: TimeInterval = 0.1,
    _ condition: () -> Bool
) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() {
        if Date() >= deadline {
            return condition()
        }
        // CoreGraphics only refreshes its in-process display list while the
        // run loop turns; a plain Thread.sleep here made this test flaky
        // because CGGetOnlineDisplayList kept returning a stale snapshot.
        RunLoop.current.run(until: Date().addingTimeInterval(pollInterval))
    }
    return true
}
