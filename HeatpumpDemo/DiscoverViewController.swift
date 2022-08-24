//
//  DiscoverViewController.swift
//  HeatpumpDemo
//
//  Created by Nabto on 31/01/2022.
//  Copyright © 2022 Nabto. All rights reserved.
//

import UIKit
import NabtoEdgeClient
import NabtoEdgeIamUtil
import NotificationBannerSwift

class DiscoverViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, MdnsResultReceiver {

    @IBOutlet weak var table: UITableView!

    var devices: [DeviceRowModel] = []
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

    func handleError(msg: String) {
        DispatchQueue.main.async {
            let errorBanner = GrowingNotificationBanner(title: "Discover error", subtitle: msg, style: .danger)
            errorBanner.show()
        }
    }

    func onResultReady(result: MdnsResult) {
        if (result.action == .ADD) {
            let name: String? = result.txtItems["fn"]
            let bookmark = Bookmark(deviceId: result.deviceId, productId: result.productId, name: name)
            if (!BookmarkManager.shared.exists(bookmark)) {
                addToViewIfPairingPossible(bookmark: bookmark)
            } else {
                print("Not adding device \(bookmark) to discovered device list: Device already bookmarked")
            }
        }
    }

    private func addToViewIfPairingPossible(bookmark: Bookmark) {
        do {
            let connection = try EdgeManager.shared.getConnection(bookmark)
            let modes: [NabtoEdgeIamUtil.PairingMode] = try IamUtil.getAvailablePairingModes(connection: connection)
            if (modes.count > 0 && !(modes.count == 1 && modes[0] != .PasswordInvite)) {
                try addToViewIfNotAlreadyPaired(connection: connection, bookmark: bookmark)
            } else {
                print("Not adding device \(bookmark) to discovered device list: No supported pairing modes enabled")
            }
        } catch {
            self.handleError(msg: "\(error)")
        }
    }

    private func addToViewIfNotAlreadyPaired(connection: Connection, bookmark: Bookmark) throws {
        if (!(try IamUtil.isCurrentUserPaired(connection: connection))) {
            self.devices.append(DeviceRowModel(bookmark: bookmark))
            DispatchQueue.main.async {
                self.table.reloadData()
            }
        } else {
            print("Not adding device \(bookmark) to discovered device list: Device already paired (... but not bookmarked!)")
        }
    }

    func findDevices() {
        self.devices = []
        self.waiting = true
        self.table.reloadData()
        let scanner = EdgeManager.shared.client.createMdnsScanner(subType: "heatpump")
        scanner.addMdnsResultReceiver(self)
        do {
            try scanner.start()
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
                scanner.stop()
                DispatchQueue.main.sync {
                    self.waiting  = false
                    self.table.reloadData()
                }
            }
        } catch {
            print("Could not start scan: \(error)")
        }
    }
    
    //MARK: - Handle device selection

    func handleSelection(device: DeviceRowModel) {
        self.handleUnpaired(device: device.bookmark)
    }
    
//    func handlePaired(device: Bookmark) {
//        let message = "Device is already paired"
//        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
//
//        let okAction = UIAlertAction(title: "Ok", style: .default) { action in
//            alert.dismiss(animated: true, completion: nil)
//
//            if let controller = StoryboardHelper.viewControllerFor(device: device) {
//                self.navigationController?.pushViewController(controller, animated: true)
//            }
//        }
//        alert.addAction(okAction)
//        present(alert, animated: true, completion: nil)
//
//        //add bookmark (just in case it was deleted before)
//        BookmarkManager.shared.add(bookmark: device)
//    }
    
    func handleUnpaired(device: Bookmark) {
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
        guard let device = sender as? Bookmark else { return }
        
        if let destination = segue.destination as? PairingViewController {
            destination.device = device
        } else if let destination = segue.destination as? DeviceDetailsViewController {
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
        
        handleSelection(device: self.devices[indexPath.row])
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
