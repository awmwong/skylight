import CoreGraphics
import CoreMedia
import ScreenCaptureKit
@testable import Skylight
import XCTest

final class CaptureConfigTests: XCTestCase {
    // MARK: - sourceRect

    func testSourceRectIsRegionRectRelativeToDisplayOrigin() {
        let region = Region(displayID: 1, rect: CGRect(x: 100, y: 200, width: 640, height: 480))

        let config = CaptureConfig(
            region: region,
            displayOrigin: CGPoint(x: 50, y: 150),
            displayScale: 1
        )

        XCTAssertEqual(config.sourceRect, CGRect(x: 50, y: 50, width: 640, height: 480))
    }

    func testSourceRectAtZeroOriginMatchesRegionRect() {
        let region = Region(displayID: 1, rect: CGRect(x: 0, y: 0, width: 320, height: 240))

        let config = CaptureConfig(region: region, displayOrigin: .zero, displayScale: 1)

        XCTAssertEqual(config.sourceRect, region.rect)
    }

    // MARK: - pixel size

    func testPixelSizeAtOneXScaleMatchesPointSize() {
        let region = Region(displayID: 1, rect: CGRect(x: 0, y: 0, width: 640, height: 480))

        let config = CaptureConfig(region: region, displayOrigin: .zero, displayScale: 1)

        XCTAssertEqual(config.pixelWidth, 640)
        XCTAssertEqual(config.pixelHeight, 480)
    }

    func testPixelSizeAtTwoXScaleDoublesPointSize() {
        let region = Region(displayID: 1, rect: CGRect(x: 0, y: 0, width: 640, height: 480))

        let config = CaptureConfig(region: region, displayOrigin: .zero, displayScale: 2)

        XCTAssertEqual(config.pixelWidth, 1280)
        XCTAssertEqual(config.pixelHeight, 960)
    }

    func testOddPixelSizeRoundsDownToEven() {
        // 641pt x 481pt at 1x scale lands on odd pixel counts.
        let region = Region(displayID: 1, rect: CGRect(x: 0, y: 0, width: 641, height: 481))

        let config = CaptureConfig(region: region, displayOrigin: .zero, displayScale: 1)

        XCTAssertEqual(config.pixelWidth, 640)
        XCTAssertEqual(config.pixelHeight, 480)
        XCTAssertEqual(config.pixelWidth % 2, 0)
        XCTAssertEqual(config.pixelHeight % 2, 0)
    }

    func testOddPixelSizeAtTwoXScaleRoundsDownToEven() {
        // 320.5pt width at 2x scale is 641px, still odd.
        let region = Region(displayID: 1, rect: CGRect(x: 0, y: 0, width: 320.5, height: 240.5))

        let config = CaptureConfig(region: region, displayOrigin: .zero, displayScale: 2)

        XCTAssertEqual(config.pixelWidth, 640)
        XCTAssertEqual(config.pixelHeight, 480)
    }

    // MARK: - cursor flag

    func testShowsCursorDefaultsToTrue() {
        let region = Region(displayID: 1, rect: CGRect(x: 0, y: 0, width: 100, height: 100))

        let config = CaptureConfig(region: region, displayOrigin: .zero, displayScale: 1)

        XCTAssertTrue(config.showsCursor)
    }

    func testShowsCursorFalseWhenOptionDisablesIt() {
        let region = Region(displayID: 1, rect: CGRect(x: 0, y: 0, width: 100, height: 100))

        let config = CaptureConfig(
            region: region,
            displayOrigin: .zero,
            displayScale: 1,
            options: CaptureOptions(showsCursor: false)
        )

        XCTAssertFalse(config.showsCursor)
    }

    // MARK: - frame interval

    func testMinimumFrameIntervalDefaultsToThirtyFPS() {
        let region = Region(displayID: 1, rect: CGRect(x: 0, y: 0, width: 100, height: 100))

        let config = CaptureConfig(region: region, displayOrigin: .zero, displayScale: 1)

        XCTAssertEqual(config.minimumFrameInterval, CMTime(value: 1, timescale: 30))
    }

    func testMinimumFrameIntervalHonorsCustomFPS() {
        let region = Region(displayID: 1, rect: CGRect(x: 0, y: 0, width: 100, height: 100))

        let config = CaptureConfig(
            region: region,
            displayOrigin: .zero,
            displayScale: 1,
            options: CaptureOptions(framesPerSecond: 60)
        )

        XCTAssertEqual(config.minimumFrameInterval, CMTime(value: 1, timescale: 60))
    }

    // MARK: - apply(to:)

    func testApplySetsAllFieldsOnStreamConfiguration() {
        let region = Region(displayID: 1, rect: CGRect(x: 100, y: 200, width: 640, height: 480))
        let config = CaptureConfig(
            region: region,
            displayOrigin: CGPoint(x: 50, y: 150),
            displayScale: 2,
            options: CaptureOptions(showsCursor: false, framesPerSecond: 60)
        )
        let streamConfiguration = SCStreamConfiguration()

        config.apply(to: streamConfiguration)

        XCTAssertEqual(streamConfiguration.sourceRect, CGRect(x: 50, y: 50, width: 640, height: 480))
        XCTAssertEqual(streamConfiguration.width, 1280)
        XCTAssertEqual(streamConfiguration.height, 960)
        XCTAssertFalse(streamConfiguration.showsCursor)
        XCTAssertEqual(streamConfiguration.minimumFrameInterval, CMTime(value: 1, timescale: 60))
    }
}
