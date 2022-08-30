//
//  ACMEHeaterViewController.swift
//  ThermostatDemo
//
//  Created by Nabto on 03/02/2022.
//  Copyright © 2022 Nabto. All rights reserved.
//

import UIKit
import NotificationBannerSwift
import CBORCoding
import NabtoEdgeClient
import NabtoEdgeIamUtil

enum DeviceMode: String {
    case COOL, HEAT, FAN, DRY
    static let all = [COOL, HEAT, FAN, DRY]
}

public struct ThermostatDetails: Codable, CustomStringConvertible {
    public let Mode: String
    public let Target: Double
    public let Power: Bool
    public let Temperature: Double

    public init(Mode: String, Target: Double, Power: Bool, Temperature: Double) {
        self.Mode = Mode
        self.Target = Target
        self.Power = Power
        self.Temperature = Temperature
    }

    public static func decode(cbor: Data) throws -> ThermostatDetails {
        let decoder = CBORDecoder()
        do {
            return try decoder.decode(ThermostatDetails.self, from: cbor)
        } catch {
            NSLog("Error when decoding response: \(error)")
            throw NabtoEdgeClientError.FAILED_WITH_DETAIL(detail: "Could not decode thermostat response: \(error)")
        }
    }

    public var description: String {
        "ThermostatDetails(Mode: \(Mode), Target: \(Target), Power: \(Power), Temperature: \(Temperature))"
    }
}


class ACMEHeaterViewController: DeviceDetailsViewController, UIPickerViewDelegate, UIPickerViewDataSource {

    @IBOutlet weak var temperatureLabel     : UILabel!
    @IBOutlet weak var roomTemperatureLabel: UILabel!
    @IBOutlet weak var temperatureSlider    : UISlider!
    @IBOutlet weak var activeSwitch         : UISwitch!
    @IBOutlet weak var errorLabel           : UILabel!
    @IBOutlet weak var modeField            : UITextField!
    @IBOutlet weak var coldIcon             : UIImageView!
    @IBOutlet weak var hotIcon              : UIImageView!
    @IBOutlet weak var refreshButton        : UIButton!
    @IBOutlet weak var settingsButton       : UIButton!
    @IBOutlet weak var connectingView       : UIView!
    @IBOutlet weak var spinner              : UIActivityIndicatorView!
    
    @IBOutlet weak var deviceIdLabel         : UILabel!
    @IBOutlet weak var appNameAndVersionLabel: UILabel!
    @IBOutlet weak var usernameLabel         : UILabel!
    @IBOutlet weak var displayNameLabel      : UILabel!
    @IBOutlet weak var roleLabel             : UILabel!
    
    let maxTemp         = 30.0
    let minTemp         = 16.0
    var offline         = false

    var roomTemperature = -1.0 {
        didSet { roomTemperatureLabel.text = "\(pretty(roomTemperature))ºC in room" }
    }
    var temperature = -1.0 {
        didSet { temperatureLabel.text = "\(pretty(temperature))ºC" }
    }
    var mode : DeviceMode? {
        didSet { modeField.text = mode?.rawValue }
    }
    
    var busy = false {
        didSet {
            print("*** busy set: \(busy)")
            if busy {
                print("    *** performing selector: \(busy)")
                perform(#selector(showSpinner), with: nil, afterDelay: 800)
            } else {
                hideSpinner()
            }
        }
    }

    var showReconnectedMessage: Bool = false
    var refreshTimer: Timer?
    var banner: GrowingNotificationBanner? = nil
    var starting = true
    
    override func viewDidLoad() {
        super.viewDidLoad()

        refreshButton.clipsToBounds  = true
        refreshButton.layer.cornerRadius  = 6
        refreshButton.imageView?.tintColor = UIColor.black
        hotIcon.image = hotIcon.image?.withRenderingMode(.alwaysTemplate)
        coldIcon.image = coldIcon.image?.withRenderingMode(.alwaysTemplate)
        
        temperatureSlider.minimumValue = Float(minTemp)
        temperatureSlider.maximumValue = Float(maxTemp)
        temperatureSlider.value = Float((maxTemp - minTemp) / 2.0)

        NotificationCenter.default
                .addObserver(self,
                        selector: #selector(connectionClosed),
                        name: NSNotification.Name (EdgeManager.connectionClosedEventName),
                        object: nil)

        configurePicker()
        
        refresh(updateTarget: true)
        self.scheduleRefresh()
    }

    deinit {
        NotificationCenter.default
                .removeObserver(self, name: NSNotification.Name(EdgeManager.connectionClosedEventName), object: nil)
    }

    @objc func connectionClosed(_ notification: Notification) {
        if let bookmark = notification.object as? Bookmark {
            DispatchQueue.main.async {
                self.refreshTimer?.invalidate()
                self.showDeviceErrorMsg("Connection closed - refresh to try to reconnect")
                self.showReconnectedMessage = true
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !starting {
            refresh()
        } else {
            starting = false
        }
    }

    func scheduleRefresh() {
        DispatchQueue.main.async {
//            self.refreshTimer?.invalidate()
//            self.refreshTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(self.refresh), userInfo: nil, repeats: false)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.refreshTimer?.invalidate()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //MARK:- Device

    func handleDeviceError(_ error: Error) {
        EdgeManager.shared.removeConnection(self.device)
        if let error = error as? NabtoEdgeClientError {
            switch error {
            case .NO_CHANNELS:
                self.showDeviceErrorMsg("Device offline - please make sure you and the target device both have a work working network connection")
                break
            case .TIMEOUT:
                self.showDeviceErrorMsg("The operation timed out - was the connection lost?")
                break
            case .STOPPED:
                // ignore - connection/client will be restarted at next connect attempt
                break
            default:
                self.showDeviceErrorMsg("An error occurred: \(error)")
            }
        } else if let error = error as? IamError {
            self.showDeviceErrorMsg("Pairing error - did the administrator remove your access to the device?")
        } else {
            self.showDeviceErrorMsg("\(error)")
        }
    }

    func showDeviceErrorMsg(_ msg: String) {
        DispatchQueue.main.async {
            self.banner?.dismiss()
            self.banner = GrowingNotificationBanner(title: "Communication Error", subtitle: msg, style: .danger)
            self.banner!.show()
            self.busy = false
        }
    }

    @objc func refresh(updateTarget: Bool=false) {
        self.busy = true
        DispatchQueue.global().async {
            var errorMessage: String?
            defer {
                self.busy = false
            }
            do {
                let connection = try EdgeManager.shared.getConnection(self.device)
                try self.refreshThermostatInfo(connection: connection, updateTarget: updateTarget)
                try self.refreshDeviceDetails(connection: connection)
                try self.refreshUserInfo(connection: connection)
                self.showConnectSuccessIfNecessary()
                self.scheduleRefresh()
            } catch (NabtoEdgeClientError.FAILED_WITH_DETAIL(let detail)) {
                NSLog("Error when refreshing: \(detail)")
                self.refreshTimer?.invalidate()
                if (!EdgeManager.shared.isStopped()) {
                    self.showDeviceErrorMsg(detail)
                }
            } catch {
                NSLog("Error when refreshing: \(error)")
                self.refreshTimer?.invalidate()
                if (updateTarget) {
                    self.handleDeviceError(error)
                }
            }
        }
    }

    private func showConnectSuccessIfNecessary() {
        if (self.showReconnectedMessage) {
            DispatchQueue.main.async {
                self.banner?.dismiss()
                self.banner = GrowingNotificationBanner(title: "Connected", subtitle: "Connection re-established!", style: .success)
                self.banner!.show()
                self.showReconnectedMessage = false
            }
        }
    }

    func pretty(_ value: Double) -> Double {
        return round(value * 10.0) / 10.0
    }

    private func refreshThermostatInfo(connection: Connection, updateTarget: Bool) throws {
        let request = try connection.createCoapRequest(method: "GET", path: "/thermostat")
        let response = try request.execute()
        if (response.status == 205) {
            let details = try ThermostatDetails.decode(cbor: response.payload)
            DispatchQueue.main.sync {
                self.refreshThermostatState(details, updateTarget: updateTarget)
            }
        } else {
            throw NabtoEdgeClientError.FAILED_WITH_DETAIL(detail: "Could not get thermostat details, device returned status \(response.status)")
        }
    }

    private func refreshDeviceDetails(connection: Connection) throws {
        let details = try IamUtil.getDeviceDetails(connection: connection)
        DispatchQueue.main.sync {
            self.deviceIdLabel.text = "\(details.ProductId).\(details.DeviceId)"
            self.appNameAndVersionLabel.text = "\(details.AppName ?? "n/a") (\(details.AppVersion ?? "n/a"))"
        }
    }

    private func refreshUserInfo(connection: Connection) throws {
        let user = try IamUtil.getCurrentUser(connection: connection)
        DispatchQueue.main.sync {
            self.usernameLabel.text = user.Username
            self.displayNameLabel.text = user.DisplayName ?? "n/a"
            self.roleLabel.text = user.Role ?? "n/a"
        }
    }

    func refreshThermostatState(_ details: ThermostatDetails, updateTarget: Bool) {
        self.activeSwitch.isOn = details.Power
        self.mode = DeviceMode(rawValue: details.Mode)
        self.roomTemperature = details.Temperature
        if (updateTarget) {
            self.temperatureSlider.value = Float(details.Target)
            self.temperature = details.Target
        }
        markNotOffline()
    }
    
    func markNotOffline() {
        offline = false
        showErrorLabel(show: !(activeSwitch.isOn), message: "Device powered off")
    }

    func applyTemperature(temperature: Double) {
        self.busy = true
        DispatchQueue.global().async {
            defer {
                DispatchQueue.main.sync {
                    self.busy = false
                }
            }
            var connection: Connection! = nil
            do {
                connection = try EdgeManager.shared.getConnection(self.device)
                let coap: CoapRequest = try connection.createCoapRequest(method: "POST", path: "/thermostat/target")
                let encoder = CBOREncoder()
                let cbor = try encoder.encode(self.temperature)
                try coap.setRequestPayload(contentFormat: ContentFormat.APPLICATION_CBOR.rawValue, data: cbor)
                let response = try coap.execute()
                if (response.status == 204) {
                    self.refresh()
                } else {
                    self.showDeviceErrorMsg("Could not set thermostat temperature, device returned status \(response.status)")
                }
            } catch {
                NSLog("Error when applying temperature: \(error)")
                self.handleDeviceError(error)
            }
        }
    }
    
    func applyActivate(activated: Bool) {
        self.busy = true
        DispatchQueue.global().async {
            defer {
                DispatchQueue.main.sync {
                    self.busy = false
                }
            }
            do {
                let connection = try EdgeManager.shared.getConnection(self.device)
                let coap = try connection.createCoapRequest(method: "POST", path: "/thermostat/power")
                let encoder = CBOREncoder()
                let cbor = try encoder.encode(activated)
                try coap.setRequestPayload(contentFormat: ContentFormat.APPLICATION_CBOR.rawValue, data: cbor)
                let response = try coap.execute()
                if (response.status == 204) {
                    self.refresh()
                } else {
                    self.showDeviceErrorMsg("Could not set thermostat power status, device returned status \(response.status)")
                }
            } catch {
                NSLog("Error when activating: \(error)")
                self.handleDeviceError(error)
            }
        }
    }
    
    func applyMode(mode: DeviceMode) {
        self.mode = mode
        self.busy = true
        DispatchQueue.global().async {
            defer {
                DispatchQueue.main.sync {
                    self.busy = false
                }
            }
            do {
                let connection = try EdgeManager.shared.getConnection(self.device)
                let coap = try connection.createCoapRequest(method: "POST", path: "/thermostat/mode")
                let encoder = CBOREncoder()
                let cbor = try encoder.encode(mode.rawValue)
                try coap.setRequestPayload(contentFormat: ContentFormat.APPLICATION_CBOR.rawValue, data: cbor)
                let response = try coap.execute()
                if (response.status == 204) {
                    self.refresh()
                } else {
                    self.showDeviceErrorMsg("Could not set thermostat mode, device returned status \(response.status)")
                }
            } catch {
                NSLog("Error when setting mode: \(error)")
                self.handleDeviceError(error)
            }
        }
    }

    //will be called after a small delay
    //if the app is still waiting response, will show the spinner
    @objc func showSpinner() {
        print(" *** showing spinner")
        DispatchQueue.main.async {
            if (self.busy) {
                self.connectingView.isHidden = false
                self.spinner.startAnimating()
            }
        }
    }
    
    func hideSpinner() {
        print(" *** hiding spinner")
        DispatchQueue.main.async {
            self.connectingView.isHidden = true
            self.spinner.stopAnimating()
        }
    }

    //MARK:- IBActions
    
    @IBAction func sliderChanged(_ sender: UISlider) {
        temperature = Double(sender.value)
    }
    
    @IBAction func sliderReleased(_ sender: UISlider) {
        temperature = Double(sender.value)
        applyTemperature(temperature: temperature)
    }
    
    @IBAction func incrementTemperature(_ sender: Any) {
        guard temperature < maxTemp else { return }
        temperature += 1.0
        applyTemperature(temperature: temperature)
    }
    
    @IBAction func decrementTemperature(_ sender: Any) {
        guard temperature > minTemp else { return }
        temperature -= 1.0
        applyTemperature(temperature: temperature)
    }
    
    @IBAction func switchChanged(_ sender: UISwitch) {
        applyActivate(activated: activeSwitch.isOn)
    }
    
    @IBAction func refreshTap(_ sender: Any) {
        EdgeManager.shared.stop()
        self.refresh(updateTarget: true)
        self.scheduleRefresh()
    }

    //MARK: - PickerView

    func configurePicker() {
        let picker = UIPickerView()
        picker.delegate = self
        modeField.inputView = picker
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return DeviceMode.all.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return DeviceMode.all[row].rawValue
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let selected = DeviceMode.all[row]
        applyMode(mode: selected)
        modeField.resignFirstResponder()
    }
    
    func showErrorLabel(show: Bool, message: String) {
        errorLabel.text = message
        errorLabel.isHidden = !show
        temperatureLabel.isHidden = show
        roomTemperatureLabel.isHidden = show
        
    }
}

//Swift needs some help converting Bool to Int
extension Int {
    init(_ bool:Bool) {
        self = bool ? 1 : 0
    }
}
