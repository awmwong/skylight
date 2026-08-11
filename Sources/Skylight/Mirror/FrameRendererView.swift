import AppKit
import AVFoundation
import CoreMedia
import CoreVideo
import os

/// Renders captured frames full-screen inside the mirror window. Uses
/// `AVSampleBufferDisplayLayer` (hardware-accelerated video display) rather
/// than drawing into a bitmap context.
final class FrameRendererView: NSView {
    private static let logger = Logger(subsystem: "com.anthony.skylight", category: "FrameRendererView")

    let displayLayer = AVSampleBufferDisplayLayer()
    private var latestBufferSize: CGSize?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureLayers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLayers()
    }

    override func layout() {
        super.layout()
        updateDisplayLayerFrame()
    }

    /// Enqueues a captured frame for display and resizes the layer to
    /// letterbox-fit the view if the buffer's aspect ratio changed.
    func enqueue(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            Self.logger.error("Dropped a sample buffer with no image data")
            return
        }

        latestBufferSize = CGSize(
            width: CVPixelBufferGetWidth(pixelBuffer),
            height: CVPixelBufferGetHeight(pixelBuffer)
        )
        updateDisplayLayerFrame()

        if displayLayer.status == .failed {
            Self.logger.error("Display layer failed; flushing before re-enqueuing")
            displayLayer.flush()
        }
        displayLayer.enqueue(sampleBuffer)
    }

    /// The letterboxed placement of a `bufferSize`-shaped buffer inside a
    /// `viewSize`-shaped view. Pure function so aspect-mismatch math is
    /// unit-testable without a live layer or window.
    func layerFrame(bufferSize: CGSize, viewSize: CGSize) -> CGRect {
        Geometry.letterboxFit(source: bufferSize, into: viewSize)
    }

    private func configureLayers() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        displayLayer.backgroundColor = NSColor.black.cgColor
        layer?.addSublayer(displayLayer)
    }

    private func updateDisplayLayerFrame() {
        guard let bufferSize = latestBufferSize else { return }
        displayLayer.frame = layerFrame(bufferSize: bufferSize, viewSize: bounds.size)
    }
}
