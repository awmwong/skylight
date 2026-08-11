import CoreGraphics
import CoreMedia
@testable import Skylight
import XCTest

@MainActor
final class ShareSessionTests: XCTestCase {
    private var displays: RecordingDisplayProvider!
    private var selector: FakeSelector!
    private var mirror: FakeMirror!
    private var captures: [FakeCapture]!
    private var surfacedErrors: [String]!

    private let region = Region(
        displayID: 1,
        rect: CGRect(x: 100, y: 50, width: 640, height: 360)
    )

    override func setUp() {
        super.setUp()
        displays = RecordingDisplayProvider()
        selector = FakeSelector()
        mirror = FakeMirror()
        captures = []
        surfacedErrors = []
    }

    private func makeSession(
        hasPermission: Bool = true,
        captureStartError: Error? = nil
    ) -> ShareSession {
        let session = ShareSession(
            displayProvider: displays,
            selector: selector,
            mirror: mirror,
            captureFactory: { [self] region, _, _ in
                let capture = FakeCapture(region: region, startError: captureStartError)
                captures.append(capture)
                return capture
            },
            sourceDisplayInfo: { displayID in
                guard displayID == 1 else { return nil }
                return SourceDisplayInfo(originCG: .zero, scale: 2)
            },
            hasScreenRecordingPermission: { hasPermission },
            requestScreenRecordingPermission: {}
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
        // 640x360 points at 2x scale.
        XCTAssertEqual(displays.createCalls.count, 1)
        XCTAssertEqual(displays.createCalls[0].widthPixels, 1280)
        XCTAssertEqual(displays.createCalls[0].heightPixels, 720)
        XCTAssertEqual(displays.createCalls[0].scale, 2)
        XCTAssertEqual(captures.count, 1)
        XCTAssertTrue(captures[0].started)
        XCTAssertEqual(mirror.presentedDisplayIDs, try [XCTUnwrap(displays.lastHandle?.displayID)])
        XCTAssertTrue(selector.inSharingMode)
    }

    func testCancelledSelectionReturnsToIdle() {
        let session = makeSession()
        session.beginSelection()

        selector.cancel()

        XCTAssertEqual(session.state, .idle)
        XCTAssertTrue(displays.createCalls.isEmpty)
        XCTAssertTrue(captures.isEmpty)
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
        XCTAssertTrue(displays.createCalls.isEmpty)
        XCTAssertTrue(selector.dismissed)
    }

    // MARK: - Failure cleanup

    func testCaptureStartFailureDestroysDisplayAndReturnsToIdle() async throws {
        let session = makeSession(captureStartError: CaptureError.displayNotFound(1))
        session.beginSelection()

        selector.confirm(region)
        try await waitUntil("share failure surfaces") { [self] in surfacedErrors.count == 1 }

        XCTAssertEqual(session.state, .idle)
        XCTAssertEqual(displays.createCalls.count, 1)
        XCTAssertTrue(displays.liveDisplayIDs.isEmpty, "failed share must not leak a display")
        XCTAssertTrue(mirror.presentedDisplayIDs.isEmpty)
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
        XCTAssertTrue(displays.liveDisplayIDs.isEmpty)
    }

    // MARK: - Live region updates

    func testRegionChangeUpdatesCaptureWithoutRecreatingDisplay() async throws {
        let session = makeSession()
        session.beginSelection()
        selector.confirm(region)
        try await waitUntil("session starts sharing") { session.state == .sharing }

        let moved = Region(displayID: 1, rect: region.rect.offsetBy(dx: 40, dy: 20))
        selector.change(moved)
        await session.settlePendingRegionUpdates()

        XCTAssertEqual(captures[0].updatedRegions.last, moved)
        XCTAssertEqual(session.currentRegion, moved)
        XCTAssertEqual(displays.createCalls.count, 1, "mid-share resize letterboxes; no display recreation")
    }

    // MARK: - Preset recall

    func testStartSharingWithRegionSkipsSelection() async {
        let session = makeSession()
        await session.startSharing(with: region)

        XCTAssertEqual(session.state, .sharing)
        XCTAssertEqual(selector.presentCount, 0)
        XCTAssertEqual(displays.createCalls.count, 1)
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

    // MARK: - Termination

    func testTerminateDestroysAllDisplays() async throws {
        let session = makeSession()
        session.beginSelection()
        selector.confirm(region)
        try await waitUntil("session starts sharing") { session.state == .sharing }

        session.terminate()

        XCTAssertTrue(displays.destroyAllCalled)
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

// MARK: - Fakes

@MainActor
private final class FakeSelector: RegionSelecting {
    private(set) var presentCount = 0
    private(set) var inSharingMode = false
    private(set) var dismissed = false
    private var onChange: ((Region) -> Void)?
    private var completion: ((Region?) -> Void)?

    func present(onChange: @escaping (Region) -> Void, completion: @escaping (Region?) -> Void) {
        presentCount += 1
        self.onChange = onChange
        self.completion = completion
    }

    func enterSharingMode(onStop _: @escaping () -> Void) {
        inSharingMode = true
    }

    func dismiss() {
        dismissed = true
    }

    /// Simulates the user confirming. The share start-up it triggers is
    /// async — tests wait on an observable condition afterwards.
    func confirm(_ region: Region) {
        completion?(region)
    }

    func cancel() {
        completion?(nil)
    }

    func change(_ region: Region) {
        onChange?(region)
    }
}

@MainActor
private final class FakeMirror: MirrorPresenting {
    private(set) var presentedDisplayIDs: [CGDirectDisplayID] = []
    private(set) var enqueuedCount = 0
    private(set) var dismissed = false

    func present(onDisplayID displayID: CGDirectDisplayID) async throws {
        presentedDisplayIDs.append(displayID)
    }

    func enqueue(_: CMSampleBuffer) {
        enqueuedCount += 1
    }

    func dismiss() {
        dismissed = true
    }
}

private final class FakeCapture: CaptureSessionControlling {
    let frames: AsyncStream<CMSampleBuffer>
    var onError: ((Error) -> Void)?

    private(set) var started = false
    private(set) var stopped = false
    private(set) var updatedRegions: [Region] = []

    private let startError: Error?
    private var continuation: AsyncStream<CMSampleBuffer>.Continuation?

    init(region _: Region, startError: Error?) {
        self.startError = startError
        var continuation: AsyncStream<CMSampleBuffer>.Continuation?
        frames = AsyncStream { continuation = $0 }
        self.continuation = continuation
    }

    func start() async throws {
        if let startError {
            throw startError
        }
        started = true
    }

    func stop() async {
        stopped = true
        continuation?.finish()
    }

    func updateRegion(_ region: Region) async throws {
        updatedRegions.append(region)
    }

    func yield(_ buffer: CMSampleBuffer) {
        continuation?.yield(buffer)
    }
}

/// Wraps the shared fake with call recording ShareSession tests need.
private final class RecordingDisplayProvider: VirtualDisplayProviding {
    struct CreateCall: Equatable {
        let name: String
        let widthPixels: Int
        let heightPixels: Int
        let scale: Int
    }

    private let fake = FakeVirtualDisplayProvider()
    private(set) var createCalls: [CreateCall] = []
    private(set) var lastHandle: VirtualDisplayHandle?
    private(set) var destroyAllCalled = false

    var liveDisplayIDs: Set<CGDirectDisplayID> {
        fake.liveDisplayIDs
    }

    func createDisplay(
        name: String,
        widthPixels: Int,
        heightPixels: Int,
        scale: Int
    ) throws -> VirtualDisplayHandle {
        let handle = try fake.createDisplay(
            name: name,
            widthPixels: widthPixels,
            heightPixels: heightPixels,
            scale: scale
        )
        createCalls.append(
            CreateCall(name: name, widthPixels: widthPixels, heightPixels: heightPixels, scale: scale)
        )
        lastHandle = handle
        return handle
    }

    func destroyDisplay(_ handle: VirtualDisplayHandle) throws {
        try fake.destroyDisplay(handle)
    }

    func destroyAll() {
        destroyAllCalled = true
        fake.destroyAll()
    }
}
