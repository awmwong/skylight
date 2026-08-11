@testable import Skylight
import XCTest

final class GeometryTests: XCTestCase {
    // MARK: - AppKit <-> CG coordinate conversion

    func testAppKitToCGRoundTripIsLossless() {
        let primaryDisplayHeight: CGFloat = 1080
        let original = CGRect(x: 100, y: 200, width: 640, height: 360)

        let cgRect = Geometry.convertAppKitToCG(original, primaryDisplayHeight: primaryDisplayHeight)
        let roundTripped = Geometry.convertCGToAppKit(cgRect, primaryDisplayHeight: primaryDisplayHeight)

        XCTAssertEqual(roundTripped, original)
    }

    func testCGToAppKitRoundTripIsLossless() {
        let primaryDisplayHeight: CGFloat = 900
        let original = CGRect(x: -50, y: 30, width: 800, height: 450)

        let appKitRect = Geometry.convertCGToAppKit(original, primaryDisplayHeight: primaryDisplayHeight)
        let roundTripped = Geometry.convertAppKitToCG(appKitRect, primaryDisplayHeight: primaryDisplayHeight)

        XCTAssertEqual(roundTripped, original)
    }

    func testAppKitToCGFlipsAroundPrimaryDisplayHeight() {
        // A rect flush with the AppKit bottom edge should land flush with
        // the CG bottom edge (primaryDisplayHeight - height).
        let rect = CGRect(x: 0, y: 0, width: 100, height: 50)

        let cgRect = Geometry.convertAppKitToCG(rect, primaryDisplayHeight: 1000)

        XCTAssertEqual(cgRect, CGRect(x: 0, y: 950, width: 100, height: 50))
    }

    func testCGToAppKitFlipsAroundPrimaryDisplayHeight() {
        // A rect flush with the CG top edge should land flush with the
        // AppKit top edge (primaryDisplayHeight - height).
        let rect = CGRect(x: 0, y: 0, width: 100, height: 50)

        let appKitRect = Geometry.convertCGToAppKit(rect, primaryDisplayHeight: 1000)

        XCTAssertEqual(appKitRect, CGRect(x: 0, y: 950, width: 100, height: 50))
    }

    // MARK: - Clamping

    func testClampLeavesRectInsideBoundsUnchanged() {
        let bounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let rect = CGRect(x: 100, y: 100, width: 400, height: 300)

        let clamped = Geometry.clamp(rect, toDisplayBounds: bounds)

        XCTAssertEqual(clamped, rect)
    }

    func testClampPullsRectBackWhenOverlappingEdge() {
        let bounds = CGRect(x: 0, y: 0, width: 800, height: 600)
        let rect = CGRect(x: 780, y: 580, width: 64, height: 64)

        let clamped = Geometry.clamp(rect, toDisplayBounds: bounds)

        XCTAssertEqual(clamped, CGRect(x: 736, y: 536, width: 64, height: 64))
        XCTAssertTrue(bounds.contains(clamped))
    }

    func testClampPinsFullyOutsideRectToNearestEdge() {
        let bounds = CGRect(x: 0, y: 0, width: 800, height: 600)
        let rect = CGRect(x: 2000, y: 2000, width: 100, height: 100)

        let clamped = Geometry.clamp(rect, toDisplayBounds: bounds)

        XCTAssertEqual(clamped, CGRect(x: 700, y: 500, width: 100, height: 100))
    }

    func testClampPinsFullyOutsideNegativeRectToNearestEdge() {
        let bounds = CGRect(x: 0, y: 0, width: 800, height: 600)
        let rect = CGRect(x: -500, y: -500, width: 100, height: 100)

        let clamped = Geometry.clamp(rect, toDisplayBounds: bounds)

        XCTAssertEqual(clamped, CGRect(x: 0, y: 0, width: 100, height: 100))
    }

    func testClampEnforcesMinimumSize() {
        let bounds = CGRect(x: 0, y: 0, width: 800, height: 600)
        let rect = CGRect(x: 100, y: 100, width: 10, height: 10)

        let clamped = Geometry.clamp(
            rect,
            toDisplayBounds: bounds,
            minimumSize: CGSize(width: 64, height: 64)
        )

        XCTAssertEqual(clamped.size, CGSize(width: 64, height: 64))
        XCTAssertEqual(clamped.origin, CGPoint(x: 100, y: 100))
    }

    func testClampShiftsOriginWhenMinimumSizeWouldOverflowBounds() {
        let bounds = CGRect(x: 0, y: 0, width: 800, height: 600)
        let rect = CGRect(x: 790, y: 590, width: 10, height: 10)

        let clamped = Geometry.clamp(
            rect,
            toDisplayBounds: bounds,
            minimumSize: CGSize(width: 64, height: 64)
        )

        XCTAssertEqual(clamped, CGRect(x: 736, y: 536, width: 64, height: 64))
    }

    func testClampCapsSizeAtBoundsWhenBoundsSmallerThanMinimum() {
        let bounds = CGRect(x: 0, y: 0, width: 40, height: 30)
        let rect = CGRect(x: 0, y: 0, width: 10, height: 10)

        let clamped = Geometry.clamp(
            rect,
            toDisplayBounds: bounds,
            minimumSize: CGSize(width: 64, height: 64)
        )

        XCTAssertEqual(clamped, CGRect(x: 0, y: 0, width: 40, height: 30))
    }

    // MARK: - Points <-> pixels scaling

    func testPixelSizeAtOneX() {
        let size = CGSize(width: 640, height: 480)

        XCTAssertEqual(Geometry.pixelSize(forPoints: size, scale: 1), size)
    }

    func testPixelSizeAtTwoX() {
        let size = CGSize(width: 640, height: 480)

        XCTAssertEqual(Geometry.pixelSize(forPoints: size, scale: 2), CGSize(width: 1280, height: 960))
    }

    func testPixelRectAtTwoX() {
        let rect = CGRect(x: 10, y: 20, width: 640, height: 480)

        let pixelRect = Geometry.pixelRect(forPoints: rect, scale: 2)

        XCTAssertEqual(pixelRect, CGRect(x: 20, y: 40, width: 1280, height: 960))
    }

    // MARK: - Letterbox fit

    func testLetterboxFitExactAspectFillsTarget() {
        let target = CGSize(width: 1920, height: 1080)
        let source = CGSize(width: 960, height: 540)

        let fitted = Geometry.letterboxFit(source: source, into: target)

        XCTAssertEqual(fitted, CGRect(x: 0, y: 0, width: 1920, height: 1080))
    }

    func testLetterboxFitWiderSourcePillarboxesTopAndBottom() {
        // Source is wider than target: fitted width fills target, height
        // shrinks, leaving bars above/below.
        let target = CGSize(width: 1000, height: 1000)
        let source = CGSize(width: 2000, height: 500)

        let fitted = Geometry.letterboxFit(source: source, into: target)

        XCTAssertEqual(fitted, CGRect(x: 0, y: 375, width: 1000, height: 250))
    }

    func testLetterboxFitTallerSourceBarsLeftAndRight() {
        // Source is taller than target: fitted height fills target, width
        // shrinks, leaving bars left/right.
        let target = CGSize(width: 1000, height: 1000)
        let source = CGSize(width: 500, height: 2000)

        let fitted = Geometry.letterboxFit(source: source, into: target)

        XCTAssertEqual(fitted, CGRect(x: 375, y: 0, width: 250, height: 1000))
    }

    func testLetterboxFitSourceLargerThanTargetScalesDown() {
        let target = CGSize(width: 100, height: 100)
        let source = CGSize(width: 4000, height: 3000)

        let fitted = Geometry.letterboxFit(source: source, into: target)

        XCTAssertEqual(fitted.width, 100, accuracy: 0.001)
        XCTAssertEqual(fitted.height, 75, accuracy: 0.001)
        XCTAssertEqual(fitted.origin, CGPoint(x: 0, y: 12.5))
    }

    func testLetterboxFitZeroSizeSourceReturnsZero() {
        let fitted = Geometry.letterboxFit(source: .zero, into: CGSize(width: 1000, height: 1000))

        XCTAssertEqual(fitted, .zero)
    }

    func testLetterboxFitZeroSizeTargetReturnsZero() {
        let fitted = Geometry.letterboxFit(source: CGSize(width: 100, height: 100), into: .zero)

        XCTAssertEqual(fitted, .zero)
    }
}
