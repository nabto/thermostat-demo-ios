//
//  PairingViewController.swift
//  HeatpumpDemo
//
//  Created by Nabto on 31/01/2022.
//  Copyright © 2022 Nabto. All rights reserved.
//

import UIKit
import NabtoEdgeIamUtil
import NotificationBannerSwift

class PairingViewController: UIViewController {

    @IBOutlet weak var nameLabel        : UILabel!
    @IBOutlet weak var modelLabel       : UILabel!
    @IBOutlet weak var confirmLabel     : UILabel!
    @IBOutlet weak var confirmView      : UIView!
    @IBOutlet weak var resultView       : UIView!
    @IBOutlet weak var confirmButton    : UIButton!
    @IBOutlet weak var newDeviceButton  : UIButton!
    @IBOutlet weak var homeButton       : UIButton!
    @IBOutlet weak var checkMark        : UIImageView!
    @IBOutlet weak var passwordField: UITextField!
    
    var device : Bookmark?

    let defaultPairingText = "You are about to pair with this device."
    let passwordText = "This device requires a password for pairing:"

    let confirmSpinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView()
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.hidesWhenStopped = true
        return spinner
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        confirmButton.clipsToBounds     = true
        newDeviceButton.clipsToBounds   = true
        homeButton.clipsToBounds        = true
        confirmButton.layer.cornerRadius    = 6
        newDeviceButton.layer.cornerRadius  = 6
        homeButton.layer.cornerRadius       = 6
        checkMark.image = checkMark.image?.withRenderingMode(.alwaysTemplate)

        confirmButton.addSubview(confirmSpinner)
        confirmSpinner.leftAnchor.constraint(equalTo: confirmButton.leftAnchor, constant: 20.0).isActive = true
        confirmSpinner.centerYAnchor.constraint(equalTo: confirmButton.centerYAnchor).isActive = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        nameLabel.text  = device?.name
        modelLabel.text = device?.modelName
        passwordField.isHidden = true
        confirmLabel.text = self.defaultPairingText
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func showPairingError(_ msg: String) {
        DispatchQueue.main.async {
            let banner = GrowingNotificationBanner(title: "Pairing Error", subtitle: msg, style: .danger)
            banner.show()
        }
    }

    @IBAction func confirmPairing(_ sender: Any) {
        guard let device = device else { return }
        self.confirmSpinner.startAnimating()
        DispatchQueue.global().async {
            do {
                let connection = try EdgeManager.shared.connect(device)
                let modes = try IamUtil.getAvailablePairingModes(connection: connection)
                if (modes.count == 0) {
                    self.showPairingError("Device is not open for pairing - please contact the owner. If you are the owner, you can factory reset it to get access again.")
                } else {
                    if (modes.contains(PairingMode.LocalInitial)) {
                        try self.pairLocalInitial()
                    } else if (modes.contains(PairingMode.LocalOpen)) {
                        try self.pairLocalOpen()
                    } else if (modes.contains(PairingMode.PasswordOpen)) {
                        try self.pairPasswordOpen()
                    }
                }
            } catch IamError.USERNAME_EXISTS {
                self.showPairingError("User name '\(ProfileTools.getSavedUsername() ?? "nil")' already in use on device")
            } catch IamError.AUTHENTICATION_ERROR {
                self.showPairingError("Pairing password not valid for this device")
            } catch {
                self.showPairingError("An error occurred when pairing with device: \(error)")
            }
            DispatchQueue.main.async {
                self.confirmSpinner.stopAnimating()
            }
        }
    }

    private func pairLocalOpen() throws {
        guard let device = self.device else { return }
        let connection = try EdgeManager.shared.connect(device)
        if let user = ProfileTools.getSavedUsername() {
            try IamUtil.pairLocalOpen(connection: connection, desiredUsername: user)
        } else {
            self.showPairingError("User profile not found, please re-configure app")
        }
    }

    private func pairLocalInitial() throws {
        guard let device = self.device else { return }
        let connection = try EdgeManager.shared.connect(device)
        try IamUtil.pairLocalInitial(connection: connection)
    }

    private func pairPasswordOpen() throws {
        guard let device = self.device else { return }
        let connection = try EdgeManager.shared.connect(device)
        if (self.passwordField.isHidden) {
            DispatchQueue.main.async {
                self.confirmLabel.text = self.passwordText
                self.passwordField.isHidden = false
                self.passwordField.becomeFirstResponder()
            }
        } else if let password = self.passwordField.text {
            if let user = ProfileTools.getSavedUsername() {
                try IamUtil.pairPasswordOpen(connection: connection, desiredUsername: user, password: password)
            } else {
                self.showPairingError("User profile not found, please re-configure app")
            }
        }
    }

    @IBAction func goToNewDevice(_ sender: Any) {
        if let device = device,
            let controller = StoryboardHelper.viewControllerFor(device: device) {
            navigationController?.pushViewController(controller, animated: true)
        }
    }
    
    @IBAction func goToHome(_ sender: Any) {
        _ = navigationController?.popToRootViewController(animated: true)
    }
    
    func showResultView() {
        resultView.isHidden = false
        confirmView.isHidden = true
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let device = sender as? Bookmark else { return }
        
        if let destination = segue.destination as? DeviceViewController {
            destination.device = device
        }
    }
    
}
