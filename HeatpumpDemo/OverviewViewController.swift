//
//  ViewController.swift
//  HeatpumpDemo
//
//  Created by Nabto on 30/01/2022.
//  Copyright © 2022 Nabto. All rights reserved.
//

import UIKit

class OverviewViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var table: UITableView!
    
    var devices: [EdgeDevice] = []
    var starting = true
    var waiting  = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        table.contentInset.top += 16
        startNabto()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if starting {
            starting = false
        } else {
            self.populateDeviceOverview()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func startNabto() {
        if let username = ProfileTools.getSavedUsername() {
            self.populateDeviceOverview()
            // TODO load user
        } else {
            self.performSegue(withIdentifier: "toProfile", sender: nil)
        }
    }

    func populateDeviceOverview() {
        let bookmarks = BookmarkManager.shared.deviceBookmarks
        DispatchQueue.global().async {
//            for b in bookmarks {
//                let connection =
//            }
            DispatchQueue.main.async {
                self.table.reloadData()
            }
        }
        // todo: retrieve information about devices
    }

    @IBAction func refresh(_ sender: Any) {
        self.populateDeviceOverview()
    }
    
    //MARK: - Handle device selection
    
    func handleSelection(device: EdgeDevice) {
        print("TODO - connect and pair or show device (or error); device: \(device.id)")
    }
    
    func handlePaired(device: NabtoDevice) {
        if let controller = StoryboardHelper.viewControllerFor(device: device) {
                self.navigationController?.pushViewController(controller, animated: true)
        }
    }
    
    func handleUnpaired(device: NabtoDevice) {
        performSegue(withIdentifier: "toPairing", sender: device)
    }
    
    func handleClosed(device: NabtoDevice) {
        let title = "Device not open"
        let message = "Device is not open for pairing - please contact owner (or factory reset if you are the owner."
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Ok", style: .default) { action in
            alert.dismiss(animated: true, completion: nil)
        }
        alert.addAction(okAction)
        present(alert, animated: true, completion: nil)
    }
    
    func handleOffline(device: NabtoDevice) {
        let title = "Device offline"
        let message = "Please check device state."
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Ok", style: .default) { action in
            alert.dismiss(animated: true, completion: nil)
        }
        alert.addAction(okAction)
        present(alert, animated: true, completion: nil)
    }
    
    //MARK: - UITableView methods
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if (indexPath.section == 0) {
            if (self.devices.count > 0) {
                let cell = tableView.dequeueReusableCell(withIdentifier: "DeviceCell", for: indexPath) as! DeviceCell
                let device = devices[indexPath.row]
                cell.configure(device: device)
                cell.lockIcon.isHidden = true
                cell.statusIcon.image = UIImage(named: true /* TODO */ ? "checkSmall" : "alert")?.withRenderingMode(.alwaysTemplate)
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "NoDevicesCell", for: indexPath) as! NoDevicesCell
                cell.configure(waiting: waiting)
                return cell
            }
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "OverviewButtonCell", for: indexPath) as! OverviewButtonCell
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section == 0 && self.devices.count > 0 else { return }
        handleSelection(device: self.devices[indexPath.row])
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? max(devices.count, 1) : 1
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return indexPath.section == 0 ? 72 : 110
    }

    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let device = sender as? NabtoDevice else { return }
        
        if let destination = segue.destination as? PairingViewController {
            destination.device = device
        } else if let destination = segue.destination as? DeviceViewController {
            destination.device = device
        }
    }
}

