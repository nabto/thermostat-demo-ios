//
//  EdgeManager.swift
//  ThermostatDemo
//

import UIKit
import NabtoEdgeClient

class EdgeConnectionWrapper : ConnectionEventReceiver {
    var isClosed: Bool = false
    let target: Bookmark
    let connection: Connection

    func onEvent(event: NabtoEdgeClientConnectionEvent) {
        if (event == NabtoEdgeClientConnectionEvent.CLOSED) {
            self.isClosed = true
            NSLog("Connection to \(target) closed, notifying listeners")
            NotificationCenter.default.post(
                    name: NSNotification.Name(EdgeManager.connectionClosedEventName),
                    object: target)
        }
    }

    init(target: Bookmark, connection: Connection) throws {
        self.target = target
        self.connection = connection
        try connection.addConnectionEventsReceiver(cb: self)
    }

    func stop() {
        self.connection.removeConnectionEventsReceiver(cb: self)

    }
}

class EdgeManager {

    // coap test app
    // let appSpecificApiKey = "sk-5f3ab4bea7cc2585091539fb950084ce"

    // password-open test app
    let appSpecificApiKey = "sk-9c826d2ebb4343a789b280fe22b98305"
    internal static let connectionClosedEventName = "EDGE_CONNECTION_CLOSED"

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
                    self.client_.setLogCallBack(cb: EdgeManager.traceOnlyApiCalls)
//                    self.client_.enableNsLogLogging()
                    try! self.client_.setLogLevel(level: "trace")
                }
                return self.client_
            }
        }
    }

    private static func traceOnlyApiCalls(msg: NabtoEdgeClientLogMessage) {
        if (msg.severity < 3 ||
                msg.message.range(of: "#[0-9]{1,6} called|ended",
                        options: .regularExpression, range: nil, locale: nil) != nil) {
            NSLog("Nabto log: \(msg.file):\(msg.line) [\(msg.severity)/\(msg.severityString)]: \(msg.message)")
        }
    }

    func isStopped() -> Bool {
        self.clientQueue.sync {
            return self.client_ == nil
        }
    }

    func stop() {
        self.cacheQueue.sync {
            for (key, value) in self.cache {
                value.stop()
            }
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
                cache[target] = try EdgeConnectionWrapper(target: target, connection: newConnection)
            }
            return newConnection
        } else {
            return cached!.connection
        }
    }

    func removeConnection(_ target: Bookmark) {
        cacheQueue.sync {
            let connection = cache.removeValue(forKey: target)
            connection?.stop()
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
