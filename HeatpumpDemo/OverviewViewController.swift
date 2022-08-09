//
//  ViewController.swift
//  HeatpumpDemo
//
//  Created by Nabto on 30/01/2022.
//  Copyright © 2022 Nabto. All rights reserved.
//

import UIKit
import NabtoEdgeIamUtil
import NabtoEdgeClient

class OverviewViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var table: UITableView!
    
    var devices: [DeviceRowModel] = []

    var starting = true
    var waiting  = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        table.contentInset.top += 16
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("viewDidAppear")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if starting {
            starting = false
        }
        if let username = ProfileTools.getSavedUsername() {
            self.populateDeviceOverview()
        } else {
            self.performSegue(withIdentifier: "toProfile", sender: nil)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func startNabto() {
    }

    func populateDeviceOverview() {
        DispatchQueue.global().async {
            self.devices = []
            self.getDeviceDetailsForBookmarks()
            DispatchQueue.main.async {
                self.table.reloadData()
            }
        }
    }

    func getDeviceDetailsForBookmarks() {
        let bookmarks = BookmarkManager.shared.deviceBookmarks
        let group = DispatchGroup()
        for b in bookmarks {
            group.enter()
            DispatchQueue.global().async {
                var device = DeviceRowModel(bookmark: b)
                do {
                    let connection = try EdgeManager.shared.connect(b)
                    device.isOnline = true
                    let user = try NabtoEdgeIamUtil.IamUtil.getCurrentUser(connection: connection)
                    if let role = user.Role {
                        device.isPaired = true
                        device.role = role
                    } else {
                        device.isPaired = false
                    }
                } catch NabtoEdgeClientError.NO_CHANNELS(let localError, let remoteError) {
                    print("remoteError: \(remoteError)")
                    device.isOnline = false
                } catch IamError.USER_DOES_NOT_EXIST {
                    device.isPaired = false
                } catch {
                    print("TODO: handle error \(error)")
                }
                self.devices.append(device)
                group.leave()
            }
        }
        group.wait()
        self.waiting = false
    }

    @IBAction func refresh(_ sender: Any) {
        self.populateDeviceOverview()
    }
    
    //MARK: - Handle device selection
    
    func handleSelection(device: DeviceRowModel) {
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
                cell.statusIcon.image = UIImage(named: device.isOnline ? "checkSmall" : "alert")?.withRenderingMode(.alwaysTemplate)
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

