//
//  EdgeThermostatViewController.swift
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

// MARK: - EdgeThermostatViewController class

class EdgeThermostatViewController: DeviceDetailsViewController, UIPickerViewDelegate, UIPickerViewDataSource {

    private let cborEncoder: CBOREncoder = CBOREncoder()

    // MARK: IBOutlet fields

    @IBOutlet weak var temperatureLabel     : UILabel!
    @IBOutlet weak var roomTemperatureLabel : UILabel!
    @IBOutlet weak var temperatureSlider    : UISlider!
    @IBOutlet weak var activeSwitch         : UISwitch!
    @IBOutlet weak var inactiveLabel         : UILabel!
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

    // MARK: Constants

    let maxTemp         = 30.0
    let minTemp         = 16.0

    // MARK: View state

    var offline         = false
    var showReconnectedMessage: Bool = false
    var refreshTimer: Timer?
    var busyTimer: Timer?
    var banner: GrowingNotificationBanner? = nil

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
            self.busyTimer?.invalidate()
            if busy {
                DispatchQueue.main.async {
                    self.busyTimer = Timer.scheduledTimer(timeInterval: 0.8, target: self, selector: #selector(self.showSpinner), userInfo: nil, repeats: false)
                }
            } else {
                self.hideSpinner()
            }
        }
    }

    enum DeviceMode: String {
        case COOL, HEAT, FAN, DRY
        static let all = [COOL, HEAT, FAN, DRY]
    }

    // MARK: - CoAP invocations

    private func coapGetThermostatInfo(connection: Connection, updateTarget: Bool) throws -> ThermostatDetails {
        let request = try connection.createCoapRequest(method: "GET", path: "/thermostat")
        let response = try request.execute()
        if (response.status == 205) {
            return try ThermostatDetails.decode(cbor: response.payload)
        } else {
            throw NabtoEdgeClientError.FAILED_WITH_DETAIL(detail: "Could not get thermostat details, device returned status \(response.status)")
        }
    }

    private func coapGetDeviceDetails(connection: Connection) throws -> DeviceDetails {
        return try IamUtil.getDeviceDetails(connection: connection)
    }

    private func coapGetUserInfo(connection: Connection) throws -> IamUser {
        return try IamUtil.getCurrentUser(connection: connection)
    }

    func coapUpdateTemperature(connection: Connection, temperature: Double) throws -> Bool {
        let cbor = try self.cborEncoder.encode(self.temperature)
        return try invokeCoapUpdate(connection: connection, path: "/thermostat/target", data: cbor)
    }

    func coapUpdatePower(connection: Connection, activated: Bool) throws -> Bool {
        let cbor = try self.cborEncoder.encode(activated)
        return try invokeCoapUpdate(connection: connection, path: "/thermostat/power", data: cbor)
    }

    func coapUpdateMode(connection: Connection, mode: DeviceMode) throws -> Bool {
        let cbor = try self.cborEncoder.encode(mode.rawValue)
        return try invokeCoapUpdate(connection: connection, path: "/thermostat/mode", data: cbor)
    }

    func invokeCoapUpdate(connection: Connection, path: String, data: Data) throws -> Bool {
        let coap = try connection.createCoapRequest(method: "POST", path: path)
        try coap.setRequestPayload(contentFormat: ContentFormat.APPLICATION_CBOR.rawValue, data: data)
        let response = try coap.execute()
        return response.status == 204
    }

    func invokeUpdateClosureAndRefreshUi(action: String, closure: @escaping (Connection) throws -> Bool) {
        self.busy = true
        DispatchQueue.global(qos: .userInitiated).async {
            defer {
                self.busy = false
            }
            var connection: Connection! = nil
            do {
                connection = try EdgeConnectionManager.shared.getConnection(self.device)
                let ok = try closure(connection)
                if (ok) {
                    self.refreshView(userInitiated: true)
                } else {
                    self.showDeviceErrorMsg("Could not \(action), device service invoked ok but it returned an error status")
                }
            } catch {
                NSLog("Error: Could not \(action): \(error)")
                self.handleDeviceError(error)
            }
        }
    }

    // MARK: - UI refresh

    private func scheduleRefresh() {
        DispatchQueue.main.async {
            self.refreshButton.isEnabled = false
            self.refreshTimer?.invalidate()
            self.refreshTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(self.refreshView), userInfo: nil, repeats: false)
        }
    }

    @objc private func refreshView(userInitiated: Bool=false) {
        if (userInitiated) {
            self.busy = true
        }
        DispatchQueue.global(qos: userInitiated ? .userInitiated : .default).async {
            defer {
                self.busy = false
            }
            do {
                let connection = try EdgeConnectionManager.shared.getConnection(self.device)
                try self.refreshThermostatInfo(connection: connection, updateTarget: userInitiated)
                self.showConnectSuccessIfNecessary()
                if (userInitiated) {
                    try self.refreshDeviceDetails(connection: connection)
                    try self.refreshUserInfo(connection: connection)
                }
                self.scheduleRefresh()
            } catch (NabtoEdgeClientError.FAILED_WITH_DETAIL(let detail)) {
                NSLog("Error when refreshing: \(detail)")
                self.disableAutoRefresh()
                if (!EdgeConnectionManager.shared.isStopped()) {
                    self.showDeviceErrorMsg(detail)
                }
            } catch {
                NSLog("Error when refreshing: \(error)")
                self.disableAutoRefresh()
                if (userInitiated) {
                    self.handleDeviceError(error)
                }
            }
        }
    }

    private func refreshThermostatInfo(connection: Connection, updateTarget: Bool) throws {
        let details = try self.coapGetThermostatInfo(connection: connection, updateTarget: updateTarget)
        DispatchQueue.main.sync {
            self.activeSwitch.isOn = details.Power
            self.updateActivateState(isActive: details.Power)
            self.mode = DeviceMode(rawValue: details.Mode)
            self.roomTemperature = details.Temperature
            if (updateTarget) {
                self.temperatureSlider.value = Float(details.Target)
                self.temperature = details.Target
            }
        }
    }

    private func refreshDeviceDetails(connection: Connection) throws {
        let details = try self.coapGetDeviceDetails(connection: connection)
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

    // MARK: - UI helpers

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

    func handleDeviceError(_ error: Error) {
        EdgeConnectionManager.shared.removeConnection(self.device)
        if let error = error as? NabtoEdgeClientError {
            handleApiError(error: error)
        } else if let error = error as? IamError {
            if case .API_ERROR(let cause) = error {
                handleApiError(error: cause)
            } else {
                NSLog("Pairing error, really? \(error)")
            }
        } else {
            self.showDeviceErrorMsg("\(error)")
        }
    }

    private func handleApiError(error: NabtoEdgeClientError) {
        switch error {
        case .NO_CHANNELS:
            self.showDeviceErrorMsg("Device offline - please make sure you and the target device both have a working network connection")
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
    }

    func showDeviceErrorMsg(_ msg: String) {
        DispatchQueue.main.async {
            self.banner?.dismiss()
            self.banner = GrowingNotificationBanner(title: "Communication Error", subtitle: msg, style: .danger)
            self.banner!.show()
            self.busy = false
        }
    }

    func pretty(_ value: Double) -> Double {
        return round(value * 10.0) / 10.0
    }

    @objc func showSpinner() {
        DispatchQueue.main.async {
            if (self.busy) {
                self.connectingView.isHidden = false
                self.spinner.startAnimating()
            }
        }
    }

    func hideSpinner() {
        DispatchQueue.main.async {
            self.connectingView.isHidden = true
            self.spinner.stopAnimating()
        }
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
        let mode = DeviceMode.all[row]
        self.invokeUpdateClosureAndRefreshUi(action: "set thermostat mode") { connection in
            return try self.coapUpdateMode(connection: connection, mode: mode)
        }
        modeField.resignFirstResponder()
    }
    
    func updateActivateState(isActive: Bool) {
        self.inactiveLabel.isHidden = isActive
        self.temperatureLabel.isHidden = !isActive
        self.roomTemperatureLabel.isHidden = !isActive
        self.temperatureSlider.isEnabled = isActive
    }

    //MARK: - IBActions

    @IBAction func sliderChanged(_ sender: UISlider) {
        self.temperature = Double(sender.value)
    }

    @IBAction func sliderReleased(_ sender: UISlider) {
        self.temperature = Double(sender.value)
        self.updateTemperature()
    }

    @IBAction func incrementTemperature(_ sender: Any) {
        guard self.temperature < maxTemp else { return }
        self.temperature += 1.0
        self.updateTemperature()
    }

    @IBAction func decrementTemperature(_ sender: Any) {
        guard temperature > minTemp else { return }
        temperature -= 1.0
        self.updateTemperature()
    }

    func updateTemperature() {
        self.invokeUpdateClosureAndRefreshUi(action: "set thermostat temperature") { connection in
            return try self.coapUpdateTemperature(connection: connection, temperature: self.temperature)
        }
    }

    @IBAction func switchChanged(_ sender: UISwitch) {
        let isOn = self.activeSwitch.isOn
        self.updateActivateState(isActive: isOn)
        self.invokeUpdateClosureAndRefreshUi(action: "set thermostat power status") { connection in
            return try self.coapUpdatePower(connection: connection, activated: isOn)
        }
    }

    @IBAction func refreshTap(_ sender: Any) {
        EdgeConnectionManager.shared.stop()
        self.refreshView(userInitiated: true)
    }

    // MARK: - View life cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        self.refreshButton.clipsToBounds  = true
        self.refreshButton.layer.cornerRadius  = 6
        self.refreshButton.imageView?.tintColor = UIColor.black
        self.hotIcon.image = hotIcon.image?.withRenderingMode(.alwaysTemplate)
        self.coldIcon.image = coldIcon.image?.withRenderingMode(.alwaysTemplate)
       
        self.temperatureSlider.minimumValue = Float(minTemp)
        self.temperatureSlider.maximumValue = Float(maxTemp)
        self.temperatureSlider.value = Float((maxTemp - minTemp) / 2.0)


        self.configurePicker()

        self.refreshView(userInitiated: true)

        self.refreshButton.setTitle("(auto-refreshing)", for: .disabled)
        self.refreshButton.setTitle("Refresh", for: .normal)
        self.scheduleRefresh()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.refreshView()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.disableAutoRefresh()
        NotificationCenter.default
                .removeObserver(self, name: NSNotification.Name(EdgeConnectionManager.eventNameConnectionClosed), object: nil)
        NotificationCenter.default
                .removeObserver(self, name: NSNotification.Name(EdgeConnectionManager.eventNameNoNetwork), object: nil)
        NotificationCenter.default
                .removeObserver(self, name: NSNotification.Name(EdgeConnectionManager.eventNameNetworkAvailable), object: nil)

    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        NotificationCenter.default
                .addObserver(self,
                        selector: #selector(connectionClosed),
                        name: NSNotification.Name (EdgeConnectionManager.eventNameConnectionClosed),
                        object: nil)
        NotificationCenter.default
                .addObserver(self,
                        selector: #selector(networkLost),
                        name: NSNotification.Name (EdgeConnectionManager.eventNameNoNetwork),
                        object: nil)
        NotificationCenter.default
                .addObserver(self,
                        selector: #selector(networkAvailable),
                        name: NSNotification.Name (EdgeConnectionManager.eventNameNetworkAvailable),
                        object: nil)
    }

    // MARK: - Reachability callbacks

    @objc func connectionClosed(_ notification: Notification) {
        if notification.object is Bookmark {
            DispatchQueue.main.async {
                self.disableAutoRefresh()
                self.showDeviceErrorMsg("Connection closed - refresh to try to reconnect")
                self.showReconnectedMessage = true
            }
        }
    }

    func disableAutoRefresh() {
        self.refreshTimer?.invalidate()
        self.refreshButton.isEnabled = true
    }

    @objc func networkLost(_ notification: Notification) {
        DispatchQueue.main.async {
            self.disableAutoRefresh()
            let banner = GrowingNotificationBanner(title: "Network connection lost", subtitle: "Please try again later", style: .warning)
            banner.show()
        }
    }

    @objc func networkAvailable(_ notification: Notification) {
        DispatchQueue.main.async {
            self.refreshView()
            let banner = GrowingNotificationBanner(title: "Network up again!", style: .success)
            banner.show()
        }
    }

}

// MARK: - ThermostatDetails struct

/*
 * Data received from device's GET /thermostat CoAP endpoint.
 */
struct ThermostatDetails: Codable, CustomStringConvertible {
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




