/*
See LICENSE folder for this sample’s licensing information.

Abstract:
SettingsNetworkBundle.swift
*/

import Foundation
import os.log
import RealityKit

enum SettingsNetworkBundleError: Error {
    case decodeError
}

enum SettingsMatchType: UInt32, CaseIterable {
    case mustMatch
    case mustBe
    case copy

    fileprivate init?(_ value: UInt32) {
        switch value {
        case 0: self = .mustMatch
        case 1: self = .mustBe
        case 2: self = .copy
        default: return nil
        }
    }
}

//
// UserDefaults can be Bool, Float, Double, Int, String, URL, Date, etc.
// For network transport we only allow certain types to be used in our
// UserSettings because we convert them to strings for transport and from
// strings during retrieval.
enum SettingsNetworkTypeId: UInt32, CaseIterable {
    case bool
    case float
    case int
    case gameScale
    case visualMode
}
private protocol SettingsNetworkValueTypeProtocol {}
extension Bool: SettingsNetworkValueTypeProtocol {}
extension Float: SettingsNetworkValueTypeProtocol {}
extension Int: SettingsNetworkValueTypeProtocol {}
extension GameScale: SettingsNetworkValueTypeProtocol {}
extension VisualMode: SettingsNetworkValueTypeProtocol {}

// special Network version required because the native
// enum must have a String RawValue, and the network
// transport requires a UInt32 RawValue for minimal cost
private enum NetworkGameScale: UInt32, CaseIterable {
    case tableTop
    case fullCourt

    fileprivate init(_ gameScale: GameScale) {
        switch gameScale {
        case GameScale.tableTop: self = .tableTop
        case GameScale.fullCourt: self = .fullCourt
        }
    }
}

extension GameScale {
    fileprivate init(_ value: NetworkGameScale) {
        switch value {
        case NetworkGameScale.tableTop: self = .tableTop
        case NetworkGameScale.fullCourt: self = .fullCourt
        }
    }
}

// special Network version required because the native
// enum must have a String RawValue, and the network
// transport requires a UInt32 RawValue for minimal cost
private enum NetworkVisualMode: UInt32, CaseIterable {
    case normal
    case cosmic

    fileprivate init(_ visualMode: VisualMode) {
        switch visualMode {
        case VisualMode.normal: self = .normal
        case VisualMode.cosmic: self = .cosmic
        }
    }
}

extension VisualMode {
     fileprivate init(_ value: NetworkVisualMode) {
        switch value {
        case NetworkVisualMode.normal: self = .normal
        case NetworkVisualMode.cosmic: self = .cosmic
        }
    }
}

private struct NetworkData {
    fileprivate let matchType: SettingsMatchType
    fileprivate let valueTypeId: SettingsNetworkTypeId
    private let value: Any //SettingsNetworkValueTypeProtocol

    fileprivate init(matchType: SettingsMatchType, valueTypeId: SettingsNetworkTypeId, value: SettingsNetworkValueTypeProtocol) {
        self.matchType = matchType
        self.valueTypeId = valueTypeId
        self.value = value
    }

    fileprivate var networkValue: SettingsNetworkValueTypeProtocol {
        guard let returnValue = value as? SettingsNetworkValueTypeProtocol else {
            fatalError(String(format: "NetworkData: value stored is not SettingsNetworkValueTypeProtocol???, is '%s'", "\(type(of: value))"))
        }
        return returnValue
    }
}

extension UserSettings {
    fileprivate static func getNetworkTypeForValue(fromKey key: String) -> SettingsNetworkValueTypeProtocol? {
        guard let value = UserSettings.get(forKey: key) else { return nil }
        return value as? SettingsNetworkValueTypeProtocol
    }

    fileprivate static func networkSet(forKey key: String,
                                       valueTypeId: SettingsNetworkTypeId,
                                       value: SettingsNetworkValueTypeProtocol?) -> Bool {
        guard let newValue = value else {
            os_log(.error, log: GameLog.general, "UserSettings: setValueFromString(forKey: '%s') failed because value is nil", "\(key)")
            return false
        }
        guard let oldValue = UserSettings.get(forKey: key) else {
            os_log(.error, log: GameLog.general, "UserSettings: setValueFromString(forKey: '%s') failed because key doesn't exist", "\(key)")
            return false
        }
        var success = false
        switch valueTypeId {
        case .bool:
            if oldValue is Bool, let bool = newValue as? Bool {
                UserSettings[key] = bool
                success = true
            }
        case .float:
            if oldValue is Float, let float = newValue as? Float {
                UserSettings[key] = float
                success = true
            }
        case .int:
            if oldValue is Int, let int = newValue as? Int {
                UserSettings[key] = int
                success = true
            }
        case .gameScale:
            if oldValue is GameScale, let gameScale = newValue as? GameScale {
                UserSettings[key] = gameScale
                success = true
            }
        case .visualMode:
            if oldValue is VisualMode, let visualMode = newValue as? VisualMode {
                UserSettings[key] = visualMode
                success = true
            }
        }
        if !success {
            os_log(.error, log: GameLog.general,
                   """
                   UserSettings: setValueFromString(forKey: '%s') failed because stored type for '%s' is type '%s' \
                   not given type '%s', or new value is type '%s' not type '%s'
                   """,
                   "\(key)",
                   "\(newValue)",
                   "\(type(of: oldValue))",
                   "\(valueTypeId)",
                   "\(type(of: newValue))",
                   "\(valueTypeId)")
        }
        return success
    }
}

extension NetworkData: Hashable {
    static func == (lhs: NetworkData, rhs: NetworkData) -> Bool {
        guard lhs.matchType == rhs.matchType && lhs.valueTypeId == rhs.valueTypeId else {
            return false
        }
        switch lhs.valueTypeId {
        case .bool:
            return lhs.value as? Bool == rhs.value as? Bool
        case .float:
            return lhs.value as? Float == rhs.value as? Float
        case .int:
            return lhs.value as? Int == rhs.value as? Int
        case .gameScale:
            return lhs.value as? GameScale == rhs.value as? GameScale
        case .visualMode:
            return lhs.value as? VisualMode == rhs.value as? VisualMode
        }
        //return false
    }

    func hash(into hasher: inout Hasher) {
        matchType.hash(into: &hasher)
        valueTypeId.hash(into: &hasher)
        switch valueTypeId {
        case .bool:
            hasher.combine(value as? Bool)
        case .float:
            hasher.combine(value as? Float)
        case .int:
            hasher.combine(value as? Int)
        case .gameScale:
            hasher.combine(value as? GameScale)
        case .visualMode:
            hasher.combine(value as? VisualMode)
        }
    }
}

extension SettingsMatchType: BitStreamCodable {
    init(from bitStream: inout ReadableBitStream) throws {
        guard let matchType = SettingsMatchType(try bitStream.readUInt32()) else {
            throw SettingsNetworkBundleError.decodeError
        }
        self = matchType
    }

    func encode(to bitStream: inout WritableBitStream) {
    }
}

extension SettingsNetworkTypeId: BitStreamCodable {
    init(from bitStream: inout ReadableBitStream) throws {
        guard let typeId = SettingsNetworkTypeId(rawValue: try bitStream.readUInt32()) else {
            throw SettingsNetworkBundleError.decodeError
        }
        self = typeId
    }

    func encode(to bitStream: inout WritableBitStream) {
    }
}

extension NetworkData: BitStreamCodable {
    fileprivate init(from bitStream: inout ReadableBitStream) throws {
        matchType = try bitStream.readEnum()
        valueTypeId = try bitStream.readEnum()
        switch valueTypeId {
        case .bool:
            value = try bitStream.readBool()
        case .float:
            value = try bitStream.readFloat()
        case .int:
            value = Int(try bitStream.readUInt32())
        case .gameScale:
            let enumValue: NetworkGameScale = try bitStream.readEnum()
            value = GameScale(enumValue)
        case .visualMode:
            let enumValue: NetworkVisualMode = try bitStream.readEnum()
            value = VisualMode(enumValue)
        }
    }

    fileprivate func encode(to bitStream: inout WritableBitStream) {
        bitStream.appendEnum(matchType)
        bitStream.appendEnum(valueTypeId)
        var success = false
        switch valueTypeId {
        case .bool:
            if let bool = value as? Bool {
                bitStream.appendBool(bool)
                success = true
            }
        case .float:
            if let float = value as? Float {
                bitStream.appendFloat(float)
                success = true
            }
        case .int:
            if let int = value as? Int {
                bitStream.appendInt32(Int32(int))
                success = true
            }
        case .gameScale:
            if let gameScale = value as? GameScale {
                bitStream.appendEnum(NetworkGameScale(gameScale))
                success = true
            }
        case .visualMode:
            if let visualMode = value as? VisualMode {
                bitStream.appendEnum(NetworkVisualMode(visualMode))
                success = true
            }
        }
        if !success {
            os_log(.error, log: GameLog.debugSettings, "")
        }
    }
}

class SettingsNetworkInfo {
    fileprivate enum Key: UInt8, BitStreamCodable {
        case none
        case gameScale
        case fullCourtScale
        case visualMode
        case spectator
        case enableMatchDuration
        case matchDuration

        init?(fromKey key: String) {
            switch key {
            case UserSettings.$gameScale: self = .gameScale
            case UserSettings.$fullCourtScale: self = .fullCourtScale
            case UserSettings.$visualMode: self = .visualMode
            case UserSettings.$spectator: self = .spectator
            case UserSettings.$enableMatchDuration: self = .enableMatchDuration
            case UserSettings.$matchDuration: self = .matchDuration
            default: return nil
            }
        }

        fileprivate var asString: String {
            switch self {
            case .gameScale: return UserSettings.$gameScale
            case .fullCourtScale: return UserSettings.$fullCourtScale
            case .visualMode: return UserSettings.$visualMode
            case .spectator: return UserSettings.$spectator
            case .enableMatchDuration: return UserSettings.$enableMatchDuration
            case .matchDuration: return UserSettings.$matchDuration
            default: return String(format: "<unknown SettingsNetworkInfo.Key - %s>", "\(self)")
            }
        }

        fileprivate var asTypeId: SettingsNetworkTypeId {
            switch self {
            case .gameScale: return .gameScale
            case .fullCourtScale: return .float
            case .visualMode: return .visualMode
            case .spectator: return .bool
            case .enableMatchDuration: return .bool
            case .matchDuration: return .int
            default: fatalError(String(format: "unknown SettingsNetworkInfo.Key - %s", "\(self)"))
            }
        }

        init(from bitStream: inout ReadableBitStream) throws {
            let key = Key(rawValue: try bitStream.readUInt8())
            self = key ?? .none
        }

        func encode(to bitStream: inout WritableBitStream) {
            bitStream.appendUInt8(self.rawValue)
        }
    }
}

final class SettingsNetworkBundle: BitStreamCodable {
    //
    // for making sure that the host/server
    // settings match the client(s) during
    // the join process.  Some settings
    // are set in the iOS Settings app,
    // and therefore require the app to
    // be restarted in order to use changed
    // values, while some can be copied from
    // the host/server
    //
    private(set) static var shared = SettingsNetworkBundle()

    static func update() {
        shared = SettingsNetworkBundle()
    }

    private var list = [SettingsNetworkInfo.Key: NetworkData]()

    struct ConfigData {
        let matchType: SettingsMatchType
        let valueTypeId: SettingsNetworkTypeId
        let value: Any?
        init(matchType: SettingsMatchType, valueTypeId: SettingsNetworkTypeId, value: Any? = nil) {
            self.matchType = matchType
            self.valueTypeId = valueTypeId
            self.value = value
        }
    }

    // Make sure the keys used are minimized in length (and unique)
    // Length is important because this batch of data is stored as
    // binary through BitStreamCodable, and then converted
    // to base64 as a string for network transport in the multi-peer
    // connectivity code which as limits of 100-200 characters in he
    // discoveryInfo. log warnings will be generated for over 150 characters,
    // and an error will be generated for 200 characters
    static let base64CharacterWarning = 180
    static let base64CharacterError = 200
    private static let bundleSet: [String: ConfigData] = [
        // Exposed via Settings bundle
        UserSettings.$gameScale: ConfigData(matchType: .mustMatch, valueTypeId: .gameScale),
        UserSettings.$fullCourtScale: ConfigData(matchType: .mustMatch, valueTypeId: .float),
        UserSettings.$visualMode: ConfigData(matchType: .mustMatch, valueTypeId: .visualMode),
        UserSettings.$spectator: ConfigData(matchType: .mustBe, valueTypeId: .bool, value: false),
        // Game Settings
        UserSettings.$enableMatchDuration: ConfigData(matchType: .copy, valueTypeId: .bool),
        UserSettings.$matchDuration: ConfigData(matchType: .copy, valueTypeId: .int)
    ]

    required init() {
        SettingsNetworkBundle.bundleSet.forEach { (stringKey, configData) in
            let entryValue: SettingsNetworkValueTypeProtocol?
            if configData.matchType == .mustBe {
                entryValue = configData.value as? SettingsNetworkValueTypeProtocol
            } else {
                entryValue = UserSettings.getNetworkTypeForValue(fromKey: stringKey)
            }
            guard let value = entryValue else {
                fatalError(String(format: "SettingsNetworkBundle: key '%s' value for '%s' could not be converted to '%s'",
                                  "\(stringKey)",
                                  "\(configData.matchType)",
                                  "\(configData.valueTypeId)"))
            }
            guard let key = SettingsNetworkInfo.Key(fromKey: stringKey) else {
                fatalError(String(format: "SettingsNetworkBundle: key '%s' could not be converted to SettingsNetworkInfo.Key"))
            }
            list[key] = NetworkData(matchType: configData.matchType, valueTypeId: configData.valueTypeId, value: value)
        }
    }

    private func equalValues(ofTypeId networkTypeId: SettingsNetworkTypeId,
                             _ lhs: SettingsNetworkValueTypeProtocol?,
                             _ rhs: SettingsNetworkValueTypeProtocol?) -> Bool {
        switch networkTypeId {
        case .bool: return lhs as? Bool == rhs as? Bool
        case .float: return lhs as? Float == rhs as? Float
        case .int: return lhs as? Int == rhs as? Int
        case .gameScale: return lhs as? GameScale == rhs as? GameScale
        case .visualMode: return lhs as? VisualMode == rhs as? VisualMode
        }
    }

    enum CompareMode {
        case compare
        case copy
    }

    func compare(mode: CompareMode = .compare) -> [String]? {
        var errors = [String]()
        var match = true
        let hostSettingsBundle = self
        let localSettingsBundle = SettingsNetworkBundle.shared
        if hostSettingsBundle.list.count != localSettingsBundle.list.count {
            errors.append(String(format: "local bundle (%d) != host bundle (%d)",
                                 localSettingsBundle.list.count,
                                 hostSettingsBundle.list.count))
            match = false
        }
        hostSettingsBundle.list.forEach { (key, data) in
            var errorString: String?
            let value = UserSettings.getNetworkTypeForValue(fromKey: key.asString)
            if let localSettingsValue = value {
                switch data.matchType {
                case .mustMatch, .mustBe:
                    if mode == .compare, !equalValues(ofTypeId: data.valueTypeId, data.networkValue, localSettingsValue) {
                        errorString = String(format: "'%@'='%@', need '%@'",
                                             "\(key)",
                                             "\(localSettingsValue)",
                                             "\(data.networkValue)")
                        match = false
                    }
                case .copy:
                    // validate that destination exists for a later copy
                    if mode == .copy {
                        if !UserSettings.networkSet(forKey: key.asString,
                                                    valueTypeId: data.valueTypeId,
                                                    value: data.networkValue) {
                            errorString = String(format: "failed write '%@' to '%@'",
                                                 "\(data.networkValue)",
                                                 "\(key)")
                        } else {
                            os_log(.default,
                                   log: GameLog.debugSettings,
                                   "SettingsNetworkBundle: copy() host '%s', local value changed from '%s' to '%s'",
                                   "\(key.asString)",
                                   "\(localSettingsValue)",
                                   "\(data.networkValue)")
                        }
                    }
                }
            } else {
                errorString = String( format: "host '%@' not in local settings", "\(key)")
            }
            if let string = errorString {
                os_log(.default, log: GameLog.debugSettings, "SettingsNetworkBundle: compare(%s) %s", "\(mode)", "\(string)")
                errors.append(string)
                match = false
            }
        }
        return match ? nil : errors
    }

    // MARK: - BitStreamCodable for SettingsNetworkBundle

    init(from bitStream: inout ReadableBitStream) throws {
        let count = Int(try bitStream.readUInt32())
        for _ in 0..<count {
            let key = try SettingsNetworkInfo.Key(from: &bitStream)
            list[key] = try NetworkData(from: &bitStream)
        }
    }

    func encode(to bitStream: inout WritableBitStream) {
        let streamSize = bitStream.bytes.count
        bitStream.appendUInt32(UInt32(list.count))
        list.forEach { (key, data) in
            let size = bitStream.bytes.count
            key.encode(to: &bitStream)
            data.encode(to: &bitStream)
            os_log(.default, log: GameLog.networkConnect, "BuildInfo key: %s, data size %d", "\(key)", bitStream.bytes.count - size)
        }
        os_log(.default, log: GameLog.networkConnect, "BuildInfo encoded data size %d", bitStream.bytes.count - streamSize)
    }
}

extension SettingsNetworkBundle {
    private static func asBinary() -> Data? {
        var bits = WritableBitStream()
        shared.encode(to: &bits)
        let data = bits.finalize()
        return data
    }

    private static func fromBinary(data: Data) -> SettingsNetworkBundle? {
        let settingsBundle: SettingsNetworkBundle
        var bits = ReadableBitStream(data: data)
        do {
            settingsBundle = try SettingsNetworkBundle(from: &bits)
        } catch {
            return nil
        }
        return settingsBundle
    }

    static func asString() -> String {
        update()
        guard let binary = SettingsNetworkBundle.asBinary() else {
            return ""
        }
        os_log(.default, log: GameLog.debugSettings, "SettingsNetworkBundle binary size %d", binary.count)
        let string = binary.base64EncodedString()
        os_log(.default, log: GameLog.debugSettings, "SettingsNetworkBundle string size %d", string.count)

        if string.count > base64CharacterError {
            os_log(.error, log: GameLog.debugSettings,
                   "SettingsNetworkBundle string size over %d, which is the limit indicated in documentation",
                   base64CharacterError)
        } else if string.count > base64CharacterWarning {
            os_log(.error, log: GameLog.debugSettings,
                   "SettingsNetworkBundle string size over %d, which is getting close to the limit(%d) indicated in documentation",
                   base64CharacterWarning,
                   base64CharacterError)
        }
        return string
    }

    static func fromString(base64String: String) -> SettingsNetworkBundle? {
        guard let binary = Data(base64Encoded: base64String) else {
            os_log(.error, log: GameLog.debugSettings, "failed getting settings bundle base64 data string '%s'", "\(base64String)")
            return nil
        }
        guard let settingsBundle = SettingsNetworkBundle.fromBinary(data: binary) else {
            os_log(.error, log: GameLog.debugSettings, "failed getting settings bundle from binary data from string '%s'", "\(base64String)")
            return nil
        }
        return settingsBundle
    }
}

extension SettingsNetworkBundle {
    static func logErrors(_ errors: [String]) {
        os_log(.error, log: GameLog.networkConnect, "SettingsNetworkBundle: local settings don't match host settings:")
        errors.forEach { error in
            os_log(.default, log: GameLog.networkConnect, "SettingsNetworkBundle:    %s", "\(error)")
        }
    }
}
