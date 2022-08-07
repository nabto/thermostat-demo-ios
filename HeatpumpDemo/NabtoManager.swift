//
//  NabtoManager.swift
//  HeatpumpDemo
//
//  Created by Tiago Lira on 31/01/2017.
//  Copyright © 2017 Nabto. All rights reserved.
//

import UIKit

enum NabtoError : Error {
    case undefined
    case timedOut(deviceID: String?)
    case notInLocalList(deviceID: String?)
    case noAccess
    case empty
    case authenticationFailed
    case invalidSession
    
    init(eventCode: Int, deviceID: String?) {
        switch eventCode {
        case 1000026, 2000058:
            self = .timedOut(deviceID: deviceID)
        case 2000065:
            self = .noAccess
        default:
            self = .undefined
        }
    }
}

class NabtoManager: Any {
    static let shared = NabtoManager()
    private init() {}

    // NOTE: Using dummy password for the example app.
    // If necessary, encrypt with either
    // user provided password (more complex user experience) or protect
    // with a random password and store it securely
    private var pkPassword = "empty"
    private var lastUser: String?
    private var initialized = false
        
    let nabto = { return NabtoClient.instance() as! NabtoClient }()
    
    //MARK: - App state changes
    
    func appDidBecomeActive() {
        self.startup { (success, error) in
            if success {
                print("startup: \(success)")
                if let username = ProfileTools.getSavedUsername() {
                    //open session with the saved profile certificate
                    self.openSessionForProfile(username: username, completion: { (success, error) in
                        print("open session: \(success)")
                    })
                }
            }
        }
    }
    
    func appWillResignActive() {
        self.shutdown { (success, error) -> () in
        }
    }
    
    //MARK: - Startup / shutdown / session management
    
    func startup(completion:  @escaping (_ success : Bool, _ error : NabtoError?)->()) {
        DispatchQueue.global(qos: .userInitiated).async {
            let status = self.nabto.nabtoStartup()
            switch status {
            case .NCS_OK:
                DispatchQueue.main.async {
                    self.initialized = true
                    completion(true, nil)
                }
            default:
                DispatchQueue.main.async {
                    completion(false, .undefined)
                }
            }
        }
    }
    
    func startupAndOpenGuestSession(completion: @escaping (_ success : Bool, _ error : NabtoError?)->()) {
        DispatchQueue.global(qos: .userInitiated).async {
            let startStatus = self.nabto.nabtoStartup()
            switch startStatus {
            case .NCS_OK:
                self.initialized = true
                let status = self.nabto.nabtoOpenSessionGuest()
                DispatchQueue.main.async {
                    if status == .NCS_OK {
                        completion(true, nil)
                    } else {
                        completion(false, .undefined)
                    }
                }
            default:
                DispatchQueue.main.async {
                    completion(false, .undefined)
                }
            }
        }
    }
    
    func openSessionForProfile(username: String?, completion: @escaping (_ success : Bool, _ error : NabtoError?)->()) {
        DispatchQueue.global(qos: .userInitiated).async {
            let status = self.nabto.nabtoOpenSession(username, withPassword: self.pkPassword)
            if status == .NCS_OK {
                let path = Bundle.main.url(forResource: "unabto_queries", withExtension: "xml")!
                let content = (try? String(contentsOf: path, encoding: String.Encoding.utf8)) ?? "" //handle error
        
                var buffer: UnsafeMutablePointer<Int8>? = nil
                let interfaceStatus = self.nabto.nabtoRpcSetDefaultInterface(content, withErrorMessage: &buffer)
                if interfaceStatus == .NCS_OK {
                    DispatchQueue.main.async {
                        completion(true, nil)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(false, .undefined)
                    }
                }
            } else if status == .NCS_OPEN_CERT_OR_PK_FAILED {
                DispatchQueue.main.async {
                    completion(false, .authenticationFailed)
                }
            } else {
                DispatchQueue.main.async {
                    completion(false, .undefined)
                }
            }
            
        }
    }
    
    func shutdown(completion: @escaping (_ success : Bool, _ error : NabtoError?)->()) {
        DispatchQueue.global(qos: .userInitiated).async {
            let status = self.nabto.nabtoShutdown()
            DispatchQueue.main.async {
                if status == .NCS_OK {
                    completion(true, nil)
                } else {
                    completion(false, .undefined)
                }
            }
        }
    }
    
    func restartAndOpenSession(username: String, completion: @escaping (_ success : Bool, _ error : NabtoError?)->()) {
        self.shutdown { (success, error) in
            if success {
                self.startup(completion: { (success, error) in
                    if success {
                        self.openSessionForProfile(username: username, completion: { (success, error) in
                            if success {
                                completion(true, nil)
                            } else {
                                completion(false, error)
                            }
                        })
                    } else {
                        completion(false, error)
                    }
                })
            } else {
                completion(false, error)
            }
        }
    }
    
    //MARK: - Account
    
    func createKeyPair(username: String, completion: @escaping (_ result : Bool, _ error : NabtoError?)->()){
        if initialized {
            doCreateKeyPair(username: username, completion: completion)
        } else {
            startup(completion: { (success, error) in
                if success {
                    self.doCreateKeyPair(username: username, completion: completion)
                } else {
                    completion(false, .undefined)
                }
            })
        }
    }
    
    func doCreateKeyPair(username: String, completion: @escaping (_ success : Bool, _ error : NabtoError?)->()){
        DispatchQueue.global(qos: .userInitiated).async {
            let status = self.nabto.nabtoCreateSelfSignedProfile(username, withPassword: self.pkPassword)
            switch status {
            case .NCS_OK:
                DispatchQueue.main.async {
                    completion(true, nil)
                }
            default:
                DispatchQueue.main.async {
                    completion(false, .undefined)
                }
            }
        }
    }
    
    func getFingerprint(username: String, completion:  @escaping (_ result : String?, _ error : NabtoError?)->()) {
        DispatchQueue.global(qos: .userInitiated).async {
            
            let string = self.getFingerprintInternal(username: username)
            DispatchQueue.main.async {
                if let string = string {
                    completion(string, nil)
                } else {
                    completion(nil, .undefined)
                }
            }
        }
    }
    
    func getFingerprintInternal(username: String) -> String? {
        var buffer = [Int8](repeating: 0, count: 16)
        let status = self.nabto.nabtoGetFingerprint(username, withResult: &buffer)
        if status == .NCS_OK {
            var result = ""
            for item in buffer {
                let unsigned = UInt8(bitPattern: item)
                let string = String(format:"%02x", unsigned)
                result += string
            }
            return result
        }
        return nil
    }
    
    //MARK: - Get device info - for discover and bookmarked items
    
    func discover(progress: @escaping (_ device : NabtoDevice)->(), failure: @escaping (_ error : NabtoError)->()) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let list = self.nabto.nabtoGetLocalDevices() as? [String] {
                print(list)
                if list.count != 0 {
                    self.getDevicesInfoInBackground(deviceIDs: list, progress: progress, failure: failure)
                } else {
                    DispatchQueue.main.async {
                        failure(.empty)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    failure(.undefined)
                }
            }
        }
    }
    
    func getDevicesInfo(bookmarks: [Bookmark], progress: @escaping (_ device : NabtoDevice)->(), failure: @escaping (_ error : NabtoError)->()) {
        let ids = bookmarks.map { $0.id }
        DispatchQueue.global(qos: .userInitiated).async {
            let list = self.nabto.nabtoGetLocalDevices()
            if  let list = list as? [String] {
                print(list)
                for device in ids where !(list.contains(device)) {
                    DispatchQueue.main.async {
                        failure(.notInLocalList(deviceID: device))
                    }
                }
            }
            self.getDevicesInfoInBackground(deviceIDs: ids, progress: progress, failure: failure)
        }
    }
    
    func getDevicesInfoInBackground(deviceIDs: [String], progress: @escaping (_ device : NabtoDevice)->(), failure: @escaping (_ error : NabtoError)->()) {
        for deviceID in deviceIDs {
            self.invokeRpc(device: deviceID, request: "get_public_device_info.json", parameters: nil, completion: { (result, error) in
                if let result = result {
                    let device = NabtoDevice(id: deviceID, nabtoInfo: result)
                    DispatchQueue.main.async {
                        progress(device)
                    }
                } else {
                    DispatchQueue.main.async {
                        failure(error ?? .undefined)
                    }
                }
            })
        }
    }
    
    func getCurrentUser(device: NabtoDevice, completion: @escaping (_ success : Bool, _ users: [UserInfo]?, _ error : NabtoError?)->()) {
        invokeRpc(device: device.id, request: "get_current_user.json", parameters: nil, completion: { (result, error) in
            if let result = result,
                let status = result["status"] as? Int,
                status == Int(NabtoClientStatus.NCS_OK.rawValue) {
                completion(true, nil, nil)
            } else {
                completion(false, nil, .undefined)
            }
        })
    }
    
    //MARK: - Device pairing
    
    func pairWithCurrentUser(device: NabtoDevice, completion: @escaping (_ success : Bool, _ error : NabtoError?)->()) {
        let username = ProfileTools.getSavedUsername()
        let parameters = ["name": username!]
        invokeRpc(device: device.id, request: "pair_with_device.json", parameters: parameters, completion: { (result, error) in
            if let result = result,
                let status = result["status"] as? Int,
                status == Int(NabtoClientStatus.NCS_OK.rawValue) {
                device.currentUserIsPaired = true
                if let permissions = result["permissions"] as? UInt {
                    device.currentUserIsOwner = UserInfo.isOwner(permissions: permissions)
                }
                BookmarkManager.shared.add(bookmark: Bookmark(id: device.id, name: device.name))
                completion(true, nil)
            } else {
                completion(false, .undefined)
            }
            
        })
    }
    
    //MARK: - Settings
    
    func updateDeviceInfo(device: NabtoDevice, completion: @escaping (_ success : Bool, _ device: NabtoDevice?, _ error : NabtoError?)->()) {
        guard let name = device.name else {
            completion(false, nil, nil)
            return
        }
        let parameters = ["device_name": name]
        invokeRpc(device: device.id, request: "set_device_info.json", parameters: parameters, completion: { (result, error) in
            if let result = result,
                let name = result["name"] as? String {
                device.name = name
                completion(true, device, nil)
            } else {
                completion(false, nil, .undefined)
            }
        })

    }
    
    func readSecuritySettings(device: NabtoDevice, completion: @escaping (_ success : Bool, _ device: NabtoDevice?, _ error : NabtoError?)->()) {
        invokeRpc(device: device.id, request: "get_system_security_settings.json", parameters: nil, completion: { (result, error) in
            if let result = result,
                let status = result["status"] as? Int,
                status == Int(NabtoClientStatus.NCS_OK.rawValue),
                let permissions = result["permissions"] as? UInt,
                let defPermissions = result["default_user_permissions_after_pairing"] as? UInt {
                device.setSecurityDetails(permissions: permissions, defaultUserPermissions: defPermissions)
                completion(true, device, nil)
            } else {
                completion(false, nil, error ?? .undefined)
            }
        })
    }
    
    func updateSecuritySettings(device: NabtoDevice, completion: @escaping (_ success : Bool, _ device: NabtoDevice?, _ error : NabtoError?)->()) {
        let parameters = ["permissions": device.getSystemPermissions(),
                          "default_user_permissions_after_pairing": device.getDefaultUserPermissions()]
        
        invokeRpc(device: device.id, request: "set_system_security_settings.json", parameters: parameters, completion: { (result, error) in
            if result != nil {
                completion(true, device, nil)
            } else {
                completion(false, nil, error ?? .undefined)
            }
        })
    }
    
    //MARK: - Device - User management
    
    func getUsers(device: NabtoDevice, completion: @escaping (_ success : Bool, _ users: [UserInfo]?, _ error : NabtoError?)->()) {
        let params = ["start" : 0, "count" : 20]
        invokeRpc(device: device.id, request: "get_users.json", parameters: params, completion: { (result, error) in
            if let result = result,
            let list = result["users"] as? [[String: Any]] {
                var users: [UserInfo] = []
                for item in list {
                    if let fingerprint = item["fingerprint"] as? String,
                        let name = item["name"] as? String,
                        let permissions = item["permissions"] as? UInt {
                        let user = UserInfo(name: name, fingerprint: fingerprint, permissions: permissions)
                        users.append(user)
                    }
                }
                completion(true, users, nil)
            } else {
                completion(false, nil, error ?? .undefined)
            }
        })
    }

    func setUserPermissions(device: NabtoDevice, user: UserInfo, completion: @escaping (_ success : Bool, _ users: UserInfo?, _ error : NabtoError?)->()) {
        let parameters: [String : Any] = ["fingerprint": user.fingerprint, "permissions": user.permissions]
        invokeRpc(device: device.id, request: "set_user_permissions.json", parameters: parameters, completion: { (result, error) in
            if let result = result,
                let status = result["status"] as? Int,
                status == Int(NabtoClientStatus.NCS_OK.rawValue) {
                completion(true, user, nil)
            } else {
                completion(false, nil, error ?? .undefined)
            }
        })
    }
    
    func setUserName(device: NabtoDevice, user: UserInfo, completion: @escaping (_ success : Bool, _ users: UserInfo?, _ error : NabtoError?)->()) {
        let parameters = ["fingerprint": user.fingerprint, "name": user.name]
        invokeRpc(device: device.id, request: "set_user_name.json", parameters: parameters, completion: { (result, error) in
            if let result = result,
                let status = result["status"] as? Int,
                status == Int(NabtoClientStatus.NCS_OK.rawValue) {
                completion(true, user, nil)
            } else {
                completion(false, nil, error ?? .undefined)
            }
        })
    }
    
    func removeUser(device: NabtoDevice, user: UserInfo, completion: @escaping (_ success : Bool, _ error : NabtoError?)->()) {
        let parameters = ["fingerprint": user.fingerprint]
        invokeRpc(device: device.id, request: "remove_user.json", parameters: parameters, completion: { (result, error) in
            if let result = result,
                let status = result["status"] as? Int,
                status == Int(NabtoClientStatus.NCS_OK.rawValue) {
                completion(true, nil)
            } else {
                completion(false, error ?? .undefined)
            }
        })
    }
    
    //MARK: - Main invoke methods
    //used to make requests to a device
    
    func invokeRpc(device: String, request: String, parameters: [String : Any]?, completion: @escaping (_ result : [String : Any]?, _ error : NabtoError?)->()) {
        DispatchQueue.global(qos: .userInitiated).async {
            var link = "nabto://\(device)/\(request)"
            if let parameters = parameters {
                let string = self.buildParameterString(dictionary: parameters)
                    link += "?" + string
            }
            do {
                var buffer: UnsafeMutablePointer<Int8>? = nil
                let status = self.nabto.nabtoRpcInvoke(link, withResultBuffer: &buffer)
                if status == .NCS_OK {
                    if let string = String(validatingUTF8: buffer!),
                        let data = string.data(using: .utf8) {
                        print(string)
                        if let object = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                            let response = object["response"] as? [String: Any] {
                            DispatchQueue.main.async {
                                completion(response, nil)
                            }
                        } else {
                            throw NabtoError.undefined
                        }
                    } else {
                        throw NabtoError.undefined
                    }
                } else if status == .NCS_FAILED_WITH_JSON_MESSAGE {
                    if let string = String(validatingUTF8: buffer!),
                        let data = string.data(using: .utf8),
                        let object = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                        let error = object["error"] as? [String: Any],
                        let event = error["event"] as? Int {
                        print(string)
                        throw NabtoError(eventCode: event, deviceID: device)
                    } else {
                        throw NabtoError.undefined
                    }
                } else if status == .NCS_INVALID_SESSION {
                    throw NabtoError.invalidSession
                } else {
                    throw NabtoError.undefined
                }
            } catch {
                DispatchQueue.main.async {
                    completion(nil, error as? NabtoError ?? .undefined)
                }
            }
        }
    }
    
    func buildParameterString(dictionary: [String: Any]) -> String {
        var parameters: [String] = []
        for (key, value) in dictionary {
            let valueString = String(describing: value)
            if let k = key.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed),
                let v = valueString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) {
                parameters.append(k+"="+v)
            }
        }
        return parameters.joined(separator: "&")
    }
}
