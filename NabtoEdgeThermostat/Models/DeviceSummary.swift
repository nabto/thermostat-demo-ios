import Foundation

/// Device metadata from `IamUtil.getDeviceDetails`, mirrored into a `Sendable` value type so the
/// SDK's own types never leave ``NabtoClient``.
struct DeviceSummary: Equatable, Sendable {
    var productId: String
    var deviceId: String
    var appName: String?
    var appVersion: String?

    var displayId: String { "\(productId).\(deviceId)" }
    var displayAppNameAndVersion: String { "\(appName ?? "n/a") (\(appVersion ?? "n/a"))" }
}

/// The current user on a device, from `IamUtil.getCurrentUser`.
struct UserSummary: Equatable, Sendable {
    var username: String
    var displayName: String?
    var role: String?
    var sct: String?
}

/// A device found by an mDNS scan of the local network.
struct DiscoveredDevice: Equatable, Sendable {
    var productId: String
    var deviceId: String
    var name: String?
}
