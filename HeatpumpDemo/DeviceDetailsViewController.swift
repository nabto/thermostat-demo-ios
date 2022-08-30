//
//  VendorHeatingViewController.swift
//  ThermostatDemo
//
//  Created by Nabto on 31/01/2022.
//  Copyright © 2022 Nabto. All rights reserved.
//

import UIKit

// You should subclass this controller to implement custom devices.
// More info on StoryboardHelper.swift

class ViewControllerWithDevice: UIViewController {
    var device : Bookmark!
}

class DeviceDetailsViewController: ViewControllerWithDevice {

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationItem.title = device.name
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    @IBAction func goToHome(_ sender: Any) {
        _ = navigationController?.popToRootViewController(animated: true)
    }
    
    @IBAction func settingsTap(_ sender: Any) {
        let storyboard =  UIStoryboard(name: "Main", bundle: nil)
        let controller = storyboard.instantiateViewController(withIdentifier: "DeviceSettingsViewController") as! DeviceSettingsViewController
        controller.device = device
        navigationController?.pushViewController(controller, animated: true)
    }

}
