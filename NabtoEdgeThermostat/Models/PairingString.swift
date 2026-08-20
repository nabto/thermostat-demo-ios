import Foundation

/// A pairing string as handed out by a device owner, e.g.
/// `p=pr-abcdefgh,d=de-abcdefgh,pwd=verysecret,sct=WzwjoTabnvux`.
struct PairingString: Equatable, Sendable {
    var productId: String
    var deviceId: String
    var password: String
    var sct: String?
    var username: String?
}

enum PairingStringError: Error, Equatable {
    case unexpectedElementCount(Int)
    case malformedElement(String)
    case unknownKey(String)
    case missingRequiredElement
}

extension PairingString {
    private static let separators = CharacterSet(charactersIn: ";:,")

    /// Parse a pairing string. Elements are separated by `;`, `:` or `,` and each is a `key=value`
    /// pair. `p`, `d` and `pwd` are required; `sct` and `u` are optional.
    static func parse(_ pairingString: String) throws -> PairingString {
        let elements = pairingString.components(separatedBy: separators)
        guard (3...5).contains(elements.count) else {
            throw PairingStringError.unexpectedElementCount(elements.count)
        }

        var productId: String?
        var deviceId: String?
        var password: String?
        var sct: String?
        var username: String?

        for element in elements {
            let tuple = element.components(separatedBy: "=")
            guard tuple.count == 2 else {
                throw PairingStringError.malformedElement(element)
            }
            let value = tuple[1]
            switch tuple[0] {
            case "p": productId = value
            case "d": deviceId = value
            case "pwd": password = value
            case "sct": sct = value
            case "u": username = value
            default: throw PairingStringError.unknownKey(tuple[0])
            }
        }

        guard let productId, let deviceId, let password else {
            throw PairingStringError.missingRequiredElement
        }

        return PairingString(
            productId: productId,
            deviceId: deviceId,
            password: password,
            sct: sct,
            username: username
        )
    }

    /// Convenience for live validation of a text field.
    static func isValid(_ pairingString: String) -> Bool {
        (try? parse(pairingString)) != nil
    }

    var bookmark: DeviceBookmark {
        DeviceBookmark(deviceId: deviceId, productId: productId, sct: sct)
    }
}
