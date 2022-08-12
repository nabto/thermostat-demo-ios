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

class PairingViewController: UIViewController, PairingConfirmedListener {

    @IBOutlet weak var nameLabel        : UILabel!
    @IBOutlet weak var modelLabel       : UILabel!
    @IBOutlet weak var confirmLabel     : UILabel!
    @IBOutlet weak var confirmView      : UIView!
    @IBOutlet weak var resultView       : UIView!
    @IBOutlet weak var confirmButton    : UIButton!
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
        confirmButton.layer.cornerRadius    = 6
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

    override func viewDidDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
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

    func pairingConfirmed() {
        self.navigationController?.popToRootViewController(animated: true)
    }

    @IBAction func confirmPairing(_ sender: Any) {
        guard let device = device else { return }
        self.confirmSpinner.startAnimating()
        DispatchQueue.global().async {
            do {
                let modes = try IamUtil.getAvailablePairingModes(connection: EdgeManager.shared.getConnection(device))
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
                    if (try IamUtil.isCurrentUserPaired(connection: EdgeManager.shared.getConnection(device))) {
                        try self.updateBookmarkWithDeviceInfo(device)
                        self.showConfirmation()
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

    private func updateBookmarkWithDeviceInfo(_ device: Bookmark) throws {
        let user = try IamUtil.getCurrentUser(connection: EdgeManager.shared.getConnection(device))
        device.role = user.Role
        device.sct = user.Sct
        let details = try IamUtil.getDeviceDetails(connection: EdgeManager.shared.getConnection(device))
        if let appname = details.AppName {
            device.name = appname
        }
    }

    private func pairLocalOpen() throws {
        guard let device = self.device else { return }
        let connection = try EdgeManager.shared.getConnection(device)
        if let user = ProfileTools.getSavedUsername() {
            try IamUtil.pairLocalOpen(connection: connection, desiredUsername: user)
        } else {
            self.showPairingError("User profile not found, please re-configure app")
        }
    }

    private func pairLocalInitial() throws {
        guard let device = self.device else { return }
        let connection = try EdgeManager.shared.getConnection(device)
        try IamUtil.pairLocalInitial(connection: connection)
    }

    private func pairPasswordOpen() throws {
        guard let device = self.device else { return }
        var password: String? = nil
        DispatchQueue.main.sync {
            if (self.passwordField.isHidden) {
                self.confirmLabel.text = self.passwordText
                self.passwordField.isHidden = false
                self.passwordField.becomeFirstResponder()
            } else if let userPassword = self.passwordField.text {
                password = userPassword
            }
        }
        if let password = password {
            if let user = ProfileTools.getSavedUsername() {
                let connection = try EdgeManager.shared.getConnection(device)
                try IamUtil.pairPasswordOpen(connection: connection, desiredUsername: user, password: password)
            } else {
                self.showPairingError("User profile not found, please re-configure app")
            }
        }
    }

    func showConfirmation() {
        DispatchQueue.main.sync {
            let controller = StoryboardHelper.getViewController(id: "PairingConfirmedViewController") as! PairingConfirmedViewController
            controller.device = self.device
            controller.pairingConfirmedDelegate = self
            navigationController?.pushViewController(controller, animated: true)
        }
    }
    
    @IBAction func goToHome(_ sender: Any) {
        _ = navigationController?.popToRootViewController(animated: true)
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let device = sender as? Bookmark else { return }
        if let destination = segue.destination as? DeviceDetailsViewController {
            destination.device = device
        }
    }
    
}
