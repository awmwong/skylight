@testable import Skylight
import XCTest

final class SelectionMathTests: XCTestCase {
    private let rect = CGRect(x: 500, y: 500, width: 200, height: 150)
    private let hugeBounds = CGRect(x: 0, y: 0, width: 4000, height: 4000)

    // MARK: - Handle points

    func testHandlePointsSitOnRectCornersAndEdgeMidpoints() {
        XCTAssertEqual(SelectionMath.handlePoint(.topLeft, in: rect), CGPoint(x: rect.minX, y: rect.maxY))
        XCTAssertEqual(SelectionMath.handlePoint(.top, in: rect), CGPoint(x: rect.midX, y: rect.maxY))
        XCTAssertEqual(SelectionMath.handlePoint(.topRight, in: rect), CGPoint(x: rect.maxX, y: rect.maxY))
        XCTAssertEqual(SelectionMath.handlePoint(.right, in: rect), CGPoint(x: rect.maxX, y: rect.midY))
        XCTAssertEqual(SelectionMath.handlePoint(.bottomRight, in: rect), CGPoint(x: rect.maxX, y: rect.minY))
        XCTAssertEqual(SelectionMath.handlePoint(.bottom, in: rect), CGPoint(x: rect.midX, y: rect.minY))
        XCTAssertEqual(SelectionMath.handlePoint(.bottomLeft, in: rect), CGPoint(x: rect.minX, y: rect.minY))
        XCTAssertEqual(SelectionMath.handlePoint(.left, in: rect), CGPoint(x: rect.minX, y: rect.midY))
    }

    // MARK: - Hit testing

    func testHandleHitTestingFindsEachHandleAtItsPoint() {
        for handle in SelectionHandle.allCases {
            let point = SelectionMath.handlePoint(handle, in: rect)
            XCTAssertEqual(
                SelectionMath.handle(at: point, in: rect),
                handle,
                "expected \(handle) at \(point)"
            )
        }
    }

    func testHandleHitTestingReturnsNilAwayFromHandles() {
        let centerPoint = CGPoint(x: rect.midX, y: rect.midY)

        XCTAssertNil(SelectionMath.handle(at: centerPoint, in: rect))
    }

    func testDragKindReturnsMoveWhenInsideRectAwayFromHandles() {
        let centerPoint = CGPoint(x: rect.midX, y: rect.midY)

        XCTAssertEqual(SelectionMath.dragKind(at: centerPoint, in: rect), .move)
    }

    func testDragKindReturnsNilOutsideRectAndHandles() {
        let farPoint = CGPoint(x: rect.minX - 100, y: rect.minY - 100)

        XCTAssertNil(SelectionMath.dragKind(at: farPoint, in: rect))
    }

    func testDragKindPrioritizesHandleOverMove() {
        let topLeftPoint = SelectionMath.handlePoint(.topLeft, in: rect)

        XCTAssertEqual(SelectionMath.dragKind(at: topLeftPoint, in: rect), .resize(.topLeft))
    }

    // MARK: - Resize: one test per handle, huge bounds so clamping never engages

    func testResizeLeftHandleMovesLeftEdge() {
        let result = SelectionMath.updatedRect(
            for: .resize(.left),
            startRect: rect,
            translation: CGSize(width: 20, height: 0),
            displayBounds: hugeBounds
        )

        XCTAssertEqual(result, CGRect(x: 520, y: 500, width: 180, height: 150))
    }

    func testResizeRightHandleMovesRightEdge() {
        let result = SelectionMath.updatedRect(
            for: .resize(.right),
            startRect: rect,
            translation: CGSize(width: 20, height: 0),
            displayBounds: hugeBounds
        )

        XCTAssertEqual(result, CGRect(x: 500, y: 500, width: 220, height: 150))
    }

    func testResizeTopHandleMovesTopEdge() {
        let result = SelectionMath.updatedRect(
            for: .resize(.top),
            startRect: rect,
            translation: CGSize(width: 0, height: 20),
            displayBounds: hugeBounds
        )

        XCTAssertEqual(result, CGRect(x: 500, y: 500, width: 200, height: 170))
    }

    func testResizeBottomHandleMovesBottomEdge() {
        let result = SelectionMath.updatedRect(
            for: .resize(.bottom),
            startRect: rect,
            translation: CGSize(width: 0, height: 20),
            displayBounds: hugeBounds
        )

        XCTAssertEqual(result, CGRect(x: 500, y: 520, width: 200, height: 130))
    }

    func testResizeTopLeftHandleMovesLeftAndTopEdges() {
        let result = SelectionMath.updatedRect(
            for: .resize(.topLeft),
            startRect: rect,
            translation: CGSize(width: -10, height: 20),
            displayBounds: hugeBounds
        )

        XCTAssertEqual(result, CGRect(x: 490, y: 500, width: 210, height: 170))
    }

    func testResizeTopRightHandleMovesRightAndTopEdges() {
        let result = SelectionMath.updatedRect(
            for: .resize(.topRight),
            startRect: rect,
            translation: CGSize(width: 10, height: 20),
            displayBounds: hugeBounds
        )

        XCTAssertEqual(result, CGRect(x: 500, y: 500, width: 210, height: 170))
    }

    func testResizeBottomRightHandleMovesRightAndBottomEdges() {
        let result = SelectionMath.updatedRect(
            for: .resize(.bottomRight),
            startRect: rect,
            translation: CGSize(width: 10, height: -20),
            displayBounds: hugeBounds
        )

        XCTAssertEqual(result, CGRect(x: 500, y: 480, width: 210, height: 170))
    }

    func testResizeBottomLeftHandleMovesLeftAndBottomEdges() {
        let result = SelectionMath.updatedRect(
            for: .resize(.bottomLeft),
            startRect: rect,
            translation: CGSize(width: -10, height: -20),
            displayBounds: hugeBounds
        )

        XCTAssertEqual(result, CGRect(x: 490, y: 480, width: 210, height: 170))
    }

    // MARK: - Move

    func testMoveTranslatesRectWithoutChangingSize() {
        let result = SelectionMath.updatedRect(
            for: .move,
            startRect: rect,
            translation: CGSize(width: 30, height: -15),
            displayBounds: hugeBounds
        )

        XCTAssertEqual(result, CGRect(x: 530, y: 485, width: 200, height: 150))
    }

    // MARK: - Minimum size enforcement

    func testResizeEnforcesMinimumSizeAndKeepsFixedEdgeAnchored() {
        let startRect = CGRect(x: 100, y: 100, width: 200, height: 150)

        let result = SelectionMath.updatedRect(
            for: .resize(.right),
            startRect: startRect,
            translation: CGSize(width: -150, height: 0),
            displayBounds: hugeBounds,
            minimumSize: CGSize(width: 64, height: 64)
        )

        // Dragging right's edge inward past the 64pt minimum should stop at
        // 64pt wide, with the untouched left edge still at its original x.
        XCTAssertEqual(result, CGRect(x: 100, y: 100, width: 64, height: 150))
    }

    // MARK: - Clamp at display edges

    func testResizePastDisplayBoundsStaysWithinBounds() {
        let bounds = CGRect(x: 0, y: 0, width: 800, height: 600)
        let startRect = CGRect(x: 700, y: 500, width: 80, height: 80)

        let result = SelectionMath.updatedRect(
            for: .resize(.topRight),
            startRect: startRect,
            translation: CGSize(width: 50, height: 50),
            displayBounds: bounds
        )

        XCTAssertEqual(result, CGRect(x: 670, y: 470, width: 130, height: 130))
        XCTAssertTrue(bounds.contains(result))
    }

    func testMovePastDisplayBoundsClampsWithoutChangingSize() {
        let bounds = CGRect(x: 0, y: 0, width: 800, height: 600)
        let startRect = CGRect(x: 700, y: 500, width: 80, height: 80)

        let result = SelectionMath.updatedRect(
            for: .move,
            startRect: startRect,
            translation: CGSize(width: 100, height: 100),
            displayBounds: bounds
        )

        XCTAssertEqual(result, CGRect(x: 720, y: 520, width: 80, height: 80))
        XCTAssertTrue(bounds.contains(result))
    }

    // MARK: - AppKit local -> global CG conversion

    func testGlobalCGRectConvertsPanelLocalRectOnSecondaryDisplay() {
        // Secondary display sits to the right of the primary in AppKit
        // global coordinates; primary display defines the flip height.
        let panelFrame = CGRect(x: 1920, y: 0, width: 1920, height: 1080)
        let localRect = CGRect(x: 100, y: 200, width: 400, height: 300)

        let globalCGRect = SelectionMath.globalCGRect(
            localRect: localRect,
            panelFrame: panelFrame,
            primaryDisplayHeight: 1080
        )

        XCTAssertEqual(globalCGRect, CGRect(x: 2020, y: 580, width: 400, height: 300))
    }

    func testGlobalCGRectAtPanelTopEdgeMapsToCGOrigin() {
        let panelFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let localRect = CGRect(x: 0, y: 1030, width: 100, height: 50)

        let globalCGRect = SelectionMath.globalCGRect(
            localRect: localRect,
            panelFrame: panelFrame,
            primaryDisplayHeight: 1080
        )

        XCTAssertEqual(globalCGRect, CGRect(x: 0, y: 0, width: 100, height: 50))
    }

    func testLocalRectIsTheInverseOfGlobalCGRect() {
        let panelFrame = CGRect(x: 1920, y: -200, width: 1920, height: 1080)
        let localRect = CGRect(x: 100, y: 200, width: 400, height: 300)

        let roundTripped = SelectionMath.localRect(
            fromGlobalCG: SelectionMath.globalCGRect(
                localRect: localRect,
                panelFrame: panelFrame,
                primaryDisplayHeight: 1080
            ),
            panelFrame: panelFrame,
            primaryDisplayHeight: 1080
        )

        XCTAssertEqual(roundTripped, localRect)
    }

    // MARK: - Initial selection rect

    private let initialBounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    private let initialPanelFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)

    func testInitialSelectionWithNoLastRegionCentersHalfSizeRect() {
        let rect = SelectionMath.initialSelectionRect(
            lastRegion: nil,
            displayID: 1,
            panelFrame: initialPanelFrame,
            primaryDisplayHeight: 1080,
            localBounds: initialBounds
        )

        XCTAssertEqual(rect, CGRect(x: 480, y: 270, width: 960, height: 540))
    }

    func testInitialSelectionReusesLastRegionOnSameDisplay() {
        // CG top-left (100, 100, 640, 360) on a 1080-high display flips to
        // AppKit y = 1080 - 100 - 360 = 620.
        let last = Region(displayID: 1, rect: CGRect(x: 100, y: 100, width: 640, height: 360))

        let rect = SelectionMath.initialSelectionRect(
            lastRegion: last,
            displayID: 1,
            panelFrame: initialPanelFrame,
            primaryDisplayHeight: 1080,
            localBounds: initialBounds
        )

        XCTAssertEqual(rect, CGRect(x: 100, y: 620, width: 640, height: 360))
    }

    func testInitialSelectionIgnoresLastRegionFromAnotherDisplay() {
        let last = Region(displayID: 7, rect: CGRect(x: 100, y: 100, width: 640, height: 360))

        let rect = SelectionMath.initialSelectionRect(
            lastRegion: last,
            displayID: 1,
            panelFrame: initialPanelFrame,
            primaryDisplayHeight: 1080,
            localBounds: initialBounds
        )

        XCTAssertEqual(rect, CGRect(x: 480, y: 270, width: 960, height: 540))
    }

    func testInitialSelectionClampsLastRegionToCurrentBounds() {
        // A region saved on a bigger display: wider than today's bounds.
        let last = Region(displayID: 1, rect: CGRect(x: 0, y: 0, width: 4000, height: 360))

        let rect = SelectionMath.initialSelectionRect(
            lastRegion: last,
            displayID: 1,
            panelFrame: initialPanelFrame,
            primaryDisplayHeight: 1080,
            localBounds: initialBounds
        )

        XCTAssertTrue(initialBounds.contains(rect))
        XCTAssertEqual(rect.width, 1920)
    }
}
