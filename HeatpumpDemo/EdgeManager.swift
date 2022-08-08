//
//  EdgeManager.swift
//  HeatpumpDemo
//

import UIKit
import NabtoEdgeClient

class EdgeManager {
    internal static let shared = EdgeManager()
    internal var client: NabtoEdgeClient.Client! = nil

    private var cache: [Bookmark:Connection] = [:]

    func start() {
        self.client = NabtoEdgeClient.Client()
    }

    func stop() {
        self.client?.stop()
        self.client = nil
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

        guard let key = ProfileTools.getSavedPrivateKey() else {
            throw NabtoEdgeClientError.FAILED_WITH_DETAIL(detail: "Private key not set")
        }
        try connection.setPrivateKey(key: key)

        if let sct = target.sct {
            try connection.setServerConnectToken(sct: sct)
        }

        return connection
    }

    func clearConnectionCacheEntry(_ target: Bookmark) throws {
        if let connection = self.cache[target] {
            try connection.close()
            self.cache.removeValue(forKey: target)
        }
    }
}
