/*
See LICENSE folder for this sample’s licensing information.

Abstract:
View controller for development & debugging settings.
*/

import ARKit
import os.log
import RealityKit
import UIKit

class DeveloperSettingsTableViewController: UITableViewController {

    // Section 0 - UI Settings
    @IBOutlet var disableInGameUISwitch: UISwitch!

    // Section 1 - world map sharing
    @IBOutlet var worldMapCell: UITableViewCell!
    @IBOutlet var collaborativeMappingCell: UITableViewCell!
    @IBOutlet var manualCell: UITableViewCell!

    @IBOutlet weak var floorDecalDiameterLabel: UILabel!
    @IBOutlet weak var floorDecalDiameterText: UITextField!
    @IBOutlet weak var floorDecalDiameterSlider: UISlider!

    var uiSwitches = [UISwitch]()

    @IBOutlet weak var frameworkDescriptionLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        // happens here so the switches have been loaded from the storyboard
        uiSwitches = []
        configureUISwitches()
        configureBoardLocationCells()
        configureFloorDecalDiameter()
        configureFrameworkDescription()
   }

    private func configureUISwitches() {
        disableInGameUISwitch.isOn = UserSettings.disableInGameUI

        for uiSwitch in uiSwitches {
            uiSwitch.isEnabled = !UserSettings.disableInGameUI
        }
    }

    private func configureBoardLocationCells() {
        let boardLocationMode = UserSettings.boardLocatingMode
        worldMapCell.accessoryType = (boardLocationMode == .worldMap) ? .checkmark : .none
        collaborativeMappingCell.accessoryType = (boardLocationMode == .collaborative) ? .checkmark : .none
        manualCell.accessoryType = (boardLocationMode == .manual) ? .checkmark : .none
    }

    private func configureFloorDecalDiameter() {
        floorDecalDiameterText.text = "\(UserSettings.floorDecalDiameter)"
        floorDecalDiameterSlider.value = UserSettings.floorDecalDiameter
    }

    private func bundleDetails(_ bundle: Bundle) -> String {
        var bundleInfo = "\(bundle.bundlePath)"
        if let infoDictionary = bundle.infoDictionary {
            if let bundleName = infoDictionary["CFBundleName"] as? String,
            let build = infoDictionary["CFBundleVersion"] as? String {
                bundleInfo = "\(bundleName)-\(build)"
                os_log(.default, log: GameLog.debugSettings, "%@", "\(bundleInfo)")
            }
        }
        return bundleInfo
    }

    private func dependentBundlesDetails() -> [String] {
        var bundlesInfo = [String]()
        let bundleIdentifiers = [
            "com.apple.AppleDepth",
            "com.apple.ARKit",
            "com.apple.combine",    // Combine
            "com.apple.RealityKit" // RealityKit Swift interface
        ]

        bundleIdentifiers.forEach { identifier in
            if let bundle = Bundle(identifier: identifier) {
                bundlesInfo.append(bundleDetails(bundle))
            }
        }

        return bundlesInfo
    }

    private func configureFrameworkDescription() {
        let lines = "Build SDKs:\n    \(BuildInfo.details.joined(separator: "\n    "))"
                  + "\nRun-time Frameworks:\n    \(dependentBundlesDetails().joined(separator: "\n    "))"
        let font: UIFont = .monospacedSystemFont(ofSize: 14.0, weight: .medium)
        let fontColor = UIColor { (UITraitCollection: UITraitCollection) -> UIColor in
            if UITraitCollection.userInterfaceStyle == .dark {
                return UIColor.white
            } else {
                return UIColor.black
            }
        }
        let attributes: [NSAttributedString.Key: Any] = [.font: font,
                                                         .foregroundColor: fontColor]
        let attributedText = NSAttributedString(string: lines, attributes: attributes)
        frameworkDescriptionLabel.attributedText = attributedText
    }

    // Developer Settings:  UI Settings
    @IBAction func disableInGameUIChanged(_ sender: UISwitch) {
        UserSettings.disableInGameUI = sender.isOn
        if sender.isOn {
            // also turn off everything else
            UserSettings.showARMappingState = false
            UserSettings.arDebugOptions = 0
            UserSettings.showTrackingState = false
        }
        configureUISwitches()
    }

    @IBAction func floorDecalDiameterSliderAction(_ sender: UISlider) {
        let newValue = sender.value
        floorDecalDiameterText.text = "\(newValue)"
        UserSettings.floorDecalDiameter = newValue
    }

    // MARK: - table delegate for select row

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let cell = tableView.cellForRow(at: indexPath) else { return }
        switch cell {
        case worldMapCell:
            UserSettings.boardLocatingMode = .worldMap
        case collaborativeMappingCell:
            UserSettings.boardLocatingMode = .collaborative
        case manualCell:
            UserSettings.boardLocatingMode = .manual
        default:
            break
        }
        configureBoardLocationCells()
    }

}

extension DeveloperSettingsTableViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
        switch textField {
        case floorDecalDiameterText:
            floorDecalDiameterDidEndEditing(reason: reason)
        default:
            break
        }
    }

    private func floorDecalDiameterDidEndEditing(reason: UITextField.DidEndEditingReason) {
        if let text = floorDecalDiameterText.text, let newValue = Float(text) {
            UserSettings.floorDecalDiameter = newValue.clamped(lowerBound: floorDecalDiameterSlider.minimumValue,
                                                              upperBound: floorDecalDiameterSlider.maximumValue)
            floorDecalDiameterText.text = "\(UserSettings.floorDecalDiameter)"
            floorDecalDiameterSlider.value = UserSettings.floorDecalDiameter
            floorDecalDiameterText.textColor = .black
        } else {
            floorDecalDiameterText.textColor = .red
        }
    }
}
