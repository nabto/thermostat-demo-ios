import Foundation

/// Operating mode of the thermostat, as understood by the device's IAM configuration.
enum DeviceMode: String, CaseIterable, Identifiable, Sendable {
    case cool = "COOL"
    case heat = "HEAT"
    case fan = "FAN"
    case dry = "DRY"

    var id: String { rawValue }
}

/// The payload of the device's `GET /thermostat` CoAP endpoint.
///
/// The device speaks CBOR with capitalized keys; the coding keys preserve that wire format while
/// keeping the Swift side idiomatic.
struct ThermostatState: Codable, Equatable, Sendable {
    var mode: String
    var target: Double
    var power: Bool
    var temperature: Double

    enum CodingKeys: String, CodingKey {
        case mode = "Mode"
        case target = "Target"
        case power = "Power"
        case temperature = "Temperature"
    }

    /// Nil when the device reports a mode this app does not know about.
    var deviceMode: DeviceMode? { DeviceMode(rawValue: mode) }
}

extension ThermostatState {
    /// Target temperature range offered by the app's UI.
    static let targetRange: ClosedRange<Double> = 16.0...30.0
}
