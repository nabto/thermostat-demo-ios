//
//  DeviceSettingsViewController.swift
//  HeatpumpDemo
//
//  Created by Nabto on 31/01/2022.
//  Copyright © 2022 Nabto. All rights reserved.
//

import UIKit

class DeviceSettingsViewController: UIViewController, UITextFieldDelegate {

    var device : Bookmark!

    @IBOutlet weak var nameTextField : UITextField!
    @IBOutlet weak var deviceIDLabel : UILabel!
    @IBOutlet weak var securityLabel : UILabel!
    @IBOutlet weak var securityButton: UIButton!
    @IBOutlet weak var guestLabel    : UILabel!
    
    var starting = true
    
    override func viewDidLoad() {
        super.viewDidLoad()

        securityButton.clipsToBounds = true
        securityButton.layer.cornerRadius = 6
        
        nameTextField.text = device.name
        deviceIDLabel.text = "\(device.productId).\(device.deviceId)"
        
        readSecuritySettings()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if !starting {
            readSecuritySettings()
        } else {
            starting = false
        }
        securityButton.isHidden = false // todo !(device.role == "Admin")
        guestLabel.isHidden = true // todo device.currentUserIsOwner
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    @IBAction func goToHome(_ sender: Any) {
        _ = navigationController?.popToRootViewController(animated: true)
    }
    
    func readSecuritySettings() {
//        guard device.currentUserIsOwner else { return }
//        NabtoManager.shared.readSecuritySettings(device: device) { (success, device, error) in
//            if success {
//                self.device = device
//                self.updateSecurityMessage()
//            }
//        }
    }
    
    func updateSecurityMessage() {
//        if device.openForPairing {
//            securityLabel.text = "This device is currently open for pairing to grant new guests access.";
//        } else {
//            securityLabel.text = "This device is closed for pairing, change this to grant new guests access.";
//        }
    }
    
    func saveDeviceName() {
//        NabtoManager.shared.updateDeviceInfo(device: device) { (success, device, error) in
//            if success {
//                self.device = device
//                self.confirmDeviceUpdate()
//            } else {
//                print("error saving device name")
//            }
//        }
    }
    
    func confirmDeviceUpdate() {
        let message = "Device updated successfully."
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let yesAction = UIAlertAction(title: "Ok", style: .default) { action in
            alert.dismiss(animated: true, completion: nil)
        }
        alert.addAction(yesAction)
        present(alert, animated: true, completion: nil)
    }
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destination = segue.destination as? SecuritySettingsViewController {
            destination.device = device
        }
    }
    
    //MARK: - Textfield

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        if let text = textField.text,
            text.characters.count > 0 && text != device.name {
            device.name = text
            saveDeviceName()
        }
        return false
    }
}
