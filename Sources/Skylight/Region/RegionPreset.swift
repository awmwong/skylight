import CoreGraphics

/// A named Region the user saved for later recall. RegionStore enforces
/// name uniqueness; the type itself just pairs a name with a Region.
struct RegionPreset: Equatable, Codable {
    var name: String
    var region: Region
}
