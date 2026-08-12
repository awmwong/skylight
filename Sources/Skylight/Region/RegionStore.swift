import Foundation
import os

/// Writing the presets file to disk failed. The in-memory presets the
/// caller passed in were never lost — they just didn't make it to disk.
enum RegionStoreError: Error {
    case writeFailed(underlying: Error)
}

/// Persists named region presets as JSON, one file per store directory
/// (`presets.json`). The directory is injectable so tests use a temp
/// directory instead of the real Application Support folder.
final class RegionStore {
    private static let fileName = "presets.json"
    private static let logger = Logger(subsystem: "ng.awo.skylight", category: "RegionStore")

    private let directory: URL

    init(directory: URL = RegionStore.defaultDirectory) {
        self.directory = directory
    }

    static var defaultDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("Skylight", isDirectory: true)
    }

    private var fileURL: URL {
        directory.appendingPathComponent(Self.fileName)
    }

    /// Loads saved presets. A missing file yields an empty list. A corrupt
    /// or unreadable file logs the error and also yields an empty list —
    /// callers never crash, and the file is left on disk untouched so it
    /// can still be inspected or recovered by hand. Presets whose region
    /// fails `Region.isValid` are dropped here, at the trust boundary,
    /// before they can reach the display or capture pipeline.
    func load() -> [RegionPreset] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let presets = try JSONDecoder().decode([RegionPreset].self, from: data)
            return presets.filter { preset in
                guard preset.region.isValid else {
                    Self.logger.error("Dropped preset with invalid region: \(preset.name, privacy: .public)")
                    return false
                }
                return true
            }
        } catch {
            let path = fileURL.path
            let reason = error.localizedDescription
            Self.logger
                .error("Failed to read presets at \(path, privacy: .private): \(reason, privacy: .public)")
            return []
        }
    }

    /// Saves `preset`, overwriting any existing preset with the same name.
    func save(_ preset: RegionPreset) throws {
        var presets = load()
        presets.removeAll { $0.name == preset.name }
        presets.append(preset)
        try persist(presets)
    }

    /// Deletes the preset named `name`. A no-op if no preset has that name.
    func delete(named name: String) throws {
        var presets = load()
        presets.removeAll { $0.name == name }
        try persist(presets)
    }

    private func persist(_ presets: [RegionPreset]) throws {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(presets)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            let path = fileURL.path
            let reason = error.localizedDescription
            Self.logger
                .error("Failed to write presets at \(path, privacy: .private): \(reason, privacy: .public)")
            throw RegionStoreError.writeFailed(underlying: error)
        }
    }
}
