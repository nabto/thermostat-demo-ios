import Foundation

/// Pairing modes a device can offer, mirrored from the SDK's `PairingMode` into a `Sendable` type.
enum PairingModeKind: String, Equatable, Sendable {
    case localInitial
    case localOpen
    case passwordOpen
    case passwordInvite
}

extension Collection<PairingModeKind> {
    /// The mode this app prefers, in the same priority order the app has always used:
    /// initial before open before password-open. Password-invite is not supported.
    var preferred: PairingModeKind? {
        for candidate in [PairingModeKind.localInitial, .localOpen, .passwordOpen] where contains(candidate) {
            return candidate
        }
        return nil
    }
}
