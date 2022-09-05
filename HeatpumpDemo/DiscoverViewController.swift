//
//  DiscoverViewController.swift
//  ThermostatDemo
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
    var busy = true
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
        self.devices = []
        self.busy = true
        self.table.reloadData()
        let scanner = EdgeConnectionManager.shared.client.createMdnsScanner(subType: "thermostat")
        scanner.addMdnsResultReceiver(self)
        do {
            try scanner.start()
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
                scanner.stop()
                DispatchQueue.main.async {
                    self.busy  = false
                    self.table.reloadData()
                }
            }
        } catch {
            print("Could not start scan: \(error)")
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
            let connection = try EdgeConnectionManager.shared.getConnection(bookmark)
            let modes: [NabtoEdgeIamUtil.PairingMode] = try IamUtil.getAvailablePairingModes(connection: connection)
            if (modes.count > 0 && !(modes.count == 1 && modes[0] != .PasswordInvite)) {
                self.devices.append(DeviceRowModel(bookmark: bookmark))
                DispatchQueue.main.async {
                    self.table.reloadData()
                }
            } else {
                print("Not adding device \(bookmark) to discovered device list: No supported pairing modes enabled")
            }
        } catch (NabtoEdgeIamUtil.IamError.IAM_NOT_SUPPORTED) {
            // silently ignore
            NSLog("Nabto Edge device discovered that do not support IAM: \(bookmark.productId).\(bookmark.deviceId)")
        } catch {
            self.handleError(msg: "\(error)")
        }
    }

    func handleError(msg: String) {
        DispatchQueue.global().async() {
            EdgeConnectionManager.shared.stop()
        }
        DispatchQueue.main.async {
            NSLog("Discover error: \(msg)")
            let errorBanner = GrowingNotificationBanner(title: "Discover error", subtitle: msg, style: .danger)
            errorBanner.show()

        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let device = sender as? Bookmark else { return }
        
        if let destination = segue.destination as? PairingViewController {
            destination.device = device
        } else if let destination = segue.destination as? DeviceDetailsViewController {
            destination.device = device
        }
    }
    
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
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "NoDevicesCell", for: indexPath) as! NoDevicesCell
                cell.configure(waiting: busy)
                return cell
            }
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "DiscoverButtonCell", for: indexPath) as! DiscoverButtonCell
            cell.refreshButton.isEnabled = !self.busy
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section == 0 && devices.count > 0 else { return }
        performSegue(withIdentifier: "toPairing", sender: self.devices[indexPath.row].bookmark)
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
