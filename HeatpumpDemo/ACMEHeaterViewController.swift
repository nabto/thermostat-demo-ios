//
//  ACMEHeaterViewController.swift
//  HeatpumpDemo
//
//  Created by Tiago Lira on 03/02/2017.
//  Copyright © 2017 Nabto. All rights reserved.
//

import UIKit

enum DeviceMode : Int {
    case cool       = 0
    case heat       = 1
    case circulate  = 2
    case dehumidify = 3
    
    func toText() -> String {
        return String(describing: self).capitalized
    }
    
    static let all = [cool, heat, circulate, dehumidify]
}


class ACMEHeaterViewController: DeviceViewController, UIPickerViewDelegate, UIPickerViewDataSource {

    @IBOutlet weak var temperatureLabel     : UILabel!
    @IBOutlet weak var localTemperatureLabel: UILabel!
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
    
    let maxTemp         = 30
    let minTemp         = 16
    var offline         = false
    
    var roomTemperature = -1 {
        didSet { localTemperatureLabel.text = "\(roomTemperature)ºC in room" }
    }
    var temperature = -1 {
        didSet { temperatureLabel.text = "\(temperature)ºC" }
    }
    var mode : DeviceMode? {
        didSet { modeField.text = mode?.toText() ?? "-" }
    }
    
    var busy = false {
        didSet {
            UIApplication.shared.isNetworkActivityIndicatorVisible = busy
            if busy {
                perform(#selector(showSpinner), with: nil, afterDelay: 2)
            } else {
                hideSpinner()
            }
        }
    }
    
    var starting = true
    
    override func viewDidLoad() {
        super.viewDidLoad()

        refreshButton.clipsToBounds  = true
        settingsButton.clipsToBounds = true
        refreshButton.layer.cornerRadius  = 6
        settingsButton.layer.cornerRadius = 6
        refreshButton.imageView?.tintColor = UIColor.black
        settingsButton.imageView?.tintColor = UIColor.black
        hotIcon.image = hotIcon.image?.withRenderingMode(.alwaysTemplate)
        coldIcon.image = coldIcon.image?.withRenderingMode(.alwaysTemplate)
        
        temperatureSlider.minimumValue = Float(minTemp)
        temperatureSlider.maximumValue = Float(maxTemp)
        temperatureSlider.value = Float(maxTemp - minTemp) / 2.0
        
        configurePicker()
        
        refresh()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if !starting {
            refresh()
        } else {
            starting = false
        }
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //MARK:- Device
    
    @objc func refresh() {
        busy = true
        let request = "heatpump_get_full_state.json"
        NabtoManager.shared.invokeRpc(device: device.id, request: request, parameters: nil) { (result, error) in
            if let state = result {
                self.refreshState(state: state)
            } else if let error = error {
                self.handleError(error: error)
            }
            self.busy = false
        }
    }
    
    func refreshState(state: [String : Any]) {
        activeSwitch.isOn = state["activated"] as? Bool ?? false
        mode = DeviceMode(rawValue: (state["mode"] as? Int) ?? -1)
        
        if let temp = state["target_temperature"] as? Int {
            temperature = min(maxTemp, max(minTemp, temp))
            temperatureSlider.value = Float(temperature)
        }
        if let tempR = state["room_temperature"] as? Int {
            roomTemperature = tempR
        }
        
        markNotOffline()
    }
    
    func markNotOffline() {
        offline = false
        showErrorLabel(show: !(activeSwitch.isOn), message: "Device powered off")
    }
    
    func applyTemperature(temperature: Int) {
        busy = true
        let request = "heatpump_set_target_temperature.json"
        let params = ["temperature" : temperature]
        NabtoManager.shared.invokeRpc(device: device.id, request: request, parameters: params) { (result, error) in
            if let temperature = result?["temperature"] as? Int {
                self.temperature = temperature
                self.temperatureSlider.value = Float(temperature)
                self.markNotOffline()
            } else if let error = error {
                self.handleError(error: error)
            }
            self.busy = false
        }
    }
    
    func applyActivate(activated: Bool) {
        busy = true
        let request = "heatpump_set_activation_state.json"
        let params = ["activated" : Int(activated)]
        NabtoManager.shared.invokeRpc(device: device.id, request: request, parameters: params) { (result, error) in
            if let activated = result?["activated"] as? Bool {
                self.activeSwitch.setOn(activated, animated: false)
                self.markNotOffline()
            } else if let error = error {
                self.handleError(error: error)
            }
            self.busy = false
        }
    }
    
    func applyMode(mode: DeviceMode) {
        self.mode = mode
        busy = true
        let request = "heatpump_set_mode.json"
        let params = ["mode" : mode.rawValue]
        NabtoManager.shared.invokeRpc(device: device.id, request: request, parameters: params) { (result, error) in
            if let modeValue = result?["mode"] as? Int {
                self.mode = DeviceMode(rawValue: modeValue)
                self.markNotOffline()
            } else if let error = error {
                self.handleError(error: error)
            }
            self.busy = false
        }
    }
    
    func handleError(error: NabtoError) {
        print(error)
        
        switch error {
        case .timedOut(deviceID: _):
            showErrorLabel(show: true, message: "Device is offline")
            if !offline {
                offline = true
                perform(#selector(refresh), with: nil, afterDelay: 4)
            }
        case .noAccess:
            noAccessNotice()
        default:
            showErrorLabel(show: true, message: "Error invoking device")
            if !offline {
                offline = true
                perform(#selector(refresh), with: nil, afterDelay: 4)
            }
        }
    }
    
    //will be called after a small delay
    //if the app is still waiting response, will show the spinner
    @objc func showSpinner() {
        if busy {
            connectingView.isHidden = false
            spinner.startAnimating()
            //remove the status bar spinner, it's redundant
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
        }
    }
    
    func hideSpinner() {
        connectingView.isHidden = true
        spinner.stopAnimating()
    }
    
    func noAccessNotice() {
        let title = "Access denied"
        let message = "You no longer have permission to access this device. Please try pairing with it again."
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Ok", style: .default) { action in
            alert.dismiss(animated: true, completion: nil)
            _ = self.navigationController?.popToRootViewController(animated: true)
        }
        alert.addAction(okAction)
        present(alert, animated: true, completion: nil)
    }
    
    //MARK:- IBActions
    
    @IBAction func sliderChanged(_ sender: UISlider) {
        temperature = Int(sender.value)
    }
    
    @IBAction func sliderReleased(_ sender: UISlider) {
        temperature = Int(sender.value)
        applyTemperature(temperature: temperature)
    }
    
    @IBAction func incrementTemperature(_ sender: Any) {
        guard temperature < maxTemp else { return }
        temperature += 1
        applyTemperature(temperature: temperature)
    }
    
    @IBAction func decrementTemperature(_ sender: Any) {
        guard temperature > minTemp else { return }
        temperature -= 1
        applyTemperature(temperature: temperature)
    }
    
    @IBAction func switchChanged(_ sender: UISwitch) {
        applyActivate(activated: activeSwitch.isOn)
    }
    
    @IBAction func refreshTap(_ sender: Any) {
        refresh()
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
        return DeviceMode.all[row].toText()
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
        localTemperatureLabel.isHidden = show
        
    }
}

//Swift needs some help converting Bool to Int
extension Int {
    init(_ bool:Bool) {
        self = bool ? 1 : 0
    }
}
