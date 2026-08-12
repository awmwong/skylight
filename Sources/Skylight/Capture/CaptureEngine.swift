import CoreGraphics
import CoreMedia
import Foundation
import os
import ScreenCaptureKit

enum CaptureError: Error, Equatable {
    /// No `SCDisplay` in the current shareable content matches the
    /// region's `displayID` (display was unplugged, or is a virtual
    /// display ScreenCaptureKit doesn't expose).
    case displayNotFound(CGDirectDisplayID)
}

/// Wraps a single ScreenCaptureKit capture of one `Region`.
///
/// `SCShareableContent` and `SCStream` only get touched inside `start()`,
/// which needs a live GUI session and Screen Recording permission. Unit
/// tests must never call `start()`; they exercise `CaptureConfig` instead
/// (see `CaptureConfigTests`).
///
/// Threading: frame callbacks arrive on `sampleQueue` (kept off the main
/// thread so frame delivery never waits behind UI work) and only touch the
/// thread-safe `frameContinuation`. `stream` is the only mutable state and
/// is mutated only through `start`/`stop`, which the `@MainActor`
/// `ShareSession` is the sole caller of.
final class CaptureEngine: NSObject {
    private let logger = Logger(subsystem: CaptureConfig.excludedBundleIdentifier, category: "capture")
    private let sampleQueue = DispatchQueue(label: "ng.awo.skylight.capture.frames")

    private let region: Region
    private let displayOrigin: CGPoint
    private let displayScale: CGFloat
    private let options: CaptureOptions

    private var stream: SCStream?
    private let output = FrameOutput()
    private var frameContinuation: AsyncStream<CMSampleBuffer>.Continuation?

    /// Delivered frames. Finishes when `stop()` is called or the stream
    /// stops itself (see `onError`).
    let frames: AsyncStream<CMSampleBuffer>

    /// Called when the underlying stream stops itself with an error (for
    /// example, the source display disconnects mid-share). The error is
    /// always logged first; this closure is how the caller surfaces it to
    /// the user.
    var onError: ((Error) -> Void)?

    init(
        region: Region,
        displayOrigin: CGPoint,
        displayScale: CGFloat,
        options: CaptureOptions = CaptureOptions()
    ) {
        self.region = region
        self.displayOrigin = displayOrigin
        self.displayScale = displayScale
        self.options = options

        var continuation: AsyncStream<CMSampleBuffer>.Continuation?
        // Only the newest frame matters for a live mirror: if the consumer
        // stalls (modal alert, busy main thread), stale frames are dropped
        // instead of queueing CVPixelBuffers without bound.
        frames = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation = $0 }
        super.init()

        frameContinuation = continuation
        output.onSampleBuffer = { [weak self] sampleBuffer in
            self?.frameContinuation?.yield(sampleBuffer)
        }
    }

    func start() async throws {
        let shareableContent = try await SCShareableContent.current
        guard let display = shareableContent.displays.first(where: { $0.displayID == region.displayID })
        else {
            throw CaptureError.displayNotFound(region.displayID)
        }

        let excludedWindows = shareableContent.windows.filter(CaptureConfig.isOwnWindow)
        let filter = SCContentFilter(display: display, excludingWindows: excludedWindows)

        let streamConfiguration = SCStreamConfiguration()
        currentConfig().apply(to: streamConfiguration)

        let newStream = SCStream(filter: filter, configuration: streamConfiguration, delegate: self)
        try newStream.addStreamOutput(output, type: .screen, sampleHandlerQueue: sampleQueue)
        try await newStream.startCapture()
        stream = newStream
    }

    func stop() async {
        defer {
            stream = nil
            frameContinuation?.finish()
        }
        guard let stream else { return }
        do {
            try await stream.stopCapture()
        } catch {
            logger.error("stopCapture failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func currentConfig() -> CaptureConfig {
        CaptureConfig(
            region: region,
            displayOrigin: displayOrigin,
            displayScale: displayScale,
            options: options
        )
    }
}

extension CaptureEngine: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        logger.error("stream stopped with error: \(error.localizedDescription, privacy: .public)")
        onError?(error)
    }
}

/// Bridges `SCStreamOutput`'s delegate callback into a closure. `SCStream`
/// retains its output, so this can stay separate from `CaptureEngine`
/// without being deallocated early.
private final class FrameOutput: NSObject, SCStreamOutput {
    var onSampleBuffer: ((CMSampleBuffer) -> Void)?

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard type == .screen else { return }
        onSampleBuffer?(sampleBuffer)
    }
}
