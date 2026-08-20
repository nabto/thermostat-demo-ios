import Testing

@testable import NabtoEdgeThermostat

@Suite("Username sanitizing")
struct UsernameTests {
    @Test("Spaces become dashes and case is lowered")
    func spacesAndCase() {
        #expect(Username.sanitize("Kitchen iPhone") == "kitchen-iphone")
    }

    @Test("Characters outside the Edge IAM set are dropped")
    func illegalCharacters() {
        #expect(Username.sanitize("Ulrik's iPhone!") == "ulriks-iphone")
        #expect(Username.sanitize("æøå") == "")
    }

    @Test("Every letter the IAM spec allows survives")
    func fullAlphabet() {
        // Regression test: the character set this was ported from was missing 'w', which silently
        // dropped that letter from any username containing it.
        #expect(Username.sanitize("abcdefghijklmnopqrstuvwxyz") == "abcdefghijklmnopqrstuvwxyz")
        #expect(Username.sanitize("Wendy") == "wendy")
    }

    @Test("Digits, dash, underscore and period are preserved")
    func allowedPunctuation() {
        #expect(Username.sanitize("user_1.2-3") == "user_1.2-3")
    }
}
