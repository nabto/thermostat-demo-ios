//
//  StoryboardHelper.swift
//  HeatpumpDemo
//
//  Created by Tiago Lira on 03/02/2017.
//  Copyright © 2017 Nabto. All rights reserved.
//

import UIKit

// To add custom view controllers for your devices:
// 1 - Create a subclass of DeviceViewController
// 2 - Add it to the storyboard with correct storyboardID
// 3 - Add it to the options in this method

class StoryboardHelper {
    
    class func viewControllerFor(device: NabtoDevice) -> DeviceViewController? {
        
        let storyboard =  UIStoryboard(name: "Main", bundle: nil)
        
        var controller : DeviceViewController?
        
        //Add custom device screens here
        let demoProductType = "ACME 9002 Heatpump"
        if device.product != demoProductType {
            NSLog("Warning: Target device is of type \(device.product), this app only supports \(demoProductType)")
        }
        controller = storyboard.instantiateViewController(withIdentifier: "ACMEHeaterViewController") as! ACMEHeaterViewController

        controller?.device = device
        return controller
    }
}
