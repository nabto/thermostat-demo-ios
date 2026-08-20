import Foundation

/// A device the user knows about: either paired with, or in the process of pairing with.
///
/// Persisted as JSON in the app's documents directory by ``BookmarkStore``. The coding keys are
/// deliberately unchanged from earlier versions of the app so an existing `bookmarks.json` still
/// decodes after an upgrade.
struct DeviceBookmark: Codable, Hashable, Identifiable, Sendable {
    let deviceId: String
    let productId: String

    var name: String = "Anonymous Thermostat"
    var timeAdded: Date?
    var sct: String?
    var modelName: String?
    var role: String?

    /// Fingerprint of the device as observed during pairing. Checked on every subsequent connect so
    /// a device that has been replaced or spoofed is not silently trusted.
    var deviceFingerprint: String?

    var id: String { "\(productId).\(deviceId)" }

    /// Identity is the device itself, not the mutable metadata we have cached about it.
    static func == (lhs: DeviceBookmark, rhs: DeviceBookmark) -> Bool {
        lhs.deviceId == rhs.deviceId && lhs.productId == rhs.productId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(deviceId)
        hasher.combine(productId)
    }
}

extension DeviceBookmark: CustomStringConvertible {
    var description: String {
        "DeviceBookmark(\(id), name: \(name), role: \(role ?? "n/a"))"
    }
}
