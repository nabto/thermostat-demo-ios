//
//  ViewController.swift
//  HeatpumpDemo
//
//  Created by Tiago Lira on 30/01/2017.
//  Copyright © 2017 Nabto. All rights reserved.
//

import UIKit

class OverviewViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var table: UITableView!
    
    var devices: [NabtoDevice] = []
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
            getBookmarkedDevices()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func startNabto() {
        NabtoManager.shared.startup { (success, error) in
            if success {
                print("startup: \(success)")
                if let username = ProfileTools.getSavedUsername() {
                    //open session with the saved profile certificate
                    NabtoManager.shared.openSessionForProfile(username: username, completion: { (success, error) in
                        print("open session: \(success)")
                        self.getBookmarkedDevices()
                    })
                } else {
                    //no saved profile, prompt user to create one
                    self.performSegue(withIdentifier: "toProfile", sender: nil)
                }
            }
        }
    }
    
    func getBookmarkedDevices() {
        devices = []
        waiting = true
        self.table.reloadData()

        let bookmarks = BookmarkManager.shared.deviceBookmarks
        guard bookmarks.count > 0 else {
            self.waiting = false
            return
        }
        NabtoManager.shared.getDevicesInfo(bookmarks: bookmarks, progress: { (device) in
            self.add(device: device)        //got reachable device!
            self.waiting = false
            self.table.reloadData()
        }, failure: { (error) in     //will be called for each undiscoverable or unreachable item
            switch error {
            case .notInLocalList(deviceID: let deviceID):
                //device not in local list. will try to connect
                if let deviceID = deviceID,
                    let bookmark = bookmarks.filter({ $0.id == deviceID }).first {
                    let offlineDevice = NabtoDevice(unreachable: deviceID, name: bookmark.name, timedOut: false)
                    self.add(device: offlineDevice)
                }
            case .timedOut(deviceID: let deviceID):
                //device is unreachable
                if let deviceID = deviceID,
                    let bookmark = bookmarks.filter({ $0.id == deviceID }).first {
                    let offlineDevice = NabtoDevice(unreachable: deviceID, name: bookmark.name, timedOut: true)
                    self.add(device: offlineDevice)
                }
            default:
                print("Undefined error")
            }
            self.waiting = false
            self.table.reloadData()
        })
    }
    
    func add(device: NabtoDevice) {
        for (i, item) in devices.enumerated() {
            if item.id == device.id {
                devices[i] = device     //replace
                return
            }
        }
        devices.append(device)  //not found in array, add
    }
    
    
    @IBAction func refresh(_ sender: Any) {
        getBookmarkedDevices()
    }
    
    //MARK: - Handle device selection
    
    func handleSelection(device: NabtoDevice) {
        if !device.reachable {
            handleOffline(device: device)
        } else if device.currentUserIsPaired {
            handlePaired(device: device)
        } else if device.openForPairing {
            handleUnpaired(device: device)
        } else {
            handleClosed(device: device)
        }
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
        if indexPath.section == 0 {
            if devices.count > 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "DeviceCell", for: indexPath) as! DeviceCell
                let device = devices[indexPath.row]
                cell.configure(device: device)
                cell.lockIcon.isHidden = true
                cell.statusIcon.image = UIImage(named: device.reachable ? "checkSmall" : "alert")?.withRenderingMode(.alwaysTemplate)
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
        guard indexPath.section == 0 && devices.count > 0 else { return }
        
        handleSelection(device: devices[indexPath.row])
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

