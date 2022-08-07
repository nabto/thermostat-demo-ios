//
//  ProfileManager.swift
//  HeatpumpDemo
//
//  Created by Tiago Lira on 02/02/2017.
//  Copyright © 2017 Nabto. All rights reserved.
//

import UIKit

enum DefaultsKey: String {
    case certificate = "certificate"
    case username = "username"
}

class ProfileTools {

    class func saveProfile(username: String, certificate: String) {
        ProfileTools.saveUsername(username: username)
        ProfileTools.saveCertificate(certificate: certificate)
    }
    
    class func clearProfile() {
        ProfileTools.clearUsername()
        ProfileTools.clearCertificate()
    }
    
    class func getSavedUsername() -> String? {
        return UserDefaults.standard.string(forKey: DefaultsKey.username.rawValue)
    }
    
    class func saveUsername(username: String) {
        let defaults = UserDefaults.standard
        defaults.set(username, forKey: DefaultsKey.username.rawValue)
        defaults.synchronize()
    }

    class func clearUsername() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: DefaultsKey.username.rawValue)
        defaults.synchronize()
    }
    
    class func getSavedCertificate() -> String? {
        return UserDefaults.standard.string(forKey: DefaultsKey.certificate.rawValue)
    }
    
    class func saveCertificate(certificate: String) {
        let defaults = UserDefaults.standard
        defaults.set(certificate, forKey: DefaultsKey.certificate.rawValue)
        defaults.synchronize()
    }
    
    class func clearCertificate() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: DefaultsKey.certificate.rawValue)
        defaults.synchronize()
    }
}
