import Foundation

enum Username {
    /// Character set Nabto Edge IAM accepts for usernames:
    /// lower case letters, digits, underscore, dash and period.
    /// See https://docs.nabto.com/developer/api-reference/coap/iam/pairing-password-open.html
    private static let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-_.")

    /// Turn a free-form name — typically `UIDevice.current.name`, e.g. "Wendy's iPhone" — into
    /// something the device will accept as a username.
    static func sanitize(_ input: String) -> String {
        input
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .components(separatedBy: allowed.inverted)
            .joined()
    }
}
