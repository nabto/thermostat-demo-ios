//
//  CustomTableViewCells.swift
//  HeatpumpDemo
//
//  Created by Nabto on 01/02/2022.
//  Copyright © 2022 Nabto. All rights reserved.
//

import UIKit

class DeviceRowModel {
    var bookmark: Bookmark
    var isPaired: Bool = false
    var isOnline: Bool? = nil
    var id: String {
        get {
            return "\(self.bookmark.productId).\(self.bookmark.deviceId)"
        }
    }
    init(bookmark: Bookmark) {
        self.bookmark = bookmark
    }
}

//Device cell on overview and discover screens
class DeviceCell: UITableViewCell {

    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var modelLabel: UILabel!
    @IBOutlet weak var statusIcon: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    func configure(device: DeviceRowModel) {
        nameLabel.text = device.bookmark.name ?? device.id
        modelLabel.text = device.bookmark.modelName ?? "Unknown Model"
    }
}

//Empty list warning cell - overview and discover
class NoDevicesCell: UITableViewCell {
    
    @IBOutlet weak var indicator    : UIActivityIndicatorView!
    @IBOutlet weak var messageView  : UIView!

    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    func configure(waiting: Bool) {
        messageView.isHidden = waiting
        indicator.isHidden = !waiting
        if waiting {
            indicator.startAnimating()
        } else {
            indicator.stopAnimating()
        }
    }
}

class OverviewButtonCell: UITableViewCell {
    
    @IBOutlet weak var refreshButton: UIButton!
    @IBOutlet weak var addNewButton : UIButton!

    override func awakeFromNib() {
        super.awakeFromNib()
        refreshButton.clipsToBounds = true
        addNewButton.clipsToBounds  = true
        refreshButton.layer.cornerRadius = 6
        addNewButton.layer.cornerRadius  = 6
        refreshButton.imageView?.tintColor = UIColor.black
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
}

class DiscoverButtonCell: UITableViewCell {
    
    @IBOutlet weak var refreshButton: UIButton!

    override func awakeFromNib() {
        super.awakeFromNib()
        refreshButton.clipsToBounds = true
        refreshButton.layer.cornerRadius = 6
        refreshButton.imageView?.tintColor = UIColor.white
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
}

//Cell for the user list on security settins screen
class SecurityUserCell: UITableViewCell {
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var accessLabel: UILabel!
    @IBOutlet weak var fingerprintLabel: UILabel!
    @IBOutlet weak var icon: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    func configure(user: UserInfo) {
        nameLabel.text = user.name
        fingerprintLabel.text = "RSA fingerprint: " + user.formattedFingerprint()
        accessLabel.text = user.formattedRole() + " - " + user.formattedPermissions()
        icon.image = UIImage(named: user.isOwner ? "owner" : "guest")
    }
}

//Main settings on security screen
//Implemented in a cell to avoid scrolling conflicts
class SecurityMainCell: UITableViewCell {
    
    @IBOutlet weak var remoteSwitch : UISwitch!
    @IBOutlet weak var pairingSwitch: UISwitch!
    @IBOutlet weak var newUserSwitch: UISwitch!
    @IBOutlet weak var newUserLabel : UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    func configure(/*todo*/) {
//        remoteSwitch.isOn = device.remoteAccessEnabled
//        pairingSwitch.isOn = device.openForPairing
//        newUserSwitch.isOn = device.grantGuestRemoteAccess
//        updateNewUserSwitch(device: device)
    }
    
    func updateNewUserSwitch(device: NabtoDevice) {
        let allowed = device.remoteAccessEnabled
        newUserSwitch.isEnabled = allowed
        newUserLabel.textColor = allowed ? UIColor.darkText : UIColor.lightGray
    }
}
