import CoreGraphics
import CoreMedia
@testable import Skylight
import XCTest

@MainActor
final class ShareSessionTests: XCTestCase {
    private var selector: FakeSelector!
    private var mirror: FakeMirror!
    private var captures: [FakeCapture]!
    private var surfacedErrors: [String]!
    private var persistedRegions: [Region]!

    private let region = Region(
        displayID: 1,
        rect: CGRect(x: 100, y: 50, width: 640, height: 360)
    )

    override func setUp() {
        super.setUp()
        selector = FakeSelector()
        mirror = FakeMirror()
        captures = []
        surfacedErrors = []
        persistedRegions = []
    }

    private func makeSession(
        hasPermission: Bool = true,
        captureStartError: Error? = nil
    ) -> ShareSession {
        let session = ShareSession(
            selector: selector,
            mirror: mirror,
            captureFactory: { [self] region, _, _ in
                let capture = FakeCapture(region: region, startError: captureStartError)
                captures.append(capture)
                return capture
            },
            sourceDisplayInfo: { displayID in
                guard displayID == 1 else { return nil }
                return SourceDisplayInfo(
                    bounds: CGRect(x: 0, y: 0, width: 2000, height: 1200),
                    scale: 2
                )
            },
            hasScreenRecordingPermission: { hasPermission },
            requestScreenRecordingPermission: {},
            persistLastRegion: { [self] region in persistedRegions.append(region) }
        )
        session.onUserFacingError = { [self] message in surfacedErrors.append(message) }
        return session
    }

    // MARK: - Selection flow

    func testConfirmedSelectionStartsSharing() async throws {
        let session = makeSession()
        session.beginSelection()
        XCTAssertEqual(session.state, .selecting)

        selector.confirm(region)
        try await waitUntil("session starts sharing") { session.state == .sharing }

        XCTAssertEqual(session.currentRegion, region)
        XCTAssertEqual(captures.count, 1)
        XCTAssertTrue(captures[0].started)
        XCTAssertEqual(mirror.presentCount, 1)
        XCTAssertEqual(mirror.presentedSizes, [region.rect.size])
        XCTAssertTrue(selector.dismissed, "the overlay must go away once the share is live")
        XCTAssertEqual(persistedRegions, [region])
    }

    func testCancelledSelectionReturnsToIdle() {
        let session = makeSession()
        session.beginSelection()

        selector.cancel()

        XCTAssertEqual(session.state, .idle)
        XCTAssertTrue(captures.isEmpty)
        XCTAssertEqual(mirror.presentCount, 0)
        XCTAssertTrue(selector.dismissed)
    }

    func testBeginSelectionWhileSelectingIsIgnored() {
        let session = makeSession()
        session.beginSelection()
        session.beginSelection()
        XCTAssertEqual(selector.presentCount, 1)
    }

    // MARK: - Permission

    func testMissingPermissionSurfacesErrorAndStaysIdle() async throws {
        let session = makeSession(hasPermission: false)
        session.beginSelection()

        selector.confirm(region)
        try await waitUntil("permission error surfaces") { [self] in surfacedErrors.count == 1 }

        XCTAssertEqual(session.state, .idle)
        XCTAssertEqual(mirror.presentCount, 0)
        XCTAssertTrue(selector.dismissed)
    }

    // MARK: - Failure cleanup

    func testCaptureStartFailureReturnsToIdleWithoutPresenting() async throws {
        let session = makeSession(captureStartError: CaptureError.displayNotFound(1))
        session.beginSelection()

        selector.confirm(region)
        try await waitUntil("share failure surfaces") { [self] in surfacedErrors.count == 1 }

        XCTAssertEqual(session.state, .idle)
        XCTAssertEqual(mirror.presentCount, 0, "a failed capture must not show a mirror window")
        XCTAssertTrue(mirror.dismissed)
        XCTAssertTrue(selector.dismissed)
    }

    // MARK: - Stop

    func testStopSharingTearsEverythingDown() async throws {
        let session = makeSession()
        session.beginSelection()
        selector.confirm(region)
        try await waitUntil("session starts sharing") { session.state == .sharing }

        await session.stopSharing()

        XCTAssertEqual(session.state, .idle)
        XCTAssertTrue(captures[0].stopped)
        XCTAssertTrue(mirror.dismissed)
        XCTAssertTrue(selector.dismissed)
    }

    func testClosingMirrorWindowStopsSharing() async throws {
        let session = makeSession()
        session.beginSelection()
        selector.confirm(region)
        try await waitUntil("session starts sharing") { session.state == .sharing }

        mirror.closeWindow()
        try await waitUntil("session returns to idle") { session.state == .idle }

        XCTAssertTrue(captures[0].stopped)
    }

    // MARK: - Preset recall

    func testStartSharingWithRegionSkipsSelection() async {
        let session = makeSession()
        await session.startSharing(with: region)

        XCTAssertEqual(session.state, .sharing)
        XCTAssertEqual(selector.presentCount, 0)
        XCTAssertEqual(mirror.presentCount, 1)
    }

    func testRecalledRegionIsClampedToCurrentDisplayBounds() async {
        let session = makeSession()
        let offscreen = Region(displayID: 1, rect: CGRect(x: 1800, y: 1000, width: 640, height: 360))

        await session.startSharing(with: offscreen)

        XCTAssertEqual(session.state, .sharing)
        let clamped = CGRect(x: 1360, y: 840, width: 640, height: 360)
        XCTAssertEqual(captures[0].region.rect, clamped)
        XCTAssertEqual(session.currentRegion?.rect, clamped)
        XCTAssertEqual(persistedRegions.map(\.rect), [clamped], "the clamped region is what persists")
    }

    func testStartSharingWithRegionWhileSharingRestartsWithNewRegion() async {
        let session = makeSession()
        await session.startSharing(with: region)
        let second = Region(displayID: 1, rect: CGRect(x: 0, y: 0, width: 320, height: 180))

        await session.startSharing(with: second)

        XCTAssertEqual(session.state, .sharing)
        XCTAssertEqual(captures.count, 2)
        XCTAssertEqual(captures[0].stopCount, 1)
        XCTAssertEqual(mirror.presentCount, 2)
        XCTAssertEqual(session.currentRegion, second)
    }

    // MARK: - Teardown re-entrancy

    func testConcurrentStopSharingStopsCaptureOnce() async {
        let session = makeSession()
        await session.startSharing(with: region)

        async let first: Void = session.stopSharing()
        async let second: Void = session.stopSharing()
        _ = await (first, second)

        XCTAssertEqual(session.state, .idle)
        XCTAssertEqual(captures[0].stopCount, 1)
        XCTAssertTrue(surfacedErrors.isEmpty)
    }

    // MARK: - Frame pump

    func testFramesFlowFromCaptureToMirror() async throws {
        let session = makeSession()
        session.beginSelection()
        selector.confirm(region)
        try await waitUntil("session starts sharing") { session.state == .sharing }

        let buffer = try SampleBufferFixtures.make(width: 64, height: 36)
        captures[0].yield(buffer)

        try await waitUntil("mirror received a frame") { [self] in mirror.enqueuedCount == 1 }
        _ = session // keep the session (and its frame pump) alive until the assertion ran
    }

    private func waitUntil(
        _ what: String,
        timeout: TimeInterval = 2,
        condition: @MainActor () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            guard Date() < deadline else {
                return XCTFail("timed out waiting until \(what)")
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}
