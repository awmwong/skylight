import CoreGraphics
import CoreMedia
@testable import Skylight
import XCTest

final class PreferencesTests: XCTestCase {
    private static let suiteName = "com.anthony.skylight.tests.preferences"
    private var testDefaults: UserDefaults!
    private var previousDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: Self.suiteName)
        testDefaults.removePersistentDomain(forName: Self.suiteName)
        previousDefaults = Preferences.defaults
        Preferences.defaults = testDefaults
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: Self.suiteName)
        Preferences.defaults = previousDefaults
        super.tearDown()
    }

    func testShowsCursorDefaultsToTrue() {
        XCTAssertTrue(Preferences.showsCursor)
    }

    func testShowsCursorRoundTripsThroughUserDefaults() {
        Preferences.showsCursor = false
        XCTAssertFalse(Preferences.showsCursor)

        Preferences.showsCursor = true
        XCTAssertTrue(Preferences.showsCursor)
    }

    func testLastSharedRegionDefaultsToNil() {
        XCTAssertNil(Preferences.lastSharedRegion)
    }

    func testLastSharedRegionRoundTripsThroughUserDefaults() {
        let region = Region(displayID: 3, rect: CGRect(x: 10, y: 20, width: 640, height: 360))

        Preferences.lastSharedRegion = region
        XCTAssertEqual(Preferences.lastSharedRegion, region)

        Preferences.lastSharedRegion = nil
        XCTAssertNil(Preferences.lastSharedRegion)
    }

    func testLastSharedRegionDropsInvalidStoredValue() {
        Preferences.lastSharedRegion = Region(
            displayID: 3,
            rect: CGRect(x: 0, y: 0, width: -640, height: 360)
        )

        XCTAssertNil(Preferences.lastSharedRegion)
    }
}

@MainActor
final class HotkeyControllerTests: XCTestCase {
    private let region = Region(displayID: 1, rect: CGRect(x: 0, y: 0, width: 100, height: 100))

    func testSharingStateStops() {
        XCTAssertEqual(HotkeyController.action(state: .sharing, lastRegion: region), .stopSharing)
        XCTAssertEqual(HotkeyController.action(state: .sharing, lastRegion: nil), .stopSharing)
    }

    func testIdleWithLastRegionStartsThatRegion() {
        XCTAssertEqual(HotkeyController.action(state: .idle, lastRegion: region), .startSharing(region))
    }

    func testIdleWithNoLastRegionBeginsSelection() {
        XCTAssertEqual(HotkeyController.action(state: .idle, lastRegion: nil), .beginSelection)
    }
}

/// Confirms `ShareSession` reads `Preferences.showsCursor` fresh at each
/// share start, so flipping the setting between shares takes effect on the
/// next one without any capture-side wiring.
@MainActor
final class CaptureOptionsPreferenceTests: XCTestCase {
    private static let suiteName = "com.anthony.skylight.tests.captureoptions"
    private var testDefaults: UserDefaults!
    private var previousDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: Self.suiteName)
        testDefaults.removePersistentDomain(forName: Self.suiteName)
        previousDefaults = Preferences.defaults
        Preferences.defaults = testDefaults
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: Self.suiteName)
        Preferences.defaults = previousDefaults
        super.tearDown()
    }

    func testShareStartPicksUpCurrentCursorPreference() async {
        var receivedOptions: [CaptureOptions] = []
        let session = ShareSession(
            displayProvider: FakeVirtualDisplayProvider(),
            selector: StubSelector(),
            mirror: StubMirror(),
            captureFactory: { _, _, options in
                receivedOptions.append(options)
                return StubCapture()
            },
            sourceDisplayInfo: { _ in
                SourceDisplayInfo(bounds: CGRect(x: 0, y: 0, width: 1000, height: 1000), scale: 1)
            },
            hasScreenRecordingPermission: { true },
            requestScreenRecordingPermission: {},
            captureOptions: { CaptureOptions(showsCursor: Preferences.showsCursor) }
        )
        let region = Region(displayID: 1, rect: CGRect(x: 0, y: 0, width: 10, height: 10))

        Preferences.showsCursor = true
        await session.startSharing(with: region)
        await session.stopSharing()

        Preferences.showsCursor = false
        await session.startSharing(with: region)

        XCTAssertEqual(receivedOptions.map(\.showsCursor), [true, false])
    }
}

private final class StubSelector: RegionSelecting {
    func present(completion _: @escaping (Region?) -> Void) {}
    func dismiss() {}
}

private final class StubMirror: MirrorPresenting {
    func present(onDisplayID _: CGDirectDisplayID) async throws {}
    func enqueue(_: CMSampleBuffer) {}
    func dismiss() {}
}

private final class StubCapture: CaptureSessionControlling {
    let frames = AsyncStream<CMSampleBuffer> { _ in }
    var onError: ((Error) -> Void)?

    func start() async throws {}
    func stop() async {}
}
