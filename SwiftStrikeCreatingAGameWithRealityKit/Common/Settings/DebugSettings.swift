/*
See LICENSE folder for this sample’s licensing information.

Abstract:
DebugSettings
*/

import os.log
import UIKit

extension GameLog {
    static let debugSettings = OSLog(subsystem: subsystem, category: "debugSettings")
}

extension DebugSettingPrototype.Kind {
    var hasKeyValue: Bool {
        switch self {
        case .slider, .sliderTunable, .sliderTunableInt:
            return true
        case .checkbox, .checkboxTunable:
            return true
        case .action, .segue, .section:
            return false
        case .optionSet:
            return true
        }
    }

    var valueType: Any.Type? {
        switch self {
        case .slider, .sliderTunable:
            return Float.self
        case .sliderTunableInt:
            return Int.self
        case .checkbox, .checkboxTunable:
            return Bool.self
        case .action, .segue, .section:
            return nil
        case .optionSet:
            return OptionSetControl.RawValue.self
        }
    }
}

class DebugSettings {
    static let shared = DebugSettings()

    private var sections: [DebugSettingPrototype] = []
    private var prototypes: [[DebugSettingPrototype]] = [[]]

    var numberOfSections: Int { return sections.count }

    func section(_ section: Int) -> DebugSettingPrototype {
        return sections[section]
    }

    func prototype(_ indexPath: IndexPath) -> DebugSettingPrototype {
        return prototypes[indexPath.section][indexPath.row]
    }

    func prototypes(in section: Int) -> Int {
        return prototypes[section].count
    }

    private func sectionPrototypes(_ newPrototypes: [DebugSettingPrototype]) {
        var prototypeCount: Int = 0
        prototypes = [[]]
        sections = []
        newPrototypes.forEach { prototype in
            if case .section = prototype.kind {
                if !sections.isEmpty {
                    prototypes.append([])
                }
                sections.append(prototype)
                return
            }
            if sections.isEmpty {
                sections.append(DebugSettingPrototype(title: "", kind: .section))
            }
            prototypes[sections.count - 1].append(prototype)
            prototypeCount += 1
        }
        os_log(.default, log: GameLog.debugSettings,
               "DebugSettings:  %s prototypeCount added in %s sections",
               "\(prototypeCount)",
               "\(sections.count)")
    }

    private func createSettingsStorage(_ newPrototypes: [DebugSettingPrototype]) {
        // Kind.action and Kind.segue do not require a key and no default value, so filter
        // those out to get the settings that have keys, values, and default values
        let dictionaryPrototypes = self.prototypes
            .flatMap { $0 }
            .compactMap { $0.kind.hasKeyValue ? $0 : nil }
        var error = 0
        settings = Dictionary(uniqueKeysWithValues: dictionaryPrototypes.map {
            let expectedType = $0.kind.valueType
            let value = $0.defaultValue
            let valueType = Mirror(reflecting: value).subjectType
            if expectedType != valueType {
                os_log(.default, log: GameLog.debugSettings,
                       "prototypes(): key: '%s', value '%s', value type = %s (not %s)",
                       "\($0.key)",
                       "\(value)",
                       "\(valueType)",
                       "\(String(describing: expectedType))")
                error += 1
            }
            return ($0.key, $0.defaultValue)
        })
        if error > 0 {
            let plural = error > 1 ? "s" : ""
            let hasHad = error > 1 ? "has" : "had"
            assertionFailure(String(format: "prototype%@ %@ default value types different from expected types, see log",
                                    "\(plural)",
                                    "\(hasHad)"))
        }
        os_log(.default, log: GameLog.debugSettings, "DebugSettings:  %s settings added", "\(settings.count)")
    }

    func setPrototypes(_ newPrototypes: [DebugSettingPrototype]) {
        sectionPrototypes(newPrototypes)
        createSettingsStorage(newPrototypes)
    }

    private(set) var settings: [String: Any] = [:]

    func floatGet(_ key: String) -> Float? { return settings[key] as? Float }
    func intGet(_ key: String) -> Int? { return settings[key] as? Int }
    func boolGet(_ key: String) -> Bool? { return settings[key] as? Bool }
    func rawValueGet(_ key: String) -> OptionSetControl.RawValue? { return settings[key] as? OptionSetControl.RawValue }
    func set(key: String, value newValue: Any?) {
        settings[key] = newValue
        guard let newValue = newValue else {
            return
        }
        prototypes
            .flatMap { $0 }
            .first(where: { $0.key == key })?.valueDidChange?(newValue)
    }
}

struct DebugSettingPrototype {
    let key: String
    let title: String
    enum Kind {
        case slider(minValue: Float?, maxValue: Float?, step: Float? = nil)
        case checkbox
        case action(() -> Void)
        case segue(identifier: String)
        case sliderTunable(tunableFloat: TunableScalar<Float>)
        case sliderTunableInt(tunableInt: TunableScalar<Int>)
        case checkboxTunable(tunableBool: TunableBool)
        case optionSet(config: OptionSetControl.Config, cellHeight: Int? = nil)
        case section
    }
    let kind: Kind
    let defaultValue: Any
    var controlWasReleased: (() -> Void)?
    var valueDidChange: ((Any) -> Void)?

    // action, seque, section
    init(title: String,
         kind: Kind
    ) {
        self.key = ""
        self.title = title
        self.kind = kind
        self.defaultValue = 0
    }

    // slider
    init(key: String,
         title: String,
         kind: Kind,
         defaultValue: Float? = nil,
         controlWasReleased: (() -> Void)?,
         _ valueDidChange: ((Float) -> Void)? = nil
    ) {
        self.key = key
        self.title = title
        self.kind = kind
        self.defaultValue = defaultValue ?? Float(0)
        self.controlWasReleased = controlWasReleased
        self.valueDidChange = {
            guard let newValue = $0 as? Float else { return }
            valueDidChange?(newValue)
        }
    }

    init(key: String,
         title: String,
         kind: Kind,
         defaultValue: Float? = nil,
         valueDidChange: ((Float) -> Void)? = nil
    ) {
        self.init(key: key, title: title, kind: kind, defaultValue: defaultValue, controlWasReleased: nil, valueDidChange)
    }

    // checkbox
    init(key: String,
         title: String,
         kind: Kind,
         defaultValue: Bool? = nil,
         valueDidChange: ((Bool) -> Void)? = nil
    ) {
        self.key = key
        self.title = title
        self.kind = kind
        self.defaultValue = defaultValue ?? false
        self.controlWasReleased = nil
        self.valueDidChange = {
            guard let newValue = $0 as? Bool else { return }
            valueDidChange?(newValue)
        }
    }

    // optionSet
    init(key: String,
         title: String,
         cellHeight: Int? = nil,
         config: OptionSetControl.Config,
         valueDidChange: ((OptionSetControl.RawValue) -> Void)? = nil
    ) {
        self.key = key
        self.title = title
        self.kind = .optionSet(config: config, cellHeight: cellHeight)
        self.defaultValue = config.initialOptions
        self.controlWasReleased = nil
        self.valueDidChange = {
            guard let newValue = $0 as? OptionSetControl.RawValue else { return }
            valueDidChange?(newValue)
        }
    }

    // sliderTunable (Float)
    init(_ tunableFloat: TunableScalar<Float>, _ completion: (() -> Void)? = nil) {
        self.key = tunableFloat.label
        self.title = tunableFloat.label
        self.kind = .sliderTunable(tunableFloat: tunableFloat)
        self.defaultValue = tunableFloat.value
        self.valueDidChange = {
            guard let newValue = $0 as? Float else { return }
            tunableFloat.value = newValue
            completion?()
        }
    }

    // sliderTunable (Int)
    init(_ tunableInt: TunableScalar<Int>, _ completion: (() -> Void)? = nil) {
        self.key = tunableInt.label
        self.title = tunableInt.label
        self.kind = .sliderTunableInt(tunableInt: tunableInt)
        self.defaultValue = tunableInt.value
        self.valueDidChange = {
            guard let newValue = $0 as? Int else { return }
            tunableInt.value = newValue
            completion?()
        }
    }

    // checkboxTunable
    init(_ tunableBool: TunableBool, _ completion: (() -> Void)? = nil) {
        self.key = tunableBool.label
        self.title = tunableBool.label
        self.kind = .checkboxTunable(tunableBool: tunableBool)
        self.defaultValue = tunableBool.value
        self.valueDidChange = {
            guard let newValue = $0 as? Bool else { return }
            tunableBool.value = newValue
            completion?()
        }
    }
}
