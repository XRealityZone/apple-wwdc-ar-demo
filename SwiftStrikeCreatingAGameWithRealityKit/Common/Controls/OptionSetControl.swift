/*
See LICENSE folder for this sample’s licensing information.

Abstract:
OptionSetContol - generic control for OptionSet conforming classes.  The
 control uses a UIStackView to manage a set of UIStackViews each of which
 has a column of buttons that represent each value in the given map of
 button label to OptionSet rawValue.  The number of buttons in each column
 can be configured, and an extra column for ALL and NONE buttons is added.
 The buttons are evenly spaced in the UIStackView and the UIStackView
 columns are evenly spaced in a UIStackView which fills the parent frame.
 Most of the appearance characteristics are controllable through publc
 members: view background color, selected button text color, unselected
 button text color, # of buttons per column, etc.

 // Setup
 place a UIControl in a UIView and assign OptionSetControl as the class
 hook the IBOutlet to the control variable in your class
 hook the control valueChanged to your IBAction for value changed in your class
 create your options map with label -> rawvalue
 let optionsMap = [ OptionSetMapEntry("My First Option", .myFirstOption) ]
 optionSetControl.setupView(options: yourOptionSet.rawValue, map: optionsMap)

 // while instanced, optionsRawValue property can be used to get
 // the current options RawValue
 myCurrentOptions = optionsRawValue
*/

import os.log
import UIKit

class OptionSetControl: UIControl {
    typealias RawValue = Int

    // an generic OptionSet comformer to use when
    // converting the owner's OptionSet conformer values
    private struct Options: OptionSet {
        var rawValue: RawValue
        init(rawValue: RawValue) {
            self.rawValue = rawValue
        }
    }

    struct MapEntry {
        init(_ label: String, _ option: RawValue) {
            buttonLabel = label
            self.option = option
        }
        let buttonLabel: String
        let option: RawValue
    }

    typealias Map = [MapEntry]

    // MARK: - Configuarion settings for view

    struct Config {
        var initialOptions: RawValue = 0
        var map = Map()
        var viewBackgroundColor = UIColor.white
        var unselectedTextColor = UIColor.blue
        var unselectedBackgroundColor = UIColor.white
        var selectedTextColor = UIColor.cyan
        var selectedBackgroundColor = UIColor.blue
        var buttonsPerColumn: Int = 5

        init() {}

        init(options: RawValue, map: Map,
             viewBackgroundColor: UIColor? = UIColor.white,
             unselectedTextColor: UIColor? = UIColor.blue,
             unselectedBackgroundColor: UIColor? = UIColor.white,
             selectedTextColor: UIColor? = UIColor.cyan,
             selectedBackgroundColor: UIColor? = UIColor.blue,
             buttonsPerColumn: Int? = 5
        ) {
            self.initialOptions = options
            self.map = map
            if let viewBackgroundColor = viewBackgroundColor {
                self.viewBackgroundColor = viewBackgroundColor
            }
            if let unselectedTextColor = unselectedTextColor {
                self.unselectedTextColor = unselectedTextColor
            }
            if let unselectedBackgroundColor = unselectedBackgroundColor {
                self.unselectedBackgroundColor = unselectedBackgroundColor
            }
            if let selectedTextColor = selectedTextColor {
                self.selectedTextColor = selectedTextColor
            }
            if let selectedBackgroundColor = selectedBackgroundColor {
                self.selectedBackgroundColor = selectedBackgroundColor
            }
            if let buttonsPerColumn = buttonsPerColumn {
                self.buttonsPerColumn = buttonsPerColumn
            }
        }
    }

    private var sendValueChangedAction = true
    private var config = Config()

    // MARK: -

    private var options: Options = [] {
        didSet {
            updateView()
            if sendValueChangedAction {
                sendActions(for: .valueChanged)
            }
        }
    }

    var optionsRawValue: Int { return options.rawValue }

    private var optionButtons: [[UIButton]] = [[]]
    private var gridRow = 0
    private var gridCol = 0

    private let allTag = -1
    private let noneTag = -2

    private var all: Options = []

    private func reset() {
        optionButtons = [[]]
        subviews.forEach { $0.removeFromSuperview() }

        config = Config()
        gridRow = 0
        gridCol = 0
        all = []
    }

    // MARK: - init(s)

    init() {
        super.init(frame: CGRect())     // owner will setup constraints and frame
        reset()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        reset()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        reset()
    }

    // MARK: setup
    @discardableResult
    private func addButton(title: String, tag: Int) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(config.unselectedTextColor, for: .normal)
        button.backgroundColor = config.unselectedBackgroundColor
        button.setTitleColor(config.selectedTextColor, for: .selected)
        button.tintColor = config.selectedBackgroundColor
        button.addTarget(self, action: #selector(toggleOption(_:)), for: .touchUpInside)
        button.tag = tag
        if gridRow >= config.buttonsPerColumn || tag == allTag {
            optionButtons.append([])
            gridCol += 1
            gridRow = 0
        }
        optionButtons[gridCol].append(button)
        gridRow += 1
        return button
    }

    private func createButtons() {
        os_log(.default, log: GameLog.debugSettings,
               "OPTIONSET createButtons() - buttsonsPerColumn - %s - view height = %s",
               "\(config.buttonsPerColumn)",
               "\(bounds.height)")
        var tagIndex = 0
        config.map.forEach { entry in
            let button = addButton(title: entry.buttonLabel, tag: tagIndex)
            all.insert(Options(rawValue: entry.option))
            tagIndex += 1
            os_log(.default, log: GameLog.debugSettings, "OPTIONSET created - %s - %s - %s",
                   "\(button.titleLabel?.text ?? "<>")",
                   "\(entry.buttonLabel)",
                   "\(entry.option)")
        }

        addButton(title: "ALL", tag: allTag)
        addButton(title: "NONE", tag: noneTag)
    }

    private func createStackView() {
        if optionButtons.count < 2 { return }

        // for any more than just the ALL or NONE buttons
        // create a stackview to hold stackviews for each
        // of the button columns
        let containerStackView = UIStackView()
        addSubview(containerStackView)
        containerStackView.spacing = 8.0
        containerStackView.axis = .horizontal
        containerStackView.alignment = .leading
        containerStackView.distribution = .fillProportionally
        containerStackView.translatesAutoresizingMaskIntoConstraints = false
        topAnchor.constraint(equalTo: containerStackView.topAnchor).isActive = true
        bottomAnchor.constraint(equalTo: containerStackView.bottomAnchor).isActive = true
        leadingAnchor.constraint(equalTo: containerStackView.leadingAnchor).isActive = true
        trailingAnchor.constraint(equalTo: containerStackView.trailingAnchor).isActive = true

        for buttonColumn in optionButtons {
            let stackView = UIStackView(arrangedSubviews: buttonColumn)
            containerStackView.addArrangedSubview(stackView)

            stackView.spacing = 8.0
            stackView.axis = .vertical
            stackView.alignment = .leading
            stackView.distribution = .fillEqually
            stackView.translatesAutoresizingMaskIntoConstraints = false
        }
   }

    @objc
    func toggleOption(_ sender: UIButton) {
        let tag = sender.tag
        if tag == allTag {
            options = all
            os_log(.default, log: GameLog.debugSettings, "OPTIONSET all - %s", "\(all)")
        } else if tag == noneTag {
            options = []
        } else if tag >= 0 && tag < .max {
            options = options.symmetricDifference(Options(rawValue: config.map[tag].option))
        }
        sendActions(for: .valueChanged)
    }

    func setupView(_ newConfig: Config) {
        reset()
        config = newConfig
        sendValueChangedAction = false
        options = Options(rawValue: config.initialOptions)
        sendValueChangedAction = true
        createButtons()
        createStackView()
        addTarget(self, action: #selector(toggleOption(_:)), for: .touchUpInside)
        configureButtons()
    }

    func updateView() {
        configureButtons()
    }

    func configureButtons() {
        guard !optionButtons.isEmpty, !optionButtons.first!.isEmpty else { return }
        os_log(.default, log: GameLog.debugSettings, "OPTIONSET configureButtons() - buttsonsPerColumn - %s - view height = %s",
               "\(config.buttonsPerColumn)",
               "\(bounds.height)")
        var tagIndex = 0
        for buttonArray in optionButtons {
            for button in buttonArray {
                if tagIndex < config.map.count {
                    let option = Options(rawValue: config.map[tagIndex].option)
                    button.isSelected = options.contains(option)
                    os_log(.default, log: GameLog.debugSettings, "OPTIONSET updated - %s - %s - %s",
                           "\(button.titleLabel?.text ?? "<>")",
                           "\(config.map[tagIndex].buttonLabel)",
                           "\(option.rawValue)")
                } else {
                    button.isSelected = false
                }
                tagIndex += 1
            }
        }
    }

}
