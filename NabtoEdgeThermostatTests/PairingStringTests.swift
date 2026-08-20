import Testing

@testable import NabtoEdgeThermostat

@Suite("Pairing string parsing")
struct PairingStringTests {
    @Test("A minimal pairing string yields product, device and password")
    func minimal() throws {
        let parsed = try PairingString.parse("p=pr-abcd1234,d=de-abcd1234,pwd=verysecret")
        #expect(parsed.productId == "pr-abcd1234")
        #expect(parsed.deviceId == "de-abcd1234")
        #expect(parsed.password == "verysecret")
        #expect(parsed.sct == nil)
        #expect(parsed.username == nil)
    }

    @Test("Optional sct and username elements are picked up")
    func fullyPopulated() throws {
        let parsed = try PairingString.parse(
            "p=pr-abcd1234,d=de-abcd1234,pwd=verysecret,sct=WzwjoTabnvux,u=admin"
        )
        #expect(parsed.sct == "WzwjoTabnvux")
        #expect(parsed.username == "admin")
    }

    @Test("Semicolon, colon and comma all separate elements", arguments: [";", ":", ","])
    func separators(_ separator: String) throws {
        let input = ["p=pr-abcd1234", "d=de-abcd1234", "pwd=verysecret"].joined(separator: separator)
        let parsed = try PairingString.parse(input)
        #expect(parsed.productId == "pr-abcd1234")
    }

    @Test("Fewer than three elements is rejected")
    func tooFewElements() {
        #expect(throws: PairingStringError.unexpectedElementCount(2)) {
            try PairingString.parse("p=pr-abcd1234,d=de-abcd1234")
        }
    }

    @Test("More than five elements is rejected")
    func tooManyElements() {
        #expect(throws: PairingStringError.unexpectedElementCount(6)) {
            try PairingString.parse("p=a,d=b,pwd=c,sct=d,u=e,x=f")
        }
    }

    @Test("An element without '=' is rejected")
    func missingAssignment() {
        #expect(throws: PairingStringError.malformedElement("nonsense")) {
            try PairingString.parse("p=pr-abcd1234,d=de-abcd1234,nonsense")
        }
    }

    @Test("An element with more than one '=' is rejected")
    func tooManyAssignments() {
        #expect(throws: PairingStringError.malformedElement("pwd=a=b")) {
            try PairingString.parse("p=pr-abcd1234,d=de-abcd1234,pwd=a=b")
        }
    }

    @Test("An unknown key is rejected")
    func unknownKey() {
        #expect(throws: PairingStringError.unknownKey("q")) {
            try PairingString.parse("p=pr-abcd1234,d=de-abcd1234,q=whatever")
        }
    }

    @Test("Each required element is required", arguments: [
        "d=de-abcd1234,pwd=verysecret,sct=x",
        "p=pr-abcd1234,pwd=verysecret,sct=x",
        "p=pr-abcd1234,d=de-abcd1234,sct=x",
    ])
    func missingRequiredElement(_ input: String) {
        #expect(throws: PairingStringError.missingRequiredElement) {
            try PairingString.parse(input)
        }
    }

    @Test("An empty string is rejected")
    func empty() {
        #expect(throws: (any Error).self) {
            try PairingString.parse("")
        }
    }

    @Test("isValid mirrors parse")
    func validity() {
        #expect(PairingString.isValid("p=pr-abcd1234,d=de-abcd1234,pwd=verysecret"))
        #expect(!PairingString.isValid("p=pr-abcd1234"))
    }

    @Test("A parsed string converts to a bookmark carrying the sct")
    func bookmarkConversion() throws {
        let parsed = try PairingString.parse("p=pr-abcd1234,d=de-abcd1234,pwd=s,sct=WzwjoTabnvux")
        let bookmark = parsed.bookmark
        #expect(bookmark.productId == "pr-abcd1234")
        #expect(bookmark.deviceId == "de-abcd1234")
        #expect(bookmark.sct == "WzwjoTabnvux")
    }
}
