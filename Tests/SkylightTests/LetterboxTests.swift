@testable import Skylight
import XCTest

final class LetterboxTests: XCTestCase {
    // MARK: - layerFrame: pure letterbox math

    func testLayerFrameExactAspectFillsView() {
        let view = FrameRendererView(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))

        let frame = view.layerFrame(
            bufferSize: CGSize(width: 960, height: 540),
            viewSize: CGSize(width: 1920, height: 1080)
        )

        XCTAssertEqual(frame, CGRect(x: 0, y: 0, width: 1920, height: 1080))
    }

    func testLayerFrameWiderBufferPillarboxesTopAndBottomAt1x() {
        let view = FrameRendererView(frame: .zero)

        let frame = view.layerFrame(
            bufferSize: CGSize(width: 2000, height: 500),
            viewSize: CGSize(width: 1000, height: 1000)
        )

        XCTAssertEqual(frame, CGRect(x: 0, y: 375, width: 1000, height: 250))
    }

    func testLayerFrameWiderBufferPillarboxesTopAndBottomAt2x() {
        // Same aspect ratio as the 1x case, doubled pixel dimensions: the
        // fitted frame (in the view's point space) must be identical, since
        // only aspect ratio drives the fit, not the buffer's raw pixel count.
        let view = FrameRendererView(frame: .zero)

        let frame = view.layerFrame(
            bufferSize: CGSize(width: 4000, height: 1000),
            viewSize: CGSize(width: 1000, height: 1000)
        )

        XCTAssertEqual(frame, CGRect(x: 0, y: 375, width: 1000, height: 250))
    }

    func testLayerFrameTallerBufferBarsLeftAndRightAt1x() {
        let view = FrameRendererView(frame: .zero)

        let frame = view.layerFrame(
            bufferSize: CGSize(width: 500, height: 2000),
            viewSize: CGSize(width: 1000, height: 1000)
        )

        XCTAssertEqual(frame, CGRect(x: 375, y: 0, width: 250, height: 1000))
    }

    func testLayerFrameTallerBufferBarsLeftAndRightAt2x() {
        let view = FrameRendererView(frame: .zero)

        let frame = view.layerFrame(
            bufferSize: CGSize(width: 1000, height: 4000),
            viewSize: CGSize(width: 1000, height: 1000)
        )

        XCTAssertEqual(frame, CGRect(x: 375, y: 0, width: 250, height: 1000))
    }

    func testLayerFrameZeroBufferSizeReturnsZero() {
        let view = FrameRendererView(frame: .zero)

        let frame = view.layerFrame(bufferSize: .zero, viewSize: CGSize(width: 1000, height: 1000))

        XCTAssertEqual(frame, .zero)
    }

    func testLayerFrameZeroViewSizeReturnsZero() {
        let view = FrameRendererView(frame: .zero)

        let frame = view.layerFrame(bufferSize: CGSize(width: 100, height: 100), viewSize: .zero)

        XCTAssertEqual(frame, .zero)
    }

    // MARK: - enqueue: accepts real CMSampleBuffers and updates layout

    func testEnqueueAcceptsSampleBufferWithoutCrashing() throws {
        let view = FrameRendererView(frame: CGRect(x: 0, y: 0, width: 1000, height: 1000))
        let sampleBuffer = try SampleBufferFixtures.make(width: 2000, height: 500)

        view.enqueue(sampleBuffer)

        XCTAssertEqual(view.displayLayer.frame, CGRect(x: 0, y: 375, width: 1000, height: 250))
    }

    func testEnqueueUpdatesLayoutWhenBufferSizeChanges() throws {
        let view = FrameRendererView(frame: CGRect(x: 0, y: 0, width: 1000, height: 1000))

        try view.enqueue(SampleBufferFixtures.make(width: 2000, height: 500))
        XCTAssertEqual(view.displayLayer.frame, CGRect(x: 0, y: 375, width: 1000, height: 250))

        try view.enqueue(SampleBufferFixtures.make(width: 500, height: 2000))
        XCTAssertEqual(view.displayLayer.frame, CGRect(x: 375, y: 0, width: 250, height: 1000))
    }
}
