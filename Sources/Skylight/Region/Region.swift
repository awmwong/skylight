import CoreGraphics

/// A user-selected capture region: a display and a rect on it, in
/// CoreGraphics top-left global coordinates (points, not pixels).
struct Region: Equatable, Codable {
    var displayID: CGDirectDisplayID
    var rect: CGRect
}
