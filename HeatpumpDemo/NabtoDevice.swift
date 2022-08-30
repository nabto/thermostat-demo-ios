//
//  NabtoDevice.swift
//  ThermostatDemo
//
//  Created by Nabto on 31/01/2022.
//  Copyright © 2022 Nabto. All rights reserved.
//

import UIKit

struct Permission {
    static let LOCAL_ACCESS : UInt          = 0x80000000
    static let REMOTE_ACCESS : UInt         = 0x40000000
    static let ADMIN : UInt                 = 0x20000000
    static let SYSTEM_LOCAL_ACCESS : UInt   = 0x80000000
    static let SYSTEM_REMOTE_ACCESS : UInt  = 0x40000000
    static let SYSTEM_PAIRING : UInt        = 0x20000000
}

class NabtoDevice {

    var id          : String
    var name        : String?
    var product     : String?
    var iconUrl     : String?
    var reachable               = true
    var openForPairing          = false
    var remoteAccessEnabled     = false
    var grantGuestRemoteAccess  = false
    var currentUserIsPaired     = false
    var currentUserIsOwner      = false
    
    init(id: String, nabtoInfo: [String: Any]) {
        self.id = id
        self.name = nabtoInfo["device_name"] as? String
        self.product = nabtoInfo["device_type"] as? String
        self.iconUrl = nabtoInfo["device_icon"] as? String
        if let openForPairing = nabtoInfo["is_open_for_pairing"] as? Bool {
            self.openForPairing = openForPairing
        }
        if let currentUserIsPaired = nabtoInfo["is_current_user_paired"] as? Bool {
            self.currentUserIsPaired = currentUserIsPaired
        }
        if let currentUserIsOwner = nabtoInfo["is_current_user_owner"] as? Bool {
            self.currentUserIsOwner = currentUserIsOwner
        }
    }
    
    init(unreachable id: String, name: String?, timedOut: Bool) {
        self.id = id
        self.name = name ?? "Unknown"
        self.product = timedOut ? "Device is offline" : "Connecting..."
        self.reachable = false
    }
    
    func getSystemPermissions() -> UInt {
        return (Permission.SYSTEM_LOCAL_ACCESS |
            (remoteAccessEnabled ? Permission.SYSTEM_REMOTE_ACCESS : 0) |
            (openForPairing ? Permission.SYSTEM_PAIRING : 0))
    }
    
    func getDefaultUserPermissions() -> UInt {
        if grantGuestRemoteAccess {
            return (Permission.REMOTE_ACCESS | Permission.LOCAL_ACCESS)
        } else {
            return Permission.LOCAL_ACCESS
        }
    }
    
    func setSecurityDetails(permissions: UInt, defaultUserPermissions: UInt) {
        remoteAccessEnabled = ((permissions & Permission.SYSTEM_REMOTE_ACCESS) ==
            Permission.SYSTEM_REMOTE_ACCESS)
        openForPairing = ((permissions & Permission.SYSTEM_PAIRING) ==
            Permission.SYSTEM_PAIRING)
        grantGuestRemoteAccess = ((defaultUserPermissions & Permission.REMOTE_ACCESS) ==
            Permission.REMOTE_ACCESS)
    }
}
