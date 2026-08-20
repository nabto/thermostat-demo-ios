import Foundation
import Observation

/// The user's list of known devices, persisted as JSON in the documents directory.
///
/// The on-disk format is unchanged from earlier versions of the app, so an existing
/// `bookmarks.json` survives an upgrade.
@MainActor
@Observable
final class BookmarkStore {
    private(set) var bookmarks: [DeviceBookmark] = []

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL
    }

    static var defaultFileURL: URL {
        URL.documentsDirectory.appending(path: "bookmarks.json")
    }

    func load() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path()) else {
            bookmarks = []
            return
        }
        let data = try Data(contentsOf: fileURL)
        bookmarks = try JSONDecoder()
            .decode([DeviceBookmark].self, from: data)
            .sorted { lhs, rhs in
                guard let l = lhs.timeAdded, let r = rhs.timeAdded else { return false }
                return l < r
            }
    }

    /// Add a bookmark, or replace the existing entry for the same device. Stamps `timeAdded` so the
    /// list keeps its "oldest first" ordering.
    func add(_ bookmark: DeviceBookmark) throws {
        var stamped = bookmark
        stamped.timeAdded = Date()
        bookmarks.removeAll { $0 == stamped }
        bookmarks.append(stamped)
        try save()
    }

    /// Update the metadata we hold about an already-known device, leaving its position alone.
    func update(_ bookmark: DeviceBookmark) throws {
        guard let index = bookmarks.firstIndex(of: bookmark) else { return }
        var updated = bookmark
        updated.timeAdded = bookmarks[index].timeAdded
        bookmarks[index] = updated
        try save()
    }

    func remove(_ bookmark: DeviceBookmark) throws {
        bookmarks.removeAll { $0 == bookmark }
        try save()
    }

    func contains(_ bookmark: DeviceBookmark) -> Bool {
        bookmarks.contains(bookmark)
    }

    func clear() {
        bookmarks = []
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func save() throws {
        let data = try JSONEncoder().encode(bookmarks)
        try data.write(to: fileURL, options: .atomic)
    }
}
