import CoreMedia
import CoreVideo

/// Builds minimal, ready-to-render sample buffers for tests that need real
/// CMSampleBuffer instances without any capture running.
enum SampleBufferFixtures {
    static func make(width: Int, height: Int) throws -> CMSampleBuffer {
        var pixelBuffer: CVPixelBuffer?
        let pixelBufferStatus = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            nil,
            &pixelBuffer
        )
        guard pixelBufferStatus == kCVReturnSuccess, let pixelBuffer else {
            throw FixtureError.pixelBufferCreationFailed(pixelBufferStatus)
        }

        var formatDescription: CMFormatDescription?
        let formatStatus = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDescription
        )
        guard formatStatus == noErr, let formatDescription else {
            throw FixtureError.formatDescriptionCreationFailed(formatStatus)
        }

        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 30),
            presentationTimeStamp: .zero,
            decodeTimeStamp: .invalid
        )
        var sampleBuffer: CMSampleBuffer?
        let sampleStatus = CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: formatDescription,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )
        guard sampleStatus == noErr, let sampleBuffer else {
            throw FixtureError.sampleBufferCreationFailed(sampleStatus)
        }
        return sampleBuffer
    }

    enum FixtureError: Error {
        case pixelBufferCreationFailed(CVReturn)
        case formatDescriptionCreationFailed(OSStatus)
        case sampleBufferCreationFailed(OSStatus)
    }
}
