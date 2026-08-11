import CoreGraphics
import Foundation
@testable import Skylight
import XCTest

final class RegionStoreTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RegionStoreTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        tempDirectory = nil
        super.tearDown()
    }

    private func makeStore() -> RegionStore {
        RegionStore(directory: tempDirectory)
    }

    private func makePreset(name: String, originX: CGFloat = 0) -> RegionPreset {
        RegionPreset(
            name: name,
            region: Region(displayID: 1, rect: CGRect(x: originX, y: 0, width: 640, height: 480))
        )
    }

    // MARK: - Round trip

    func testLoadOnMissingFileReturnsEmptyList() {
        let store = makeStore()

        XCTAssertEqual(store.load(), [])
    }

    func testSaveThenLoadRoundTrips() throws {
        let store = makeStore()
        let preset = makePreset(name: "Ticket")

        try store.save(preset)

        XCTAssertEqual(store.load(), [preset])
    }

    func testSaveMultiplePresetsPersistsAll() throws {
        let store = makeStore()
        let first = makePreset(name: "Ticket")
        let second = makePreset(name: "Camera", originX: 100)

        try store.save(first)
        try store.save(second)

        let loaded = store.load().sorted { $0.name < $1.name }
        XCTAssertEqual(loaded, [second, first])
    }

    // MARK: - Overwrite / uniqueness

    func testSaveWithExistingNameOverwritesRatherThanDuplicates() throws {
        let store = makeStore()
        try store.save(makePreset(name: "Ticket", originX: 0))
        let updated = makePreset(name: "Ticket", originX: 200)

        try store.save(updated)

        let loaded = store.load()
        XCTAssertEqual(loaded, [updated])
    }

    // MARK: - Delete

    func testDeleteRemovesNamedPreset() throws {
        let store = makeStore()
        let toKeep = makePreset(name: "Ticket")
        let toDelete = makePreset(name: "Camera", originX: 100)
        try store.save(toKeep)
        try store.save(toDelete)

        try store.delete(named: "Camera")

        XCTAssertEqual(store.load(), [toKeep])
    }

    func testDeleteUnknownNameIsANoOp() throws {
        let store = makeStore()
        let preset = makePreset(name: "Ticket")
        try store.save(preset)

        try store.delete(named: "DoesNotExist")

        XCTAssertEqual(store.load(), [preset])
    }

    // MARK: - Corrupt file

    func testLoadOnCorruptFileReturnsEmptyListWithoutCrashing() throws {
        let store = makeStore()
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let fileURL = tempDirectory.appendingPathComponent("presets.json")
        try Data("not valid json".utf8).write(to: fileURL)

        XCTAssertEqual(store.load(), [])
    }

    func testLoadOnCorruptFileDoesNotDeleteIt() throws {
        let store = makeStore()
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let fileURL = tempDirectory.appendingPathComponent("presets.json")
        try Data("not valid json".utf8).write(to: fileURL)

        _ = store.load()

        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    // MARK: - Write failures

    func testSaveThrowsRegionStoreErrorWhenDirectoryCannotBeCreated() throws {
        // Point the store's "directory" at a path that is already a
        // regular file, so FileManager can't create a directory there.
        let blockingFile = tempDirectory.appendingPathComponent("blocking-file")
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
        try Data().write(to: blockingFile)
        let store = RegionStore(directory: blockingFile)

        XCTAssertThrowsError(try store.save(makePreset(name: "Ticket"))) { error in
            XCTAssertTrue(error is RegionStoreError)
        }
    }
}
