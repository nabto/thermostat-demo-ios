//
//  EdgeManager.swift
//  HeatpumpDemo
//

import UIKit
import NabtoEdgeClient

class EdgeManager {

    // coap
    // let appSpecificApiKey = "sk-5f3ab4bea7cc2585091539fb950084ce"

    // password-open
    let appSpecificApiKey = "sk-9c826d2ebb4343a789b280fe22b98305"

    internal static let shared = EdgeManager()
    private var client_: NabtoEdgeClient.Client! = nil
    internal var client: NabtoEdgeClient.Client {
        get {
            if (self.client_ == nil) {
                self.client_ = NabtoEdgeClient.Client()
            }
            return self.client_
        }
    }

    private var cache: [Bookmark:Connection] = [:]

    func stop() {
        self.client_?.stop()
        self.client_ = nil
    }

    func connect(_ target: Bookmark) throws -> Connection {
        if (cache[target] == nil) {
            cache[target] = try doConnect(target)
        }
        return cache[target]!
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

    func clearConnectionCacheEntry(_ target: Bookmark) throws {
        if let connection = self.cache[target] {
            try connection.close()
            self.cache.removeValue(forKey: target)
        }
    }
}
