import Foundation

/// What the app knows about a bookmarked device after probing it.
enum DeviceStatus: Equatable, Sendable {
    case paired(role: String?)
    case unpaired
    case offline
    case unavailable(String)

    var isOnline: Bool {
        switch self {
        case .paired, .unpaired: true
        case .offline, .unavailable: false
        }
    }

    var isPaired: Bool {
        if case .paired = self { return true }
        return false
    }
}

/// A failure talking to a device, mapped out of the SDK's error types by ``NabtoClient`` so that
/// nothing SDK-specific reaches the views.
enum DeviceFailure: Error, Equatable, Sendable {
    case offline
    case timedOut
    /// The client was stopped underneath us — the connection is re-established on the next attempt,
    /// so this is not worth showing to the user.
    case stopped
    case identityChanged
    case other(String)

    var userMessage: String? {
        switch self {
        case .offline:
            "Device offline - please make sure you and the target device both have a working network connection"
        case .timedOut:
            "The operation timed out - was the connection lost?"
        case .stopped:
            nil
        case .identityChanged:
            "Device identity changed since pairing"
        case let .other(detail):
            "An error occurred: \(detail)"
        }
    }
}

/// A failure during pairing. The cases are exactly the ones the pairing UI reacts to differently.
enum PairingFailure: Error, Equatable, Sendable {
    case usernameExists
    case authenticationFailed
    case blockedByDeviceConfiguration
    case deviceOffline
    case noPairingModesAvailable
    case unsupportedPairingMode
    case other(String)

    var userMessage: String {
        switch self {
        case .usernameExists:
            "Name already in use on device - please change the name and try again"
        case .authenticationFailed:
            "Pairing password not valid for this device"
        case .blockedByDeviceConfiguration:
            "The device's IAM configuration is not valid - it must allow pairing"
        case .deviceOffline:
            "Could not connect to device for pairing - device offline or invalid id in pairing string"
        case .noPairingModesAvailable:
            """
            Device is not open for pairing - please contact the owner. If you are the owner, you can \
            factory reset it to get access again.
            """
        case .unsupportedPairingMode:
            "This app only supports initial and open pairing modes - please reconfigure target device"
        case let .other(detail):
            "An error occurred when pairing with device: \(detail)"
        }
    }
}
