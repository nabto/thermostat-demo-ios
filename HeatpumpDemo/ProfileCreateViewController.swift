//
//  ProfileViewController.swift
//  HeatpumpDemo
//
//  Created by Nabto on 31/01/2022.
//  Copyright © 2022 Nabto. All rights reserved.
//

import UIKit

class ProfileCreateViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var textField        : UITextField!
    @IBOutlet weak var continueButton   : UIButton!
    @IBOutlet weak var clearButton      : UIButton!
    @IBOutlet weak var pagePosition     : NSLayoutConstraint!
    @IBOutlet weak var topLabel         : UILabel!
    @IBOutlet weak var cancelButton: UIBarButtonItem!
    
    var isReset = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.isModalInPresentation = true

        continueButton.clipsToBounds    = true
        clearButton.clipsToBounds       = true
        continueButton.layer.cornerRadius = 6
        clearButton.layer.cornerRadius    = 6

        textField.text = getSimpleDeviceName()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func createProfile(_ sender: Any) {
        guard let username = textField.text, username.count > 2 else { return }
        
        NabtoManager.shared.createKeyPair(username: username) { (success, error) in
            print("create profile: \(success)")
            if success {
                NabtoManager.shared.getFingerprint(username: username, completion: { (fingerprint, error) in
                    if let fingerprint = fingerprint {
                        print("fingerprint: \(fingerprint)")
                        ProfileTools.saveProfile(username: username, privateKey: fingerprint, displayName: "TBD")
                        self.dismiss(animated: true, completion: nil)
                        // todo - inform parent view
                    } else {
                        print("fingerprint: error")
                    }
                })
            } else {
                print("create profile: error")
            }
        }
    }
    
    @IBAction func clear(_ sender: Any) {
        textField.text = nil
    }

    @IBAction func cancel(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    func getSimpleDeviceName() -> String {
        let okayChars : Set<Character> =
            Set("abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLKMNOPQRSTUVWXYZ1234567890+-*=(),.:!_")
        return String(UIDevice.current.name.filter {okayChars.contains($0) })
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
