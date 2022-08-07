//
//  DiscoverViewController.swift
//  HeatpumpDemo
//
//  Created by Tiago Lira on 31/01/2017.
//  Copyright © 2017 Nabto. All rights reserved.
//

import UIKit

class DiscoverViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var table: UITableView!
    
    var devices: [NabtoDevice] = []
    var waiting  = true
    var starting = true

    override func viewDidLoad() {
        super.viewDidLoad()
        table.contentInset.top += 16

        findDevices()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !starting {
            findDevices()
        } else {
            starting = false
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func findDevices() {
        devices = []
        waiting = true
        self.table.reloadData()
        
        NabtoManager.shared.discover(progress: { (device) in
            self.devices.append(device)
            self.table.reloadData()
        }, failure: { (error) in
            self.waiting = false
            self.table.reloadData()
        })
    }
    
    //MARK: - Handle device selection

    func handleSelection(device: NabtoDevice) {
        if device.currentUserIsPaired {
            handlePaired(device: device)
        } else if device.openForPairing {
            handleUnpaired(device: device)
        } else {
            handleClosed(device: device)
        }
    }
    
    func handlePaired(device: NabtoDevice) {
        let message = "Device is already paired"
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        
        let okAction = UIAlertAction(title: "Ok", style: .default) { action in
            alert.dismiss(animated: true, completion: nil)
            
            if let controller = StoryboardHelper.viewControllerFor(device: device) {
                self.navigationController?.pushViewController(controller, animated: true)
            }
        }
        alert.addAction(okAction)
        present(alert, animated: true, completion: nil)
        
        //add bookmark (just in case it was deleted before)
        BookmarkManager.shared.add(bookmark: Bookmark(id: device.id, name: device.name))
    }
    
    func handleUnpaired(device: NabtoDevice) {
        performSegue(withIdentifier: "toPairing", sender: device)
    }
    
    func handleClosed(device: NabtoDevice) {
        let title = "Device not open"
        let message = "Sorry! This device is not open for pairing, please contact the device owner. Or perform a factory reset if you are the owner of the device but don't have access."
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Ok", style: .default) { action in
            alert.dismiss(animated: true, completion: nil)
        }
        alert.addAction(okAction)
        present(alert, animated: true, completion: nil)
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
    
    // MARK: - Button actions
    
    @IBAction func refresh(_ sender: Any) {
        findDevices()
    }
    
    @IBAction func goToHome(_ sender: Any) {
        _ = navigationController?.popToRootViewController(animated: true)
    }
    
    //MARK: - UITableView methods
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            if devices.count > 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "DeviceCell", for: indexPath) as! DeviceCell
                let device = devices[indexPath.row]
                cell.configure(device: device)
                cell.statusIcon.isHidden = true
                cell.lockIcon.image = UIImage(named: device.openForPairing ? "open" : "locked")?.withRenderingMode(.alwaysTemplate)
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "NoDevicesCell", for: indexPath) as! NoDevicesCell
                cell.configure(waiting: waiting)
                return cell
            }
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "DiscoverButtonCell", for: indexPath) as! DiscoverButtonCell
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section == 0 && devices.count > 0 else { return }
        
        handleSelection(device: devices[indexPath.row])
        tableView.deselectRow(at: indexPath, animated: true)
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

}
