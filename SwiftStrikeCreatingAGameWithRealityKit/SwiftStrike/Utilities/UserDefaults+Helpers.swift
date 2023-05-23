/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Convenience extension for type safe UserDefaults access.
*/

import Foundation
import MultipeerConnectivity
import os.log
import RealityKit

/// Global Game Enums
enum BoardLocatingMode {
    case worldMap
    case manual
    case collaborative

    static let worldMapName = "worldMap"
    static let manualName = "manual"
    static let collaborativeName = "collaborative"
}

extension BoardLocatingMode: RawRepresentable {
    typealias RawValue = String

    init?(rawValue: RawValue) {
        switch rawValue {
        case BoardLocatingMode.worldMapName: self = .worldMap
        case BoardLocatingMode.manualName: self = .manual
        case BoardLocatingMode.collaborativeName: self = .collaborative
        default: return nil
        }
    }

    var rawValue: RawValue {
        switch self {
        case .worldMap: return BoardLocatingMode.worldMapName
        case .manual: return BoardLocatingMode.manualName
        case .collaborative: return BoardLocatingMode.collaborativeName
        }
    }
}

let rkRenderOptionsDefaults: ARView.RenderOptions = [
    .disableMotionBlur,
    .disableDepthOfField,
    .disableGroundingShadows,
    .disableCameraGrain
]

enum GameScale {
    case tableTop
    case fullCourt

    static let tableTopName = "tableTop"
    static let fullCourtName = "fullCourt"
}

extension GameScale: RawRepresentable, Equatable {
    typealias RawValue = String

    init?(rawValue: RawValue) {
        switch rawValue {
        case GameScale.tableTopName: self = .tableTop
        case GameScale.fullCourtName: self = .fullCourt
        default: return nil
        }
    }

    var rawValue: RawValue {
        switch self {
        case .tableTop: return GameScale.tableTopName
        case .fullCourt: return GameScale.fullCourtName
        }
    }
}

enum VisualMode {
    case normal
    case cosmic

    static let normalName = "normal"
    static let cosmicName = "cosmic"
}

extension VisualMode: RawRepresentable, Equatable {
    typealias RawValue = String

    init?(rawValue: RawValue) {
        switch rawValue {
        case VisualMode.normalName: self = .normal
        case VisualMode.cosmicName: self = .cosmic
        default: return nil
        }
    }

    var rawValue: RawValue {
        switch self {
        case .normal: return VisualMode.normalName
        case .cosmic: return VisualMode.cosmicName
        }
    }
}

// UserDefaults can be Bool, Float, Double, Int, String, URL, Date, etc.
// However, the bundle settings that root.plist references, associated with
// UserDefaults, are limited to Bool and String based on the default UI
// available.  So we only allow certain types to be used in our UserSettings
// and convert others to String for storage and retrieval
// These protocols allow us to enforce type safety
// for UserDefaults in the Bundle, we only support the following:
protocol BundleDefaultWrapperTypeProtocol {}
extension Bool: BundleDefaultWrapperTypeProtocol {}
extension String: BundleDefaultWrapperTypeProtocol {}
// for UserDefaults, we only support the following:
protocol UserDefaultWrapperTypeProtocol {}
extension Bool: UserDefaultWrapperTypeProtocol {}
extension String: UserDefaultWrapperTypeProtocol {}
extension Float: UserDefaultWrapperTypeProtocol {}
extension Int: UserDefaultWrapperTypeProtocol {}
extension UInt: UserDefaultWrapperTypeProtocol {}

extension UserDefaults {
    // used only for setting defaults when app is installed fresh, not for modifying bundle settings
    fileprivate static func setBundleDefaultAsync<T>(_ value: T, forKey key: String) where T: BundleDefaultWrapperTypeProtocol {
        DispatchQueue.main.async {
            UserDefaults.standard.set(value, forKey: key)
        }
    }
    fileprivate static func setUserDefaultAsync<T>(_ value: T, forKey key: String) where T: UserDefaultWrapperTypeProtocol {
        DispatchQueue.main.async {
            UserDefaults.standard.set(value, forKey: key)
        }
    }
}

//
// value type wrappers for propertiess
// used to shadow UserDefaults
//
// UserDefaults can be Bool, Float, Double, Int, String, URL, Date, etc.
// However, the bundle settings that root.plist references, associated with
// UserDefaults, are limited to Bool, Int, String based on the default UI
// available.  So we convert Float, and Enum types to String for storage,
// and convert from String when loading to store in the property
protocol UserSettingsWrapperTypeProtocol {
    associatedtype BundleDefaultType: BundleDefaultWrapperTypeProtocol
    associatedtype UserDefaultType: UserDefaultWrapperTypeProtocol
    var typedForBundleDefault: BundleDefaultType { get }
    var typedForUserDefault: UserDefaultType { get }
    static func bundleDefaultAsTypedValue(_ dictionaryValue: Any) -> Self?
    static func userDefaultAsTypedValue(_ dictionaryValue: Any) -> Self?
}
extension Bool: UserSettingsWrapperTypeProtocol {
    typealias BundleDefaultType = Bool
    typealias UserDefaultType = Bool
    var typedForBundleDefault: BundleDefaultType { return self }
    var typedForUserDefault: UserDefaultType { return self }
    static func bundleDefaultAsTypedValue(_ dictionaryValue: Any) -> Bool? {
        let typedValue = dictionaryValue as? Bool
        return typedValue
    }
    static func userDefaultAsTypedValue(_ dictionaryValue: Any) -> Bool? {
        let typedValue = dictionaryValue as? Bool
        return typedValue
    }
}
extension String: UserSettingsWrapperTypeProtocol {
    typealias BundleDefaultType = String
    typealias UserDefaultType = String
    var typedForBundleDefault: BundleDefaultType { return self }
    var typedForUserDefault: UserDefaultType { return self }
    static func bundleDefaultAsTypedValue(_ dictionaryValue: Any) -> String? {
        let typedValue = dictionaryValue as? String
        return typedValue
    }
    static func userDefaultAsTypedValue(_ dictionaryValue: Any) -> String? {
        let typedValue = dictionaryValue as? String
        return typedValue
    }
}
extension Float: UserSettingsWrapperTypeProtocol {
    typealias BundleDefaultType = String
    typealias UserDefaultType = Float
    var typedForBundleDefault: BundleDefaultType { return "\(self)" }
    var typedForUserDefault: UserDefaultType { return self }
    static func bundleDefaultAsTypedValue(_ dictionaryValue: Any) -> Float? {
        let stringValue = dictionaryValue as? String
        let typedValue: Float? = stringValue != nil ? Float(stringValue!) : nil
        return typedValue
    }
    static func userDefaultAsTypedValue(_ dictionaryValue: Any) -> Float? { return dictionaryValue as? Float }
}
extension Int: UserSettingsWrapperTypeProtocol {
    typealias BundleDefaultType = String
    typealias UserDefaultType = Int
    var typedForBundleDefault: BundleDefaultType { return "\(self)" }
    var typedForUserDefault: UserDefaultType { return self }
    static func bundleDefaultAsTypedValue(_ dictionaryValue: Any) -> Int? {
        let stringValue = dictionaryValue as? String
        let typedValue = stringValue != nil ? Int(stringValue!) : nil
        return typedValue
    }
    static func userDefaultAsTypedValue(_ dictionaryValue: Any) -> Int? { return dictionaryValue as? Int }
}
extension UInt: UserSettingsWrapperTypeProtocol {
    typealias BundleDefaultType = String
    typealias UserDefaultType = UInt
    var typedForBundleDefault: BundleDefaultType { return "\(self)" }
    var typedForUserDefault: UserDefaultType { return self }
    static func bundleDefaultAsTypedValue(_ dictionaryValue: Any) -> UInt? {
        let stringValue = dictionaryValue as? String
        let typedValue = stringValue != nil ? UInt(stringValue!) : nil
        return typedValue
    }
    static func userDefaultAsTypedValue(_ dictionaryValue: Any) -> UInt? { return dictionaryValue as? UInt }
}
extension GameScale: UserSettingsWrapperTypeProtocol {
    typealias BundleDefaultType = String
    typealias UserDefaultType = String
    var typedForBundleDefault: BundleDefaultType { return "\(self)" }
    var typedForUserDefault: UserDefaultType { return "\(self)" }
    static func bundleDefaultAsTypedValue(_ dictionaryValue: Any) -> GameScale? {
        let stringValue = dictionaryValue as? String
        let typedValue = stringValue != nil ? GameScale(rawValue: stringValue!) : nil
        return typedValue
    }
    static func userDefaultAsTypedValue(_ dictionaryValue: Any) -> GameScale? { return dictionaryValue as? GameScale }
}
extension VisualMode: UserSettingsWrapperTypeProtocol {
    typealias BundleDefaultType = String
    typealias UserDefaultType = String
    var typedForBundleDefault: BundleDefaultType { return "\(self)" }
    var typedForUserDefault: UserDefaultType { return "\(self)" }
    static func bundleDefaultAsTypedValue(_ dictionaryValue: Any) -> VisualMode? {
        let stringValue = dictionaryValue as? String
        let typedValue = stringValue != nil ? VisualMode(rawValue: stringValue!) : nil
        return typedValue
    }
    static func userDefaultAsTypedValue(_ dictionaryValue: Any) -> VisualMode? { return dictionaryValue as? VisualMode }
}
extension BoardLocatingMode: UserSettingsWrapperTypeProtocol {
    typealias BundleDefaultType = String
    typealias UserDefaultType = String
    var typedForBundleDefault: BundleDefaultType { return "\(self)" }
    var typedForUserDefault: UserDefaultType { return "\(self)" }
    static func bundleDefaultAsTypedValue(_ dictionaryValue: Any) -> BoardLocatingMode? { return dictionaryValue as? BoardLocatingMode }
    static func userDefaultAsTypedValue(_ dictionaryValue: Any) -> BoardLocatingMode? {
        let stringValue = dictionaryValue as? String
        let typedValue = stringValue != nil ? BoardLocatingMode(rawValue: stringValue!) : nil
        return typedValue
    }
}

//
// property wrappers for propertiess
// used to shadow UserDefaults
//
@propertyWrapper
struct BundleDefault<T: UserSettingsWrapperTypeProtocol> {
    let projectedValue: String
    private var cachedValue: T

    // bundle settings are read-only
    // and only initialized, so we can
    // return the cachedValue and do nothing for the set
    var wrappedValue: T { get { cachedValue } set { _ = newValue } }

    init(key: String, initialValue: T) {
        UserSettings.staticInit()

        (projectedValue, cachedValue) = (key, initialValue)

        // override initial value if key exists with a proper value in
        // the UserDefaults
        let userDefaultsValue = UserDefaults.standard.object(forKey: key)
        let typedValue = userDefaultsValue != nil ? T.bundleDefaultAsTypedValue(userDefaultsValue!) : nil
        if typedValue != nil {
            cachedValue = typedValue!
        }

        UserSettings.set(cachedValue, forKey: projectedValue,
                         userDefault: userDefaultsValue, userDefaultTyped: typedValue, wrapperName: "BundleDefault")
        if userDefaultsValue == nil {
            UserDefaults.setBundleDefaultAsync(cachedValue.typedForBundleDefault, forKey: projectedValue)
        }
    }

    init(key: String, debugValue: T, releaseValue: T) {
        #if DEBUG
        self.init(key: key, initialValue: debugValue)
        #else
        self.init(key: key, initialValue: releaseValue)
        #endif
    }
}

@propertyWrapper
struct BundleDefaultEnum<T: RawRepresentable> where T: UserSettingsWrapperTypeProtocol, T.RawValue == String {
    let projectedValue: String
    private var cachedValue: T

    // bundle settings are read-only
    // and only initialized, so we can
    // return the cachedValue and do nothing for the set
    var wrappedValue: T { get { cachedValue } set { _ = newValue } }

    init(key: String, initialValue: T) {
        UserSettings.staticInit()

        (projectedValue, cachedValue) = (key, initialValue)

        // override initial value if key exists with a proper value in
        // the UserDefaults
        let userDefaultsValue = UserDefaults.standard.string(forKey: key)
        let typedValue = userDefaultsValue != nil ? T.bundleDefaultAsTypedValue(userDefaultsValue!) : nil
        if typedValue != nil {
            cachedValue = typedValue!
        }

        UserSettings.set(cachedValue, forKey: projectedValue,
                         userDefault: userDefaultsValue, userDefaultTyped: typedValue, wrapperName: "BundleDefaultEnum")
        if userDefaultsValue == nil {
            UserDefaults.setBundleDefaultAsync(cachedValue.typedForBundleDefault, forKey: projectedValue)
        }
    }
}

@propertyWrapper
struct UserDefault<T: UserSettingsWrapperTypeProtocol> {
    let projectedValue: String
    private var cachedValue: T

    var wrappedValue: T {
        get {
            guard UserSettings.defaultsRegistered else { return cachedValue }
            return UserSettings.get(forKey: projectedValue) as? T ?? cachedValue
        }
        set {
            let key = projectedValue
            cachedValue = newValue
            UserSettings.set(cachedValue.typedForUserDefault, forKey: key, wrapperName: "UserDefault")
            UserDefaults.setUserDefaultAsync(cachedValue.typedForUserDefault, forKey: projectedValue)
        }
    }

    init(key: String, initialValue: T) {
        UserSettings.staticInit()

        (projectedValue, cachedValue) = (key, initialValue)

        // override initial value if key exists with a proper value in
        // the UserDefaults
        let userDefaultsValue = UserDefaults.standard.object(forKey: key)
        let typedValue = userDefaultsValue != nil ? T.userDefaultAsTypedValue(userDefaultsValue!) : nil
        if typedValue != nil {
            cachedValue = typedValue!
        }

        UserSettings.set(cachedValue, forKey: projectedValue,
                         userDefault: userDefaultsValue, userDefaultTyped: typedValue, wrapperName: "UserDefault")
        if userDefaultsValue == nil {
            UserDefaults.setUserDefaultAsync(cachedValue.typedForUserDefault, forKey: projectedValue)
        }
    }

    init(key: String, debugValue: T, releaseValue: T) {
        #if DEBUG
        self.init(key: key, initialValue: debugValue)
        #else
        self.init(key: key, initialValue: releaseValue)
        #endif
    }
}

@propertyWrapper
struct UserDefaultEnum<T: RawRepresentable> where T: UserSettingsWrapperTypeProtocol, T.RawValue == String {
    let projectedValue: String
    private var cachedValue: T

    var wrappedValue: T {
        get {
            guard UserSettings.defaultsRegistered else { return cachedValue }
            return UserSettings.get(forKey: projectedValue) as? T ?? cachedValue
        }
        set {
            let key = projectedValue
            cachedValue = newValue
            UserSettings.set(newValue.rawValue, forKey: key, wrapperName: "UserDefaultEnum")
            UserDefaults.setUserDefaultAsync(cachedValue.typedForUserDefault, forKey: projectedValue)
        }
    }

    init(key: String, initialValue: T) {
        UserSettings.staticInit()

        (projectedValue, cachedValue) = (key, initialValue)

        // override initial value if key exists with a proper value in
        // the UserDefaults
        let userDefaultsValue = UserDefaults.standard.string(forKey: key)
        let typedValue = userDefaultsValue != nil ? T.userDefaultAsTypedValue(userDefaultsValue!) : nil
        if typedValue != nil {
            cachedValue = typedValue!
        }

        UserSettings.set(cachedValue, forKey: projectedValue,
                         userDefault: userDefaultsValue, userDefaultTyped: typedValue, wrapperName: "UserDefaultEnum")
        if userDefaultsValue == nil {
            UserDefaults.setUserDefaultAsync(cachedValue.typedForUserDefault, forKey: projectedValue)
        }
    }

    init(key: String, debugValue: T, releaseValue: T) {
        #if DEBUG
        self.init(key: key, initialValue: debugValue)
        #else
        self.init(key: key, initialValue: releaseValue)
        #endif
    }
}

enum UserSettingsTunables {
    // this is a set of tunable values the should not be persistent
    static var peopleOcclusion = TunableBool("Enable People Occlusion", def: false)
}

enum UserSettings {

    // This dictionary is a shadow of UserDefaults.standard
    // so that its values can be updated from one of
    // the property wrappers, or some external system
    // using the apis below.  Also, the propertyWrappers
    // update this shadow, and then update UserDefaults
    // using DispatchQueue.main so that the UserDefaults.didChangeNotification
    // is delivered while we are executing outside the
    // propertyWrapper setter.  This is so that we don't
    // get a Swift run-time error for simultaeneous access
    // for using the property setter, triggering a UserDefaults.didChangeNotification,
    // which may trigger a getter on the same property, causing
    // the simultaeneious access - read while writing
    private static var settingsBackingDictionary: [String: Any]!

    // used by property wrappers to make sure our backing
    // dictionary is allocated and available during the
    // init() of the property
    fileprivate static func staticInit() {
        if settingsBackingDictionary == nil {
            settingsBackingDictionary = [String: Any]()
        }
    }

    // Exposed via Settings bundle
    @BundleDefaultEnum(key: "GameScale", initialValue: .tableTop)
    static var gameScale: GameScale
    @BundleDefault(key: "FullCourtScale", initialValue: 1.0)
    static var fullCourtScale: Float
    @BundleDefaultEnum(key: "VisualMode", initialValue: .normal)
    static var visualMode: VisualMode
    @BundleDefault(key: "Spectator", initialValue: false)
    static var spectator: Bool
    @BundleDefault(key: "UseSavedMap", initialValue: false)
    static var useSavedMap: Bool
    @BundleDefault(key: "DebugBillboards", initialValue: false)
    static var debugBillboards: Bool
    @BundleDefault(key: "DebugEnabled", debugValue: true, releaseValue: false)
    static var debugEnabled: Bool

    // Game Settings: SwiftStrike Settings
    @UserDefault(key: "EnableMatchDuration", debugValue: false, releaseValue: true)
    static var enableMatchDuration: Bool
    @UserDefault(key: "MatchDuration", initialValue: 30)
    static var matchDuration: Int

    // Developer Settings:  UI Settings
    @UserDefault(key: "DisableInGameUI", initialValue: false)
    static var disableInGameUI: Bool

    // Developer Settings: Board Location
    @UserDefaultEnum(key: "BoardLocatingMode", initialValue: .collaborative)
    static var boardLocatingMode: BoardLocatingMode
    @UserDefault(key: "FloorDecalDiameter", initialValue: 1.194)
    static var floorDecalDiameter: Float

    // Debug Menu: Misc.
    @UserDefault(key: "EnableVelocityKinematic", initialValue: false)
    static var enableVelocityKinematic: Bool
    @UserDefault(key: "EnableStrikerMotion", initialValue: true)
    static var enableStrikerMotion: Bool
    @UserDefault(key: "EnablePewPew", initialValue: false)
    static var enablePewPew: Bool

    @UserDefault(key: "EnablePaddleLeafBlower", initialValue: true)
    static var enablePaddleLeafBlower: Bool
    @UserDefault(key: "EnablePaddleKick", initialValue: true)
    static var enablePaddleKick: Bool

    @UserDefault(key: "PinFadeDist", initialValue: 2.0)
    static var pinFadeDist: Float

    // Debug Settings: Audio settings
    @UserDefault(key: "MusicVolume", initialValue: 0.7)
    static var musicVolume: Float
    @UserDefault(key: "EffectsVolume", initialValue: 0.7)
    static var effectsVolume: Float
    @UserDefault(key: "EnableReverb", initialValue: false)
    static var enableReverb: Bool

    // Debug Settings:  AR Environment
    @UserDefault(key: "UseIbl", initialValue: false)
    static var useIbl: Bool
    @UserDefault(key: "LightingIntensity", initialValue: 0.5)
    static var lightingIntensity: Float

    // Debug Settings: ARView Debug Options
    @UserDefault(key: "ARDebugOptions", initialValue: 0)
    static var arDebugOptions: Int

    // Debug Settings:  RealityKit Render Options
    @UserDefault(key: "RKRenderOptions", initialValue: rkRenderOptionsDefaults.rawValue)
    static var rkRenderOptions: UInt

    @UserDefault(key: "ShowThermalState", debugValue: false, releaseValue: false)
    static var showThermalState: Bool
    @UserDefault(key: "ShowTrackingState", debugValue: true, releaseValue: false)
    static var showTrackingState: Bool
    @UserDefault(key: "CollabMappingDebug", initialValue: false)
    static var showCollabMappingDebug: Bool

    // Debug Settings: not in any debug menu
    @UserDefault(key: "DebugGlowScale", initialValue: 1.08)
    static var glowScale: Float
    @UserDefault(key: "DebugGlowBias", initialValue: 0.0)
    static var glowBias: Float
    @UserDefault(key: "GlowRotateWithBall", initialValue: false)
    static var glowRotateWithBall: Bool

    // Debug Menu
    @UserDefault(key: "EnableARAutoFocus", initialValue: false)
    static var enableARAutoFocus: Bool
    @UserDefault(key: "ShowARMappingState", initialValue: false)
    static var showARMappingState: Bool

    @UserDefault(key: "DebugPinStatusView", initialValue: false)
    static var debugPinStatusView: Bool
    @UserDefault(key: "DebugCountdownTimerView", initialValue: false)
    static var debugCountdownTimerView: Bool

    // other in-game controls
    @UserDefault(key: "CosmicExposureCompensation", initialValue: -4.3)
    static var cosmicExposureCompensation: Float

    // audio:
    @UserDefault(key: "ShowSpectatorListenerPosition", initialValue: false)
    static var showSpectatorListenerPosition: Bool

    // Misc
    @UserDefault(key: "DisableBeamsOfLight", initialValue: false)
    static var disableBeamsOfLight: Bool

    private static let appDefaultsDictionary: [String: Any] = [
        $gameScale: gameScale.rawValue,
        $fullCourtScale: fullCourtScale,
        $visualMode: visualMode.rawValue,
        $spectator: spectator,
        $useSavedMap: useSavedMap,
        $debugBillboards: debugBillboards,
        $debugEnabled: debugEnabled
    ]

    private static let gameDefaultsDictionary: [String: Any] = [
        $enableMatchDuration: enableMatchDuration,
        $matchDuration: matchDuration,

        $disableInGameUI: disableInGameUI,

        $boardLocatingMode: boardLocatingMode.rawValue,
        $floorDecalDiameter: floorDecalDiameter
    ]

    private static let developerDefaultsDictionary: [String: Any] = [

        $enableVelocityKinematic: enableVelocityKinematic,
        $enableStrikerMotion: enableStrikerMotion,

        $enablePewPew: enablePewPew,

        $enablePaddleLeafBlower: enablePaddleLeafBlower,
        $enablePaddleKick: enablePaddleKick,

        $musicVolume: musicVolume,
        $effectsVolume: effectsVolume,
        $enableReverb: enableReverb,

        $useIbl: useIbl,
        $lightingIntensity: lightingIntensity,

        $arDebugOptions: arDebugOptions,

        $rkRenderOptions: rkRenderOptions,

        $showThermalState: showThermalState,
        $showTrackingState: showTrackingState,
        $showCollabMappingDebug: showCollabMappingDebug,

        $glowScale: glowScale,
        $glowBias: glowBias,
        $glowRotateWithBall: glowRotateWithBall,

        $enableARAutoFocus: enableARAutoFocus,
        $showARMappingState: showARMappingState,

        $debugPinStatusView: debugPinStatusView,
        $debugCountdownTimerView: debugCountdownTimerView,

        $cosmicExposureCompensation: cosmicExposureCompensation,

        $showSpectatorListenerPosition: showSpectatorListenerPosition,

        $disableBeamsOfLight: disableBeamsOfLight
    ]

    private static let defaultsList: [[String: Any]] = [
        appDefaultsDictionary,
        gameDefaultsDictionary,
        developerDefaultsDictionary
    ]

    fileprivate static var defaultsRegistered: Bool = false

}

extension UserSettings {
    // used by subscript in switch mapping property name
    // to property
    private static func setBundleDefaultsProperty<T>(byName name: String,
                                                     newValue: Any,
                                                     _ property: inout T
    ) -> (Bool, String) where T: UserSettingsWrapperTypeProtocol {
        let propertyType = "\(type(of: property))"
        guard let value = T.bundleDefaultAsTypedValue(newValue) else {
            return (false, propertyType)
        }
        property = value
        return (true, propertyType)
    }
    private static func setUserDefaultsProperty<T>(byName name: String,
                                                   newValue: Any,
                                                   _ property: inout T
    ) -> (Bool, String) where T: UserSettingsWrapperTypeProtocol {
        let propertyType = "\(type(of: property))"
        guard let value = T.userDefaultAsTypedValue(newValue) else {
            return (false, propertyType)
        }
        property = value
        return (true, propertyType)
    }
    private static func setEnumProperty<T>(byName name: String,
                                           newValue: Any,
                                           _ property: inout T
    ) -> (Bool, String) where T: UserSettingsWrapperTypeProtocol {
        let propertyType = "\(type(of: property))"
        guard let value = T.userDefaultAsTypedValue(newValue) else {
            return (false, propertyType)
        }
        property = value
        return (true, propertyType)
    }
    private static func assign<T>(byName key: String, newValue: T) -> (Bool, String) where T: UserSettingsWrapperTypeProtocol {
        let propertyType: String
        var success = false
        switch key {
        // Exposed via Settings bundle
        case $gameScale: (success, propertyType) = setEnumProperty(byName: key, newValue: newValue, &gameScale)
        case $fullCourtScale: (success, propertyType) = setBundleDefaultsProperty(byName: key, newValue: newValue, &fullCourtScale)
        case $visualMode: (success, propertyType) = setEnumProperty(byName: key, newValue: newValue, &visualMode)
        case $spectator: (success, propertyType) = setBundleDefaultsProperty(byName: key, newValue: newValue, &spectator)
        case $useSavedMap: (success, propertyType) = setBundleDefaultsProperty(byName: key, newValue: newValue, &useSavedMap)
        case $debugBillboards: (success, propertyType) = setBundleDefaultsProperty(byName: key, newValue: newValue, &debugBillboards)
        case $debugEnabled: (success, propertyType) = setBundleDefaultsProperty(byName: key, newValue: newValue, &debugEnabled)

        // Game Settings: SwiftStrike Settings
        case $enableMatchDuration: (success, propertyType) = setUserDefaultsProperty(byName: key, newValue: newValue, &enableMatchDuration)
        case $matchDuration: (success, propertyType) = setUserDefaultsProperty(byName: key, newValue: newValue, &matchDuration)

        // Developer Settings:  UI Settings
        case $disableInGameUI: (success, propertyType) = setUserDefaultsProperty(byName: key, newValue: newValue, &disableInGameUI)

        // Developer Settings: Board Location
        case $boardLocatingMode: (success, propertyType) = setEnumProperty(byName: key, newValue: newValue, &boardLocatingMode)
        case $floorDecalDiameter: (success, propertyType) = setUserDefaultsProperty(byName: key, newValue: newValue, &floorDecalDiameter)

        // Debug Menu: Misc.
        case $enableVelocityKinematic: (success, propertyType) = setUserDefaultsProperty(byName: key,
                                                                                         newValue: newValue, &enableVelocityKinematic)
        case $enableStrikerMotion: (success, propertyType) = setUserDefaultsProperty(byName: key, newValue: newValue, &enableStrikerMotion)
        case $enablePewPew: (success, propertyType) = setUserDefaultsProperty(byName: key, newValue: newValue, &enablePewPew)

        // Debug Settings: Gameplay Force Field
        case $enablePaddleLeafBlower: (success, propertyType) = setUserDefaultsProperty(byName: key, newValue: newValue, &enablePaddleLeafBlower)
        case $enablePaddleKick: (success, propertyType) = setUserDefaultsProperty(byName: key, newValue: newValue, &enablePaddleKick)

        case $pinFadeDist: (success, propertyType) = setUserDefaultsProperty(byName: key, newValue: newValue, &pinFadeDist)

        // Debug Settings: Audio settings
        case $musicVolume: (success, propertyType) = setUserDefaultsProperty(byName: key, newValue: newValue, &musicVolume)
        case $effectsVolume: (success, propertyType) = setUserDefaultsProperty(byName: key, newValue: newValue, &effectsVolume)
        case $enableReverb: (success, propertyType) = setUserDefaultsProperty(byName: key, newValue: newValue, &enableReverb)

        // Debug Settings:  AR Environment
        case $useIbl: (success, propertyType) = setUserDefaultsProperty(byName: key, newValue: newValue, &useIbl)
        case $lightingIntensity: (success, propertyType) = setUserDefaultsProperty(byName: key, newValue: newValue, &lightingIntensity)

        // Debug Settings: ARView Debug Options
        case $arDebugOptions: (success, propertyType) = setUserDefaultsProperty(byName: key, newValue: newValue, &arDebugOptions)

        // Debug Settings:  RealityKit Render Options
        case $rkRenderOptions: (success, propertyType) = setUserDefaultsProperty(byName: key, newValue: newValue, &rkRenderOptions)

        case $showThermalState: (success, propertyType) = setUserDefaultsProperty(byName: key, newValue: newValue, &showThermalState)
        case $showTrackingState: (success, propertyType) = setUserDefaultsProperty(byName: key, newValue: newValue, &showTrackingState)
        case $showCollabMappingDebug: (success, propertyType) = setUserDefaultsProperty(byName: key, newValue: newValue, &showCollabMappingDebug)

        // Debug Settings: not in any debug menu
        case $glowScale: (success, propertyType) = setUserDefaultsProperty(byName: key, newValue: newValue, &glowScale)
        case $glowBias: (success, propertyType) = setUserDefaultsProperty(byName: key, newValue: newValue, &glowBias)
        case $glowRotateWithBall: (success, propertyType) = setUserDefaultsProperty(byName: key, newValue: newValue, &glowRotateWithBall)

        // Debug Menu
        case $enableARAutoFocus: (success, propertyType) = setUserDefaultsProperty(byName: key, newValue: newValue, &enableARAutoFocus)
        case $showARMappingState: (success, propertyType) = setUserDefaultsProperty(byName: key, newValue: newValue, &showARMappingState)

        case $debugPinStatusView: (success, propertyType) = setUserDefaultsProperty(byName: key,
                                                                                    newValue: newValue,
                                                                                    &debugPinStatusView)
        case $debugCountdownTimerView: (success, propertyType) = setUserDefaultsProperty(byName: key,
                                                                                         newValue: newValue,
                                                                                         &debugCountdownTimerView)

        // other in-game controls
        case $cosmicExposureCompensation: (success, propertyType) = setUserDefaultsProperty(byName: key,
                                                                                            newValue: newValue,
                                                                                            &cosmicExposureCompensation)

        // audio:
        case $showSpectatorListenerPosition: (success, propertyType) = setUserDefaultsProperty(byName: key,
                                                                                               newValue: newValue,
                                                                                               &showSpectatorListenerPosition)

        // Misc
        case $disableBeamsOfLight: (success, propertyType) = setUserDefaultsProperty(byName: key, newValue: newValue, &disableBeamsOfLight)
        default: os_log(.error, log: GameLog.general, "UserSettings: assign() '%s' not a valid name/key", "\(key)"); propertyType = "<no type>"
        }
        return (success, propertyType)
    }
}

extension UserSettings {

    // required by property wrapper to set the backing dictionary when a
    // property is set by name; prevents a possible circular set
    fileprivate static func set<T>(_ newValue: T,
                                   forKey key: String,
                                   wrapperName: String) {
        #if DEBUG
        os_log(.default, log: GameLog.debugSettings,
               "%s<%s>: %s: '%s'",
               "\(wrapperName)",
               "\(T.self)",
               "\(key)", "\(newValue)")
        #endif
        settingsBackingDictionary[key] = newValue
    }
    fileprivate static func set<T>(_ newValue: T,
                                   forKey key: String,
                                   userDefault userDefaultsValue: Any?,
                                   userDefaultTyped typedValue: T?,
                                   wrapperName: String)  {
        #if DEBUG
        // dictionaryValue, T, key, value, typedValue
        let dictionaryValueType = userDefaultsValue != nil ? type(of: userDefaultsValue!) : nil
        let dictionaryValueTypeString = dictionaryValueType != nil ? "\(dictionaryValueType!)" : nil
        let dictionaryValueString = userDefaultsValue != nil ? "\(userDefaultsValue!)" : nil
        os_log(.default, log: GameLog.debugSettings,
               "%s<%s>: %s: '%s'<-'%s'='%s'%s%s",
               "\(wrapperName)",
               "\(T.self)",
               "\(key)", "\(newValue)",
               "\(dictionaryValueTypeString != nil ? dictionaryValueTypeString! : "")",
               "\(dictionaryValueString != nil ? dictionaryValueString! : "")",
               "\(userDefaultsValue != nil ? "" : " (no dictionary entry)")",
               "\(typedValue != nil ? "" : " (entry failed cast)")")
        #endif
        settingsBackingDictionary[key] = newValue
    }

    static func getBool(forKey key: String) -> Bool? {
        return settingsBackingDictionary[key] as? Bool
    }

    static func getInt(forKey key: String) -> Int? {
        return settingsBackingDictionary[key] as? Int
    }

    static func getFloat(forKey key: String) -> Float? {
        return settingsBackingDictionary[key] as? Float
    }

    static func getString(forKey key: String) -> String? {
        return settingsBackingDictionary[key] as? String
    }

    static func get(forKey key: String) -> Any? {
        return settingsBackingDictionary[key]
    }

    static subscript<T: UserSettingsWrapperTypeProtocol>(key: String) -> T? {
        get {
            return settingsBackingDictionary[key] as? T
        }
        set {
            // first set named property and validate type, before setting backing dictionary
            // setting by key must also make sure that the
            // named property is set.  Unfortunately this
            // requires that a line is added for each
            // named property
            guard let newValue = newValue else {
                os_log(.error, log: GameLog.general, "UserSettings: cannot set property '%s' to nil", "\(key)")
                return
            }
            let (success, propertyType) = assign(byName: key, newValue: newValue)
            guard success else {
                os_log(.error, log: GameLog.general, "UserSettings: value '%s', type '%s' is not correct type '%s' for key '%s'",
                       "\(String(describing: newValue))", "\(type(of: newValue))", "\(propertyType)", "\(key)")
                return
            }
            settingsBackingDictionary[key] = newValue
        }
    }

}

extension UserSettings {

    private static func registerDefaults(_ dictionary: [String: Any]) {
        os_log(.default, log: GameLog.debugSettings, "BundleSettings/UserDefaults register %s Settings", "\(dictionary.count)")
        dictionary.forEach { entry in
            os_log(.default, log: GameLog.debugSettings, "    %s-%s", "\(entry.0)", "\(entry.1)")
        }
        UserDefaults.standard.register(defaults: dictionary)
    }

    static func registerDefaults() {
        defaultsList.forEach {
            registerDefaults($0)
        }

        defaultsRegistered = true
        // force the setter on the property to be called
        // so that the UserDefaults.set is called,
        // delivering the UserDefaults.didChangeNotification
        // which will be received by the Music and SFX
        // Coordinators
        var volume = musicVolume
        musicVolume = volume
        volume = effectsVolume
        effectsVolume = volume

        // set the debug settings default people occlusion filter
        // based on table top or full court initially.
        UserSettingsTunables.peopleOcclusion.value = !UserSettings.isTableTop
        os_log(.default, log: GameLog.arFlags,
               "registerDefaults() debug settings peopleOcclusion set to %s",
               "\(UserSettingsTunables.peopleOcclusion.value)")
    }

    static var isTableTop: Bool {
        return gameScale == .tableTop
    }

    static var isFullCourt: Bool {
        return gameScale == .fullCourt
    }

    static func forwardSettingsToSystems() {
    }

}

enum UserDefaultsKeys {
    // not controlled by settings
    static let peerID = "PeerIDDefaults"
}

extension UserDefaults {

    var myself: Player {
        // the current swiftlint generates the following warning if the following line is not here:
        //  Implicit Getter Violation: Computed read-only properties should avoid using the get keyword. (implicit_getter)
        get {
            if let data = data(forKey: UserDefaultsKeys.peerID),
                let unarchived = ((try? NSKeyedUnarchiver.unarchivedObject(ofClass: MCPeerID.self, from: data)) as MCPeerID??),
                let peerID = unarchived {
                return Player(peerID: peerID)
            }
            // if no playerID was previously selected, create and cache a new one.
            let player = Player(username: UIDevice.current.name)
            let newData = try? NSKeyedArchiver.archivedData(withRootObject: player.peerID, requiringSecureCoding: true)
            set(newData, forKey: UserDefaultsKeys.peerID)
            return player
        }
        set {
            let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue.peerID, requiringSecureCoding: true)
            set(data, forKey: UserDefaultsKeys.peerID)
        }
    }

    func register<T>(defaults: [T: Any]) where T: RawRepresentable, T.RawValue == String {
        let dictionary = Dictionary(uniqueKeysWithValues: defaults.map { ($0.0.rawValue, $0.1) })
        register(defaults: dictionary)
    }

    func float<T>(forKey key: T) -> Float where T: RawRepresentable, T.RawValue == String {
        return float(forKey: key.rawValue)
    }

    func set<T>(_ value: Float, forKey key: T) where T: RawRepresentable, T.RawValue == String {
        set(value, forKey: key.rawValue)
    }

}

// MARK: - ARView Configuration from user settings

extension ARView {

    func updateDebugOptions() {
        let newOptions = ARView.DebugOptions(rawValue: UserSettings.arDebugOptions)
        debugOptions = newOptions
    }

    func updateRealityKitRenderOptions(_ peopleOcclusion: Bool) {
        var newOptions = ARView.RenderOptions(rawValue: UInt(UserSettings.rkRenderOptions))

        //
        // Person Occlusion
        // this cannot be combined into the RK Render Options
        // because it has to affect another location in code
        // where ARWorldTrackingConfiguration is setup
        if !peopleOcclusion {
            newOptions.insert(.disablePersonOcclusion)
        }
        os_log(.default, log: GameLog.arFlags, "updateRealityKitRenderOptions(): render options peopleOcclusion = %s", "\(peopleOcclusion)")
        renderOptions = newOptions
    }

    func configureOptions(_ peopleOcclusion: Bool) {
        updateDebugOptions()

        updateRealityKitRenderOptions(peopleOcclusion)
    }

}
