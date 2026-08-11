import CoreGraphics

/// Pure geometry helpers for region selection: coordinate-space conversion,
/// bounds clamping, HiDPI scaling, and letterbox fitting. No NSScreen or
/// CGDisplay calls here — callers pass the frames/scales they need so this
/// stays unit-testable without a GUI session.
enum Geometry {
    static let defaultMinimumRegionSize = CGSize(width: 64, height: 64)

    // MARK: - Coordinate-space conversion

    /// AppKit screen space has its origin at the bottom-left of the primary
    /// display, y increasing upward. CoreGraphics global display space has
    /// its origin at the primary display's top-left, y increasing downward.
    /// Both share the same x-axis, so only y flips, around the primary
    /// display's height. The flip is its own inverse, so the same formula
    /// converts in both directions.
    static func convertAppKitToCG(_ rect: CGRect, primaryDisplayHeight: CGFloat) -> CGRect {
        flipVertically(rect, around: primaryDisplayHeight)
    }

    static func convertCGToAppKit(_ rect: CGRect, primaryDisplayHeight: CGFloat) -> CGRect {
        flipVertically(rect, around: primaryDisplayHeight)
    }

    private static func flipVertically(_ rect: CGRect, around height: CGFloat) -> CGRect {
        CGRect(
            x: rect.minX,
            y: height - rect.minY - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    // MARK: - Clamping

    /// Clamps `rect` so it fits within `bounds`, enforcing `minimumSize`.
    /// A rect smaller than `minimumSize` grows to it; a rect larger than
    /// `bounds` (or a bounds smaller than `minimumSize`) shrinks to fit
    /// `bounds`. The origin then slides so the resulting rect never
    /// extends past `bounds`, pinning to the nearest edge when the
    /// original rect was fully outside.
    static func clamp(
        _ rect: CGRect,
        toDisplayBounds bounds: CGRect,
        minimumSize: CGSize = defaultMinimumRegionSize
    ) -> CGRect {
        let width = clampedDimension(rect.width, minimum: minimumSize.width, boundsSize: bounds.width)
        let height = clampedDimension(rect.height, minimum: minimumSize.height, boundsSize: bounds.height)
        let originX = clampedOrigin(rect.minX, size: width, boundsMin: bounds.minX, boundsMax: bounds.maxX)
        let originY = clampedOrigin(rect.minY, size: height, boundsMin: bounds.minY, boundsMax: bounds.maxY)
        return CGRect(x: originX, y: originY, width: width, height: height)
    }

    private static func clampedDimension(_ value: CGFloat, minimum: CGFloat, boundsSize: CGFloat) -> CGFloat {
        min(max(value, minimum), boundsSize)
    }

    private static func clampedOrigin(
        _ value: CGFloat,
        size: CGFloat,
        boundsMin: CGFloat,
        boundsMax: CGFloat
    ) -> CGFloat {
        min(max(value, boundsMin), boundsMax - size)
    }

    // MARK: - Points <-> pixels scaling

    static func pixelSize(forPoints size: CGSize, scale: CGFloat) -> CGSize {
        CGSize(width: size.width * scale, height: size.height * scale)
    }

    static func pixelRect(forPoints rect: CGRect, scale: CGFloat) -> CGRect {
        CGRect(
            x: rect.minX * scale,
            y: rect.minY * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )
    }

    // MARK: - Letterbox fit

    /// The largest rect with `source`'s aspect ratio that fits inside a
    /// `target`-sized box at the origin, centered. Returns `.zero` if
    /// either size has a zero or negative dimension.
    static func letterboxFit(source: CGSize, into target: CGSize) -> CGRect {
        guard source.width > 0, source.height > 0, target.width > 0, target.height > 0 else {
            return .zero
        }

        let scale = min(target.width / source.width, target.height / source.height)
        let fittedSize = CGSize(width: source.width * scale, height: source.height * scale)
        let origin = CGPoint(
            x: (target.width - fittedSize.width) / 2,
            y: (target.height - fittedSize.height) / 2
        )
        return CGRect(origin: origin, size: fittedSize)
    }
}
