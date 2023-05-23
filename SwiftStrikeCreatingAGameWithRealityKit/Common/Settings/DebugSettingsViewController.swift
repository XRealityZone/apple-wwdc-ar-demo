/*
See LICENSE folder for this sample’s licensing information.

Abstract:
DebugSettingsViewController
*/

import os.log
import UIKit

class DebugSettingsViewController: UITableViewController {

    let optionSetCellHeightDefault: Int = 220

    @IBAction func doneButtonAction(_ sender: UIBarButtonItem) {
        os_log(.default, log: GameLog.navigation, "DebugSettingsViewController.doneButtonAction()")
        dismiss(animated: true, completion: nil)
    }

    var settings: DebugSettings {
        return DebugSettings.shared
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return settings.numberOfSections
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return settings.prototypes(in: section)
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let title = settings.section(section).title
        return title.isEmpty ? nil : title
    }

    private func getterSetterCell<T: DebugSettingsCell>(identifier: String, cellForRowAt indexPath: IndexPath) -> T {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath) as? T else {
            return T()
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let prototype = settings.prototype(indexPath)

        let cell: DebugSettingsCell
        switch prototype.kind {
        case .slider, .sliderTunable:
            let typedCell: DebugSettingsSliderCell = getterSetterCell(identifier: "SLIDER", cellForRowAt: indexPath)
            typedCell.floatGetter = { return self.settings.floatGet(prototype.key)! }
            typedCell.floatSetter = { newValue in self.settings.set(key: prototype.key, value: newValue) }
            cell = typedCell
        case .sliderTunableInt:
            let typedCell: DebugSettingsSliderCell = getterSetterCell(identifier: "SLIDER", cellForRowAt: indexPath)
            typedCell.intGetter = { return self.settings.intGet(prototype.key)! }
            typedCell.intSetter = { newValue in self.settings.set(key: prototype.key, value: newValue) }
            cell = typedCell
        case .checkbox, .checkboxTunable:
            let typedCell: DebugSettingsCheckboxCell = getterSetterCell(identifier: "CHECKBOX", cellForRowAt: indexPath)
            typedCell.boolGetter = { return self.settings.boolGet(prototype.key)! }
            typedCell.boolSetter = { newValue in self.settings.set(key: prototype.key, value: newValue) }
            cell = typedCell
        case .action(let action):
            let typedCell: DebugSettingsActionCell = getterSetterCell(identifier: "ACTION", cellForRowAt: indexPath)
            typedCell.action = action
            cell = typedCell
        case .segue(let identifier):
            let typedCell: DebugSettingsSegueCell = getterSetterCell(identifier: "SEGUE", cellForRowAt: indexPath)
            typedCell.segue = identifier
            cell = typedCell
        case .optionSet(let config, let cellHeight):
            let typedCell: DebugSettingsOptionSetCell = getterSetterCell(identifier: "OPTIONSET", cellForRowAt: indexPath)
            typedCell.rawValueGetter = { return self.settings.rawValueGet(prototype.key)! }
            typedCell.rawValueSetter = { newValue in self.settings.set(key: prototype.key, value: newValue) }
            os_log(.default, log: GameLog.debugSettings, "cellForRowAt: OPTIONSET @%s, height %s, %s - %s - [0]=%s-%s",
                   "\(indexPath)",
                   "\(cellHeight ?? optionSetCellHeightDefault)",
                   "\(prototype.title)",
                   "\(prototype.key)",
                   "\(config.map.first?.buttonLabel ?? "<>")",
                   "\(config.map.first?.option.description ?? "<>")")
            cell = typedCell
        case .section:
            let typedCell: DebugSettingsSectionCell = getterSetterCell(identifier: "SECTION", cellForRowAt: indexPath)
            cell = typedCell
        }
        cell.release = prototype.controlWasReleased
        cell.prototype = prototype
        return cell
    }

    // Select row...
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) else { return }
        switch cell {
        case let cell as DebugSettingsActionCell:
            cell.action?()
        case let cell as DebugSettingsSegueCell:
            if let identifier = cell.segue {
                performSegue(withIdentifier: identifier, sender: nil)
            }
        default:
            return
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }

    // height for row...including all parts, label row and OptionSet row
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let prototype = settings.prototype(indexPath)
        if case .optionSet(_, let cellHeight) = prototype.kind {
            let height = cellHeight ?? optionSetCellHeightDefault
            os_log(.default, log: GameLog.debugSettings, "heightForRowAt: OPTIONSET @%s, height %s, %s",
                   "\(indexPath)",
                   "\(height)",
                   "\(prototype.title)")
            return CGFloat(height)
        }
        return super.tableView(tableView, heightForRowAt: indexPath)
    }

}

// MARK: -

class DebugSettingsCell: UITableViewCell {
    var prototype: DebugSettingPrototype?
    var release: (() -> Void)?

    override func prepareForReuse() {
        super.prepareForReuse()
        release = nil
        prototype = nil
        setSelected(false, animated: false)
    }
}

// MARK: -

class DebugSettingsSliderCell: DebugSettingsCell {
    var floatGetter: (() -> Float)?
    var floatSetter: ((Float) -> Void)?
    var intGetter: (() -> Int)?
    var intSetter: ((Int) -> Void)?
    var step: Float?

    private func setTextField(_ newValue: Float) {
        textField.text = floatSetter != nil ? String(newValue) : String(Int(newValue))
    }

    override var prototype: DebugSettingPrototype? {
        didSet {
            var floatValue = floatGetter?()
            if floatValue == nil, let intValue = intGetter?() {
                floatValue = Float(intValue)
            }
            guard let prototype = prototype, let value = floatValue else {
                return
            }
            titleLabel.text = prototype.title
            setTextField(value)
            switch prototype.kind {
            case let .slider(minValue, maxValue, step?):
                slider.minimumValue = minValue ?? 0
                slider.maximumValue = maxValue ?? 200
                self.step = step
            case let .sliderTunable(tunableFloat):
                slider.minimumValue = tunableFloat.minimum
                slider.maximumValue = tunableFloat.maximum
                self.step = tunableFloat.step
            case let .sliderTunableInt(tunableInt):
                slider.minimumValue = Float(tunableInt.minimum)
                slider.maximumValue = Float(tunableInt.maximum)
                self.step = Float(tunableInt.step ?? 1)
            default: break
            }
            slider.value = value
        }
    }

    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var textField: UITextField!
    @IBOutlet var slider: UISlider!

    @IBAction func textFieldDidChange(_ sender: UITextField) {
        guard let textValue = textField.text, var newValue = Float(textValue) else {
            return
        }
        if newValue < slider.minimumValue {
            newValue = slider.minimumValue
            setTextField(newValue)
        } else if newValue > slider.maximumValue {
            newValue = slider.maximumValue
            setTextField(newValue)
        } else if let stepValue = step {
            newValue = round(newValue / stepValue) * stepValue
            setTextField(newValue)
        }
        floatSetter?(newValue)
        intSetter?(Int(newValue))
        slider.value = newValue
    }
    
    @IBAction func sliderDidChange(_ sender: UISlider) {
        var newValue = sender.value
        if let stepValue = step {
            newValue = round(newValue / stepValue) * stepValue
            sender.value = newValue
        }
        floatSetter?(newValue)
        intSetter?(Int(newValue))
        setTextField(newValue)
    }

    @IBAction func sliderDidRelease(_ sender: UISlider) {
        release?()
    }
}

// MARK: -

class DebugSettingsCheckboxCell: DebugSettingsCell {
    var boolGetter: (() -> Bool)?
    var boolSetter: ((Bool) -> Void)?

    override var prototype: DebugSettingPrototype? {
        didSet {
            guard let prototype = prototype, let value = boolGetter?() else {
                return
            }
            titleLabel.text = prototype.title
            checkbox.isOn = value
        }
    }
    
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var checkbox: UISwitch!
    
    @IBAction func checkboxDidChange(_ sender: UISwitch) {
        boolSetter?(checkbox.isOn)
    }
}

class DebugSettingsOptionSetCell: DebugSettingsCell {
    var rawValueGetter: (() -> OptionSetControl.RawValue)?
    var rawValueSetter: ((OptionSetControl.RawValue) -> Void)?

    override var prototype: DebugSettingPrototype? {
        didSet {
            guard let prototype = prototype, let currentValue = rawValueGetter?() else {
                return
            }
            titleLabel.text = prototype.title
            if case .optionSet(var config, _) = prototype.kind {
                config.initialOptions = currentValue
                optionSetControl.setupView(config)
            }
        }
    }

    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var optionSetControl: OptionSetControl!

    @IBAction func optionsChanged(_ sender: OptionSetControl) {
        rawValueSetter?(sender.optionsRawValue)
    }

}

// MARK: -

class DebugSettingsActionCell: DebugSettingsCell {
    var action: (() -> Void)?

    override var prototype: DebugSettingPrototype? {
        didSet {
            guard let prototype = prototype else {
                return
            }
            titleLabel?.text = prototype.title
        }
    }

    @IBOutlet var titleLabel: UILabel!
}

class DebugSettingsSegueCell: DebugSettingsCell {
    var segue: String?

    override var prototype: DebugSettingPrototype? {
        didSet {
            guard let prototype = prototype else {
                return
            }
            titleLabel?.text = prototype.title
        }
    }

    @IBOutlet var titleLabel: UILabel!
}

class DebugSettingsSectionCell: DebugSettingsCell {
    override var prototype: DebugSettingPrototype? {
        didSet {
            guard let prototype = prototype else {
                return
            }
            titleLabel?.text = prototype.title
        }
    }

    @IBOutlet var titleLabel: UILabel!
}

