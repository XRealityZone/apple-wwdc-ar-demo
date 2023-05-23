/*
See LICENSE folder for this sample’s licensing information.

Abstract:
View controller for user settings.
*/

import UIKit

class GameSettingsTableViewController: UITableViewController {
    @IBOutlet var enableMatchDurationSwitch: UISwitch!
    @IBOutlet var matchDurationTextField: UITextField!
    @IBOutlet var matchDurationSlider: UISlider!

    @IBOutlet weak var musicVolumeSlider: UISlider!

    var effectsLevelReleased: ButtonBeep!

    override func viewDidLoad() {
        super.viewDidLoad()

        enableMatchDurationSwitch.isOn = UserSettings.enableMatchDuration
        matchDurationSlider.value = Float(UserSettings.matchDuration)
        matchDurationTextField.text = "\(UserSettings.matchDuration)"
        musicVolumeSlider.value = UserSettings.musicVolume
    }

    @IBAction func enableMatchDurationChanged(_ sender: UISwitch) {
        UserSettings.enableMatchDuration = sender.isOn
    }

    @IBAction func matchDurationChanged(_ sender: UISlider) {
        UserSettings.matchDuration = Int(sender.value)
        matchDurationTextField.text = "\(UserSettings.matchDuration)"
        matchDurationTextField.textColor = .black
    }

    @IBAction func musicVolumeChanged(_ sender: UISlider) {
        UserSettings.musicVolume = sender.value
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        navigationController?.popViewController(animated: true)
    }
}

extension GameSettingsTableViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
        switch textField {
        case matchDurationTextField:
            matchDurationDidEndEditing(reason: reason)
        default:
            break
        }
    }

    private func matchDurationDidEndEditing(reason: UITextField.DidEndEditingReason) {
        if let text = matchDurationTextField.text, let newValue = Float(text) {
            UserSettings.matchDuration = Int(newValue.clamped(lowerBound: matchDurationSlider.minimumValue,
                                                              upperBound: matchDurationSlider.maximumValue))
            matchDurationTextField.text = "\(UserSettings.matchDuration)"
            matchDurationSlider.value = Float(UserSettings.matchDuration)
            matchDurationTextField.textColor = .black
        } else {
            matchDurationTextField.textColor = .red
        }
    }

}
