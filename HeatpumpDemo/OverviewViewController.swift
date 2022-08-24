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
import NotificationBannerSwift

class OverviewViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, ProfileCreatedListener {

    @IBOutlet weak var table: UITableView!

    var devices: [DeviceRowModel] = []

    var waiting  = true
    var errorBanner: GrowingNotificationBanner? = nil

    let buttonBarSpinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView()
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.hidesWhenStopped = true
        return spinner
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        table.contentInset.top += 16
        self.navigationItem.leftBarButtonItems?.append(UIBarButtonItem(customView: self.buttonBarSpinner))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if (ProfileTools.getSavedPrivateKey() != nil) {
            self.doRefresh()
        } else {
            DispatchQueue.global().async {
                self.createProfile()
                DispatchQueue.main.async {
                    self.doRefresh()
                }
            }
        }
    }

    func createProfile() {
        do {
            let key = try EdgeManager.shared.client.createPrivateKey()
            let username = UIDevice.current.name
            let simplifiedUsername = ProfileTools.convertToValidUsername(input: username)
            ProfileTools.saveProfile(username: simplifiedUsername, privateKey: key, displayName: username)
        } catch {
            let banner = NotificationBanner(title: "Error", subtitle: "Could not create private key: \(error)", style: .danger)
            banner.show()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func profileCreated() {
        self.populateDeviceOverview()
    }

    func populateDeviceOverview() {
        self.devices = []
        if (BookmarkManager.shared.deviceBookmarks.isEmpty) {
            // show big spinner in table
            self.waiting = true
        } else {
            // show spinner above table
            self.buttonBarSpinner.startAnimating()
        }
        self.addDevicesFromBookmarks()
        DispatchQueue.global().async {
            self.getDetailsForDevices()
            DispatchQueue.main.async {
                self.table.reloadData()
                self.buttonBarSpinner.stopAnimating()
                self.waiting = false
            }
        }
    }

    func addDevicesFromBookmarks() {
        let bookmarks = BookmarkManager.shared.deviceBookmarks
        self.devices = []
        for b in bookmarks {
            self.devices.append(DeviceRowModel(bookmark: b))
        }
        self.table.reloadData()
    }

    func getDetailsForDevices() {
        let group = DispatchGroup()
        for device in self.devices {
            group.enter()
            DispatchQueue.global().async {
                do {
                    try self.populateWithDetails(device)
                } catch {
                    print("An error occurred when retrieving device information for \(device.bookmark): \(error)")
                }
                DispatchQueue.main.sync {
                    self.table.reloadData()
                }
                group.leave()
            }
        }
        group.wait()
    }

    private func populateWithDetails(_ device: DeviceRowModel) throws {
        do {
            let connection = try EdgeManager.shared.getConnection(device.bookmark)
            device.isOnline = true
            let user = try NabtoEdgeIamUtil.IamUtil.getCurrentUser(connection: connection)
            if let role = user.Role {
                device.isPaired = true
                device.bookmark.role = role
            } else {
                device.isPaired = false
            }
        } catch NabtoEdgeClientError.NO_CHANNELS(_, _) {
            device.isOnline = false
        } catch IamError.USER_DOES_NOT_EXIST {
            device.isPaired = false
        } catch {
            print("Device \(device.bookmark.name) is not available due to error: \(error)")
            device.isOnline = false
        }
    }

    @IBAction func refresh(_ sender: Any) {
        self.doRefresh()
    }

    func doRefresh() {
        EdgeManager.shared.stop()
        self.errorBanner?.dismiss()
        self.devices = []
        self.table.reloadData()
        self.populateDeviceOverview()
    }
    
    //MARK: - Handle device selection
    
    func handleSelection(device: DeviceRowModel) {
        self.errorBanner?.dismiss()
        if (device.isOnline ?? false) {
            self.handleOnlineDevice(device)
        } else {
            self.handleOfflineDevice(device)
        }
    }

    private func handleOfflineDevice(_ device: DeviceRowModel) {
        // expect timeout, so indicate activity in the UI
        self.buttonBarSpinner.startAnimating()
        DispatchQueue.global().async {
            defer {
                DispatchQueue.main.sync {
                    self.buttonBarSpinner.stopAnimating()
                }
            }
            do {
                let updatedDevice = DeviceRowModel(bookmark: device.bookmark)
                try updatedDevice.populateWithDetails()
                if (device.isOnline ?? false) {
                    self.handleOnlineDevice(updatedDevice)
                } else {
                    self.handleError(msg: "Device '\(device.bookmark.name)' is offline")
                }
            } catch {
                self.handleError(msg: "\(error)")
                return
            }
        }
    }

    func handleOnlineDevice(_ device: DeviceRowModel) {
        if (device.isPaired) {
            self.handlePaired(device: device.bookmark)
        } else {
            self.handleUnpaired(device: device.bookmark)
        }
    }
    
    func handlePaired(device: Bookmark) {
        if let controller = StoryboardHelper.viewControllerFor(device: device) {
                self.navigationController?.pushViewController(controller, animated: true)
        }
    }
    
    func handleUnpaired(device: Bookmark) {
        performSegue(withIdentifier: "toPairing", sender: device)
    }

    func handleError(msg: String) {
        DispatchQueue.main.async {
            self.errorBanner = GrowingNotificationBanner(title: "Error", subtitle: msg, style: .danger)
            self.errorBanner?.show()
        }
    }

    //MARK: - UITableView methods
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if (indexPath.section == 0) {
            if (self.devices.count > 0) {
                let cell = tableView.dequeueReusableCell(withIdentifier: "DeviceCell", for: indexPath) as! DeviceCell
                let device = devices[indexPath.row]
                cell.configure(device: device)
                if (device.isOnline != nil) {
                    cell.statusIcon.isHidden = false
                    if (device.isOnline!) {
                        if (device.isPaired) {
                            cell.statusIcon.image = UIImage(named: "checkSmall")?.withRenderingMode(.alwaysTemplate)
//                            cell.statusIcon.tintColor = UIColor(named: "NabtoColor")
                            cell.statusIcon.tintColor = .systemGreen
                        } else {
                            cell.statusIcon.image = UIImage(named: "open")?.withRenderingMode(.alwaysTemplate)
//                            cell.statusIcon.tintColor = UIColor(named: "NabtoColor")
                            cell.statusIcon.tintColor = .systemGreen
                        }
                    } else {
                        cell.statusIcon.image = UIImage(named: "alert")?.withRenderingMode(.alwaysTemplate)
                        cell.statusIcon.tintColor = .systemRed
                    }
                } else {
                    cell.statusIcon.isHidden = true
                }
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
        self.handleSelection(device: self.devices[indexPath.row])
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
        if let destination = segue.destination as? ProfileCreateViewController {
            destination.profileCreatedDelegate = self
        }

        guard let device = sender as? Bookmark else { return }
        if let destination = segue.destination as? PairingViewController {
            destination.device = device
        } else if let destination = segue.destination as? DeviceDetailsViewController {
            destination.device = device
        }
    }
}

