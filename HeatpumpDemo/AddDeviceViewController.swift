//
//  PairingConfirmedViewController.swift
//  Edge Heat
//
//  Created by Ulrik Gammelby on 11/08/2022.
//  Copyright © 2022 Nabto. All rights reserved.
//

import Foundation
import UIKit

class AddDeviceViewController: UIViewController {
    
    @IBOutlet weak var pairingStringButton: UIButton!
    @IBOutlet weak var discoverButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        discoverButton.layer.cornerRadius  = 6
        discoverButton.clipsToBounds   = true
        pairingStringButton.layer.cornerRadius  = 6
        pairingStringButton.clipsToBounds   = true
    }
}
