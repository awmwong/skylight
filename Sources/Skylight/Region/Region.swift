import CoreGraphics

/// A user-selected capture region: a display and a rect on it, in
/// CoreGraphics top-left global coordinates (points, not pixels).
struct Region: Equatable, Codable {
    /// Far larger than any real display, small enough that every downstream
    /// Int/UInt32 conversion is safe.
    static let maxCoordinateMagnitude: CGFloat = 1_000_000

    var displayID: CGDirectDisplayID
    var rect: CGRect

    /// Whether the rect could exist on a real display. Persisted regions
    /// (presets) cross a trust boundary when they are read back: a corrupt
    /// or hand-edited value that decodes fine can still trap the trapping
    /// Int/UInt32 conversions in the display and capture pipeline.
    var isValid: Bool {
        // rect.size, not rect.width/height: the latter standardize to
        // absolute values and would let a negative-size rect through.
        let values = [rect.origin.x, rect.origin.y, rect.size.width, rect.size.height]
        guard values.allSatisfy({ $0.isFinite && abs($0) <= Self.maxCoordinateMagnitude }) else {
            return false
        }
        return rect.size.width > 0 && rect.size.height > 0
    }
}
