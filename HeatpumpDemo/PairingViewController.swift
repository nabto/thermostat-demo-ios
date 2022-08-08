//
//  PairingViewController.swift
//  HeatpumpDemo
//
//  Created by Nabto on 31/01/2022.
//  Copyright © 2022 Nabto. All rights reserved.
//

import UIKit

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
    
    var device : NabtoDevice?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        nameLabel.text  = device?.name
        modelLabel.text = device?.product
        
        confirmButton.clipsToBounds     = true
        newDeviceButton.clipsToBounds   = true
        homeButton.clipsToBounds        = true
        confirmButton.layer.cornerRadius    = 6
        newDeviceButton.layer.cornerRadius  = 6
        homeButton.layer.cornerRadius       = 6
        checkMark.image = checkMark.image?.withRenderingMode(.alwaysTemplate)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    @IBAction func confirmPairing(_ sender: Any) {
        guard let device = device else { return }
        
        NabtoManager.shared.pairWithCurrentUser(device: device) { (success, error) in
            if success {
                device.currentUserIsPaired = true
                self.showResultView()
            } else {
                print("failed pairing")
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
        guard let device = sender as? NabtoDevice else { return }
        
        if let destination = segue.destination as? DeviceViewController {
            destination.device = device
        }
    }
    
}
