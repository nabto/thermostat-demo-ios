//
//  DeviceUser.swift
//  HeatpumpDemo
//
//  Created by Nabto on 31/01/2022.
//  Copyright © 2022 Nabto. All rights reserved.
//

import UIKit

class UserInfo {

    var name        : String
    var fingerprint : String
    var permissions : UInt
    
    init(name: String, fingerprint: String, permissions: UInt) {
        self.name = name
        self.fingerprint = fingerprint
        self.permissions = permissions
    }
    
    var isOwner: Bool {
        return ((permissions & Permission.ADMIN) == Permission.ADMIN)
    }
    
    var hasRemoteAccess: Bool {
        return ((permissions & Permission.REMOTE_ACCESS) == Permission.REMOTE_ACCESS)
    }
    
    func formattedRole() -> String {
        return (isOwner ? "Owner" : "Guest")
    }
    
    func formattedPermissions() -> String {
        return (hasRemoteAccess ? "local & remote access" : "local access only")
    }
    
    func setRemoteAccessPermission(allowed: Bool) {
        if (allowed) {
            permissions = permissions | Permission.REMOTE_ACCESS
        } else {
            permissions = permissions & ~(Permission.REMOTE_ACCESS)
        }
    }
    
    class func isOwner(permissions: UInt) -> Bool {
        return ((permissions & Permission.ADMIN) == Permission.ADMIN)
    }
    
    func formattedFingerprint() -> String {
        let string = fingerprint
        return UserInfo.format(fingerprint: string)
    }
    
    class func format(fingerprint: String) -> String {
        var result: [String] = []
        let chars = Array(fingerprint)
        for index in stride(from: 0, to: chars.count, by: 2) {
            result.append(String(chars[index..<min(index+2, chars.count)]))
        }
        return result.joined(separator: ":")
    }
}
