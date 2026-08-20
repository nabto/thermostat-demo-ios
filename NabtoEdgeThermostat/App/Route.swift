import Foundation

/// Every screen reachable from the device list. Pushed onto the root `NavigationStack`'s path.
enum Route: Hashable {
    case addDevice
    case discover
    case pairing(PairingTarget)
    case pairingConfirmed(DeviceBookmark)
    case thermostat(DeviceBookmark)
    case settings
    case help
}

/// A device we are about to pair with, plus the password from its pairing string if we have one.
struct PairingTarget: Hashable {
    var bookmark: DeviceBookmark
    var password: String?
}
