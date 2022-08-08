//
//  ProfileEditViewController.swift
//  HeatpumpDemo
//
//  Created by Nabto on 31/01/2022.
//  Copyright © 2022 Nabto. All rights reserved.
//

import UIKit

class EditUserViewController: UIViewController, UITextFieldDelegate {
    
    var device : NabtoDevice!
    var user   : UserInfo!
    
    @IBOutlet weak var remoteSwitch : UISwitch!
    @IBOutlet weak var nameField    : UITextField!
    @IBOutlet weak var removeButton : UIButton!
    @IBOutlet weak var topLabel     : UILabel!
    @IBOutlet weak var accessLabel  : UILabel!
    @IBOutlet weak var removeLabel  : UILabel!
    @IBOutlet weak var scrollView   : UIScrollView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        removeButton.clipsToBounds = true
        removeButton.layer.cornerRadius = 6
        
        nameField.text = user.name
        remoteSwitch.isOn = user.hasRemoteAccess
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureLabels()
    }
    
    func configureLabels() {
        topLabel.text = "Control how \(user.name) may access your \(device.product!) device."
        accessLabel.text = "If remote access is enabled for your \(device.product!) device, allow this specific user to access it from remote."
        removeLabel.text = "Revoke the access granted to \(user.name)"
    }
    
    //MARK: - Editing user account
    
    func saveUserName() {
        NabtoManager.shared.setUserName(device: device, user: user) { (success, user, error) in
            if success {
                self.configureLabels()
            }
        }
    }
    
    func removeUser() {
        NabtoManager.shared.removeUser(device: device, user: user) { (success, error) in
            if success {
                _ = self.navigationController?.popViewController(animated: true)
            }
        }
    }
    
    func saveUserPermissions() {
        user.setRemoteAccessPermission(allowed: remoteSwitch.isOn)
        NabtoManager.shared.setUserPermissions(device: device, user: user) { (success, user, error) in
            if success {
            }
        }
    }
    
    func confirmRemoveUser() {
        //avoid deleting the user's own account
        guard user.fingerprint != ProfileTools.getSavedPrivateKey() else { return }
        
        let title = "Remove user"
        let message = "Are you sure you want to remove \(user.name)?"
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let yesAction = UIAlertAction(title: "Yes", style: .default) { action in
            self.removeUser()
            alert.dismiss(animated: true, completion: nil)
        }
        let noAction = UIAlertAction(title: "No", style: .cancel) { action in
            alert.dismiss(animated: true, completion: nil)
        }
        alert.addAction(noAction)
        alert.addAction(yesAction)
        present(alert, animated: true, completion: nil)
    }

    
    //MARK: - IBActions
    
    @IBAction func goToHome(_ sender: Any) {
        _ = navigationController?.popToRootViewController(animated: true)
    }
    
    @IBAction func pairingValueChanged(_ sender: UISwitch) {
        saveUserPermissions()
    }
    
    @IBAction func removeAction(_ sender: Any) {
        confirmRemoveUser()
    }
    
    //MARK: - Textfield
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        if let text = textField.text,
            text.characters.count > 0 && text != user.name {
            user.name = text
            saveUserName()
        }
        return false
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        let rect = CGRect(x: 0, y: scrollView.contentSize.height - 10, width: 10, height: 10)
        scrollView.scrollRectToVisible(rect, animated: true)
    }
}
