//
//  EdgeManager.swift
//  HeatpumpDemo
//

import UIKit
import NabtoEdgeClient

class EdgeConnectionWrapper : ConnectionEventReceiver {
    var isClosed: Bool = false
    let connection: Connection

    func onEvent(event: NabtoEdgeClientConnectionEvent) {
        if (event == NabtoEdgeClientConnectionEvent.CLOSED) {
            self.isClosed = true
        }
    }

    init(connection: Connection) throws {
        self.connection = connection
        try connection.addConnectionEventsReceiver(cb: self)
    }
}

class EdgeManager {

    // coap test app
    // let appSpecificApiKey = "sk-5f3ab4bea7cc2585091539fb950084ce"

    // password-open test app
    let appSpecificApiKey = "sk-9c826d2ebb4343a789b280fe22b98305"

    internal static let shared = EdgeManager()
    private var cache: [Bookmark:EdgeConnectionWrapper] = [:]
    private var client_: NabtoEdgeClient.Client! = nil
    private let cacheQueue = DispatchQueue(label: "cacheQueue")
    private let clientQueue = DispatchQueue(label: "clientQueue")

    internal var client: NabtoEdgeClient.Client {
        get {
            self.clientQueue.sync {
                if (self.client_ == nil) {
                    self.client_ = NabtoEdgeClient.Client()
//                self.client_.enableNsLogLogging()
//                try! self.client_.setLogLevel(level: "trace")
                }
                return self.client_
            }
        }
    }

    func stop() {
        self.cacheQueue.sync {
            self.cache = [:]
        }
        self.clientQueue.sync {
            self.client_?.stop()
            self.client_ = nil
        }
    }

    func getConnection(_ target: Bookmark) throws -> Connection {
        var cached: EdgeConnectionWrapper?
        cacheQueue.sync {
            cached = cache[target]
        }
        if (cached == nil || cached!.isClosed) {
            let newConnection = try doConnect(target)
            try cacheQueue.sync {
                cache[target] = try EdgeConnectionWrapper(connection: newConnection)
            }
            return newConnection
        } else {
            return cached!.connection
        }
    }

    func doConnect(_ target: Bookmark) throws -> Connection {
        let connection = try self.client.createConnection()
        try connection.setProductId(id: target.productId)
        try connection.setDeviceId(id: target.deviceId)
        try connection.setServerKey(key: self.appSpecificApiKey)
        guard let key = ProfileTools.getSavedPrivateKey() else {
            throw NabtoEdgeClientError.FAILED_WITH_DETAIL(detail: "Private key not set")
        }
        try connection.setPrivateKey(key: key)
        if let sct = target.sct {
            try connection.setServerConnectToken(sct: sct)
        }
        try connection.connect()
        return connection
    }

}
