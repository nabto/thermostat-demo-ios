//
//  SecuritySettingsViewController.swift
//  HeatpumpDemo
//
//  Created by Nabto on 31/01/2022.
//  Copyright © 2022 Nabto. All rights reserved.
//

import UIKit

class SecuritySettingsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    var device : NabtoDevice!
    var users  : [UserInfo] = []
    
    @IBOutlet weak var table: UITableView!
    
    var mainCell: SecurityMainCell? {
        return table.cellForRow(at: IndexPath(row: 0, section: 0)) as? SecurityMainCell
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        table.rowHeight = UITableView.automaticDimension
        table.contentInset.bottom = 32
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        readUsers()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    //MARK: - IBActions
    
    @IBAction func goToHome(_ sender: Any) {
        _ = navigationController?.popToRootViewController(animated: true)
    }
    
    @IBAction func remoteValueChanged(_ sender: UISwitch) {
        device.remoteAccessEnabled = sender.isOn
        NabtoManager.shared.updateSecuritySettings(device: device) { (success, device, error) in
        }
        mainCell?.updateNewUserSwitch(device: device)
    }
    
    @IBAction func pairingValueChanged(_ sender: UISwitch) {
        device.openForPairing = sender.isOn
        NabtoManager.shared.updateSecuritySettings(device: device) { (success, device, error) in
        }
    }
    
    @IBAction func newUserValueChanged(_ sender: UISwitch) {
        device.grantGuestRemoteAccess = sender.isOn
        NabtoManager.shared.updateSecuritySettings(device: device) { (success, device, error) in
        }
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destination = segue.destination as? EditUserViewController,
            let user = sender as? UserInfo {
            destination.device = device
            destination.user = user
        }
    }
    
    //MARK: - Retrieving users info
    
    func readUsers() {
        NabtoManager.shared.getUsers(device: device) { (success, users, error) in
            if success,
                let users = users {
                self.users = users
                self.table.reloadData()
            } else {
                print("failed to get user list")
            }
        }
    }
    
    //MARK: - UITableView methods
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SecurityMainCell", for: indexPath) as! SecurityMainCell
            cell.configure(device: device)
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SecurityUserCell", for: indexPath) as! SecurityUserCell
            cell.configure(user: users[indexPath.row])
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section == 1 else { return }
        performSegue(withIdentifier: "toEditUser", sender: users[indexPath.row])
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? 1 : users.count
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return indexPath.section == 0 ? 660 : 98
    }

}
