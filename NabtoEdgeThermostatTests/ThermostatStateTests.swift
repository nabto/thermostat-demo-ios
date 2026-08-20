import CBORCoding
import Foundation
import Testing

@testable import NabtoEdgeThermostat

@Suite("Thermostat wire format")
struct ThermostatStateTests {
    /// A CBOR map exactly as a device answers `GET /thermostat`:
    /// `{"Mode": "HEAT", "Target": 22.5, "Power": true, "Temperature": 21.3}`
    private static let devicePayload = Data([
        0xa4,
        0x64, 0x4d, 0x6f, 0x64, 0x65, 0x64, 0x48, 0x45, 0x41, 0x54,
        0x66, 0x54, 0x61, 0x72, 0x67, 0x65, 0x74, 0xfb, 0x40, 0x36, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x65, 0x50, 0x6f, 0x77, 0x65, 0x72, 0xf5,
        0x6b, 0x54, 0x65, 0x6d, 0x70, 0x65, 0x72, 0x61, 0x74, 0x75, 0x72, 0x65,
        0xfb, 0x40, 0x35, 0x4c, 0xcc, 0xcc, 0xcc, 0xcc, 0xcd,
    ])

    @Test("The device's capitalized CBOR keys decode into the Swift model")
    func decodesDevicePayload() throws {
        let state = try CBORDecoder().decode(ThermostatState.self, from: Self.devicePayload)
        #expect(state.mode == "HEAT")
        #expect(state.target == 22.5)
        #expect(state.power)
        #expect(abs(state.temperature - 21.3) < 0.000_001)
    }

    @Test("A known mode maps onto DeviceMode")
    func knownMode() throws {
        let state = try CBORDecoder().decode(ThermostatState.self, from: Self.devicePayload)
        #expect(state.deviceMode == .heat)
    }

    @Test("An unknown mode does not break decoding")
    func unknownMode() {
        let state = ThermostatState(mode: "TURBO", target: 20, power: true, temperature: 20)
        #expect(state.deviceMode == nil)
    }

    @Test("Encoding round-trips through CBOR")
    func roundTrip() throws {
        let original = ThermostatState(mode: "COOL", target: 18, power: false, temperature: 25.5)
        let encoded = try CBOREncoder().encode(original)
        let decoded = try CBORDecoder().decode(ThermostatState.self, from: encoded)
        #expect(decoded == original)
    }

    @Test("Every mode the picker offers round-trips through its raw value")
    func modeRawValues() {
        #expect(DeviceMode.allCases.map(\.rawValue) == ["COOL", "HEAT", "FAN", "DRY"])
        for mode in DeviceMode.allCases {
            #expect(DeviceMode(rawValue: mode.rawValue) == mode)
        }
    }

    @Test("Pairing modes are prioritized initial, then open, then password")
    func pairingModePriority() {
        #expect([PairingModeKind.passwordOpen, .localOpen, .localInitial].preferred == .localInitial)
        #expect([PairingModeKind.passwordOpen, .localOpen].preferred == .localOpen)
        #expect([PairingModeKind.passwordOpen].preferred == .passwordOpen)
        #expect([PairingModeKind.passwordInvite].preferred == nil)
        #expect([PairingModeKind]().preferred == nil)
    }
}
