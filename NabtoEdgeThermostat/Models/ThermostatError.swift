import Foundation

/// Errors raised by this app itself, as opposed to the ones the Nabto SDK raises.
enum ThermostatError: Error, Equatable, Sendable {
    /// The device's fingerprint no longer matches the one recorded at pairing time. Either the
    /// device was factory reset and re-keyed, or something is impersonating it.
    case deviceIdentityChanged

    /// No client private key available — the app failed to create or store one.
    case privateKeyMissing

    /// The device answered a CoAP request with an unexpected status code.
    case unexpectedStatus(path: String, status: UInt16)

    /// A CBOR payload from the device could not be decoded.
    case decodingFailed(String)

    /// The device is not open for pairing at all.
    case noPairingModesAvailable

    /// The device only offers pairing modes this app does not implement.
    case unsupportedPairingMode
}

extension ThermostatError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .deviceIdentityChanged:
            "Device identity changed since pairing"
        case .privateKeyMissing:
            "No client private key available"
        case let .unexpectedStatus(path, status):
            "The device returned status \(status) for \(path)"
        case let .decodingFailed(detail):
            "Could not decode the device's response: \(detail)"
        case .noPairingModesAvailable:
            """
            Device is not open for pairing - please contact the owner. If you are the owner, you can \
            factory reset it to get access again.
            """
        case .unsupportedPairingMode:
            "This app only supports initial and open pairing modes - please reconfigure target device"
        }
    }
}
