import XCTest
import Foundation

struct TestDevice {
    var productId: String
    var deviceId: String
    var url: String
    var key: String
    var fp: String?
    var sct: String?
    var local: Bool
    var password: String!

    init(productId: String, deviceId: String, url: String, key: String, fp: String?=nil, sct: String?=nil, local: Bool=false, password: String?=nil) {
        self.productId = productId
        self.deviceId = deviceId
        self.url = url
        self.key = key
        self.fp = fp
        self.sct = sct
        self.local = local
        self.password = password
    }

    func asJson() -> String {
        let sctElement = sct != nil ? "\"ServerConnectToken\": \"\(sct!)\",\n" : ""
        return """
               {\n
               \"Local\": \(self.local),\n
               \"ProductId\": \"\(self.productId)\",\n
               \"DeviceId\": \"\(self.deviceId)\",\n
               \"ServerUrl\": \"\(self.url)\",\n
               \(sctElement)
               \"ServerKey\": \"\(self.key)\"\n}
               """
    }
}

class EdgeManagerTest: XCTestCase {

    let testDevice = TestDevice(
            productId: "pr-fatqcwj9",
            deviceId: "de-avmqjaje",
            url: "https://pr-fatqcwj9.clients.nabto.net",
            key: "sk-5f3ab4bea7cc2585091539fb950084ce",
            fp: "fcb78f8d53c67dbc4f72c36ca6cd2d5fc5592d584222059f0d76bdb514a9340c"
    )

    func createTestBookmark() -> Bookmark {
        return Bookmark(
                deviceId: self.testDevice.deviceId,
                productId: self.testDevice.productId,
                name: "Test Device")
    }

    var sut: EdgeManager!

    override func setUp() {
        self.sut = EdgeManager()
        self.sut.start()
    }

    override func tearDown() {
        self.sut.stop()
    }

    func testSomething() {
        XCTAssertEqual(1, 1);
    }

    func testConnectionCache() throws {
        let bookmark = self.createTestBookmark()

        let connection = try self.sut.connect(bookmark)
        let coap = try connection.createCoapRequest(method: "GET", path: "/hello-world")
        let response = try coap.execute()
        XCTAssertEqual(response.status, 205)

        let connection2 = try self.sut.connect(bookmark)
        XCTAssertEqual(Unmanaged.passUnretained(connection).toOpaque(), Unmanaged.passUnretained(connection2).toOpaque())

        try self.sut.clearConnectionCacheEntry(bookmark)

        let connection3 = try self.sut.connect(bookmark)
        XCTAssertNotEqual(Unmanaged.passUnretained(connection).toOpaque(), Unmanaged.passUnretained(connection2).toOpaque())

        let coap2 = try connection.createCoapRequest(method: "GET", path: "/hello-world")
        let response2 = try coap2.execute()
        XCTAssertEqual(response2.status, 205)

    }
}
