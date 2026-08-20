import Foundation
import Testing

@testable import NabtoEdgeThermostat

@MainActor
@Suite("Bookmark storage")
struct BookmarkStoreTests {
    /// A file URL in the temporary directory, unique per test so tests stay independent.
    private func scratchFile() -> URL {
        URL.temporaryDirectory.appending(path: "bookmarks-\(UUID().uuidString).json")
    }

    @Test("Bookmarks survive a save and reload")
    func roundTrip() throws {
        let file = scratchFile()
        let store = BookmarkStore(fileURL: file)
        var bookmark = DeviceBookmark(deviceId: "de-abcd1234", productId: "pr-abcd1234")
        bookmark.name = "Kitchen"
        bookmark.sct = "WzwjoTabnvux"
        bookmark.role = "Owner"
        bookmark.deviceFingerprint = "aabbcc"
        try store.add(bookmark)

        let reloaded = BookmarkStore(fileURL: file)
        try reloaded.load()

        #expect(reloaded.bookmarks.count == 1)
        let restored = try #require(reloaded.bookmarks.first)
        #expect(restored.name == "Kitchen")
        #expect(restored.sct == "WzwjoTabnvux")
        #expect(restored.role == "Owner")
        #expect(restored.deviceFingerprint == "aabbcc")
        #expect(restored.timeAdded != nil)
    }

    @Test("Adding a known device replaces it rather than duplicating it")
    func addIsIdempotent() throws {
        let store = BookmarkStore(fileURL: scratchFile())
        let bookmark = DeviceBookmark(deviceId: "de-abcd1234", productId: "pr-abcd1234")
        try store.add(bookmark)

        var renamed = bookmark
        renamed.name = "Living room"
        try store.add(renamed)

        #expect(store.bookmarks.count == 1)
        #expect(store.bookmarks.first?.name == "Living room")
    }

    @Test("Identity is the device, not the metadata cached about it")
    func identity() {
        var a = DeviceBookmark(deviceId: "de-1", productId: "pr-1")
        a.name = "Kitchen"
        var b = DeviceBookmark(deviceId: "de-1", productId: "pr-1")
        b.name = "Somewhere else"
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)

        let other = DeviceBookmark(deviceId: "de-2", productId: "pr-1")
        #expect(a != other)
    }

    @Test("Clearing removes both the list and the file")
    func clear() throws {
        let file = scratchFile()
        let store = BookmarkStore(fileURL: file)
        try store.add(DeviceBookmark(deviceId: "de-1", productId: "pr-1"))
        store.clear()
        #expect(store.bookmarks.isEmpty)

        let reloaded = BookmarkStore(fileURL: file)
        try reloaded.load()
        #expect(reloaded.bookmarks.isEmpty)
    }

    /// A `bookmarks.json` written by the pre-SwiftUI version of the app, which encoded a `Bookmark`
    /// class with `JSONEncoder`'s default date strategy. Upgrading users must not lose their devices.
    @Test("A bookmarks.json from the previous app version still decodes")
    func legacyFormat() throws {
        let legacy = """
            [
              {
                "deviceId": "de-avmqjaje",
                "productId": "pr-fatqcwj9",
                "name": "ACME 9002 Thermostat",
                "timeAdded": 665000000.0,
                "sct": "WzwjoTabnvux",
                "modelName": "ACME 9002 Thermostat",
                "role": "Owner",
                "deviceFingerprint": "6098a7e1bef3b4c9a8f8ff0a2b3c4d5e"
              },
              {
                "deviceId": "de-second",
                "productId": "pr-second",
                "name": "Anonymous Thermostat"
              }
            ]
            """

        let url = URL.temporaryDirectory.appending(path: "legacy-\(UUID().uuidString).json")
        try Data(legacy.utf8).write(to: url)

        let store = BookmarkStore(fileURL: url)
        try store.load()

        #expect(store.bookmarks.count == 2)
        let first = try #require(store.bookmarks.first { $0.deviceId == "de-avmqjaje" })
        #expect(first.productId == "pr-fatqcwj9")
        #expect(first.name == "ACME 9002 Thermostat")
        #expect(first.role == "Owner")
        #expect(first.sct == "WzwjoTabnvux")
        #expect(first.deviceFingerprint == "6098a7e1bef3b4c9a8f8ff0a2b3c4d5e")
        #expect(first.timeAdded == Date(timeIntervalSinceReferenceDate: 665_000_000))

        // A bookmark saved before fingerprint checking existed has no fingerprint, and must still load.
        let second = try #require(store.bookmarks.first { $0.deviceId == "de-second" })
        #expect(second.deviceFingerprint == nil)
        #expect(second.timeAdded == nil)
    }
}
