//
//  PairingConfirmedViewController.swift
//  Edge Heat
//
//  Created by Ulrik Gammelby on 11/08/2022.
//  Copyright © 2022 Nabto. All rights reserved.
//

import Foundation
import UIKit

protocol PairingConfirmedListener {
    func pairingConfirmed()
}

class PairingConfirmedViewController: ViewControllerWithDevice {
    
    @IBOutlet weak var congratulationsLabel: UILabel!
    @IBOutlet weak var saveAndShowDeviceButton: UIButton!
    @IBOutlet weak var nameField: UITextField!
    var pairingConfirmedDelegate: PairingConfirmedListener?

    var appName: String = "My Heatpump"
    let text = "Congratulations! You are successfully paired with device '%@.%@' in role '%@'."

    override func viewDidLoad() {
        super.viewDidLoad()
        saveAndShowDeviceButton.layer.cornerRadius  = 6
        saveAndShowDeviceButton.clipsToBounds   = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.isModalInPresentation = true
        self.congratulationsLabel.text = String(format: text, self.device.productId, self.device.deviceId, self.device.role ?? "(not set)")
        self.nameField.text = self.device.name
    }

    @IBAction func handleTapSave(_ sender: Any) {
        if let name = self.nameField.text {
            if (name.count > 0) {
                self.device.name = name
                self.pairingConfirmedDelegate?.pairingConfirmed()
                BookmarkManager.shared.add(bookmark: self.device)
                dismiss(animated: true, completion: nil)
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}
