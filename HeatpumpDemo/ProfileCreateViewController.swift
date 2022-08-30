//
//  ProfileViewController.swift
//  ThermostatDemo
//
//  Created by Nabto on 31/01/2022.
//  Copyright © 2022 Nabto. All rights reserved.
//

import UIKit
import NabtoEdgeClient
import NotificationBannerSwift

protocol ProfileCreatedListener {
    func profileCreated()
}

class ProfileCreateViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var textField        : UITextField!
    @IBOutlet weak var continueButton   : UIButton!
    @IBOutlet weak var clearButton      : UIButton!
    @IBOutlet weak var pagePosition     : NSLayoutConstraint!
    @IBOutlet weak var topLabel         : UILabel!
    @IBOutlet weak var cancelButton: UIBarButtonItem!
    
    var isReset = false
    var profileCreatedDelegate: ProfileCreatedListener?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.isModalInPresentation = true

        continueButton.clipsToBounds    = true
        clearButton.clipsToBounds       = true
        continueButton.layer.cornerRadius = 6
        clearButton.layer.cornerRadius    = 6

        textField.text = UIDevice.current.name
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func createProfile(_ sender: Any) {
        guard let username = textField.text, username.count > 2 else { return }
        let simplifiedUsername = ProfileTools.convertToValidUsername(input: username)
        do {
            let key = try EdgeManager.shared.client.createPrivateKey()
            ProfileTools.saveProfile(username: simplifiedUsername, privateKey: key, displayName: username)
            self.profileCreatedDelegate?.profileCreated()
            self.dismiss(animated: true, completion: nil)
        } catch {
            let banner = NotificationBanner(title: "Error", subtitle: "Could not create private key: \(error)", style: .danger)
            banner.show()
        }
    }
    
    @IBAction func clear(_ sender: Any) {
        textField.text = nil
    }

    @IBAction func cancel(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    //MARK: - Textfield
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if view.frame.size.height < 460 {
            pagePosition.constant = -40
            topLabel.isHidden = true
        }
    }
    func textFieldDidEndEditing(_ textField: UITextField) {
        pagePosition.constant = 32
        topLabel.isHidden = false
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
}
