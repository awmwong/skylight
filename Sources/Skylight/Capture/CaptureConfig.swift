import CoreGraphics
import CoreMedia
import ScreenCaptureKit

/// User-facing capture preferences, independent of any particular region or
/// display.
struct CaptureOptions: Equatable {
    var showsCursor = true
    var framesPerSecond = 30
}

/// Pure translation from a `Region` into ScreenCaptureKit's
/// `SCStreamConfiguration`: the crop rect in the source display's local
/// point space, the output pixel size, cursor visibility, and frame
/// interval. Takes the display's origin and backing scale as inputs instead
/// of querying them, so it stays unit-testable without a live display.
struct CaptureConfig: Equatable {
    let sourceRect: CGRect
    let pixelWidth: Int
    let pixelHeight: Int
    let showsCursor: Bool
    let minimumFrameInterval: CMTime

    /// The bundle identifier ScreenCaptureKit's window list is filtered
    /// against so Skylight's own windows never appear in the capture
    /// (avoids recursive/self-referential frames).
    static let excludedBundleIdentifier = "ng.awo.skylight"

    init(
        region: Region,
        displayOrigin: CGPoint,
        displayScale: CGFloat,
        options: CaptureOptions = CaptureOptions()
    ) {
        sourceRect = CGRect(
            x: region.rect.minX - displayOrigin.x,
            y: region.rect.minY - displayOrigin.y,
            width: region.rect.width,
            height: region.rect.height
        )

        let pixelSize = Geometry.evenPixelSize(forPoints: region.rect.size, scale: displayScale)
        pixelWidth = pixelSize.width
        pixelHeight = pixelSize.height

        showsCursor = options.showsCursor
        minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(options.framesPerSecond))
    }

    func apply(to configuration: SCStreamConfiguration) {
        configuration.sourceRect = sourceRect
        configuration.width = pixelWidth
        configuration.height = pixelHeight
        configuration.showsCursor = showsCursor
        configuration.minimumFrameInterval = minimumFrameInterval
    }

    /// True when `window` belongs to Skylight itself, so the caller can
    /// exclude it from the `SCContentFilter` and avoid capturing the
    /// selection overlay or mirror window.
    static func isOwnWindow(_ window: SCWindow) -> Bool {
        window.owningApplication?.bundleIdentifier == excludedBundleIdentifier
    }
}
