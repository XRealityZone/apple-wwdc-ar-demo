/*
See LICENSE folder for this sample’s licensing information.

Abstract:
GameViewController Debug menu
*/

import os.log
import RealityKit
import UIKit

enum DebugSettingsVariables {
    static var effectsVolumeBeep: ButtonBeep!
}

extension GameViewController {

    func debugHook() {
        configureDebug()
    }

    private func fieldEntity() -> FieldEntity? {
        guard let levelEntity = levelLoader.activeLevel?.content else { return nil }
        return levelEntity.findEntity(named: "Field")! as? FieldEntity
    }

    func configureDebug() {
        print("Configuring Debug", to: &logViewStream)
        var prototypes: [DebugSettingPrototype] = []

        prototypes += [
            DebugSettingPrototype(title: "Force Field Control", kind: .section),
            DebugSettingPrototype(RadiatingForceFieldTunables.leafBlowerEnable) {
                UserSettings.enablePaddleLeafBlower = RadiatingForceFieldTunables.leafBlowerEnable.value
            },
            DebugSettingPrototype(RadiatingForceFieldTunables.kickEnable) {
                UserSettings.enablePaddleKick = RadiatingForceFieldTunables.kickEnable.value
            }
        ]

        prototypes += [
            DebugSettingPrototype(title: "Game State Control", kind: .section),
            DebugSettingPrototype(title: "Force Start Game/Launch Ball", kind: .action({
                NotificationCenter.default.post(name: .forceStartSelected, object: nil)
            })),
            DebugSettingPrototype(title: "Force Ball In Gutter", kind: .action({
                NotificationCenter.default.post(name: .forceBallInGutter, object: nil)
            })),
            DebugSettingPrototype(title: "Force End Game", kind: .action({
                NotificationCenter.default.post(name: .forceEndSelected, object: nil)
            }))
        ]

        prototypes += [
            DebugSettingPrototype(title: "Debug Custom Views", kind: .section),
            userDefaultsSettingBool(title: "Debug Pin Status View",
                                    userDefaultsKey: UserSettings.$debugPinStatusView) { [weak self] newValue in
                guard let self = self else { return }
                self.realityView.pinStatusView.enableDebug = newValue
                self.realityView.rightPinStatusView.enableDebug = newValue
                self.realityView.leftPinStatusView.enableDebug = newValue
            },
            userDefaultsSettingBool(title: "Debug Countdown Timer View",
                                    userDefaultsKey: UserSettings.$debugCountdownTimerView) { [weak self] newValue in
                    guard let self = self else { return }
                    self.realityView.countdownTimerView.enableDebug = newValue
            }
        ]

        prototypes += [
            userDefaultsSettingBool(title: "Enable Pew-pew",
                                    userDefaultsKey: UserSettings.$enablePewPew),
            DebugSettingPrototype(title: "Clear Pew-pew", kind: .action({ [weak self] in
                guard let self = self else { return }
                guard let fieldEntity = self.fieldEntity() else { return }
                fieldEntity.removeAllPewPew()
            }))
        ]

        prototypes += [
            DebugSettingPrototype(title: "AR Environment Settings", kind: .section),
            userDefaultsSettingBool(title: "Use Image-Based Lighting",
                                    userDefaultsKey: UserSettings.$useIbl) { [weak self] _ in
                                        self?.configureIbl()
            },
            DebugSettingPrototype(key: "lightingIntensityExponent",
                                  title: "Light Intensity Exponent",
                                  kind: .slider(minValue: 0.0, maxValue: 3.0),
                                  defaultValue: UserSettings.lightingIntensity
            ) { [weak self] newValue in
                UserSettings.lightingIntensity = newValue
                self?.realityView.environment.lighting.intensityExponent = UserSettings.lightingIntensity
            },
            DebugSettingPrototype(title: "Toggle Shadow Light", kind: .action({ [weak self] in
                guard let self = self else { return }
                guard let levelEntity = self.levelLoader.activeLevel?.content else { return }
                let light = levelEntity.findEntity(named: "shadowCastingLight")
                light?.isEnabled.toggle()
            }))
        ]

        prototypes += [
            DebugSettingPrototype(title: "Debug", kind: .section),
            DebugSettingPrototype(title: "Crash", kind: .action({ [weak self] in
                self?.dump()
                fatalError()
            })),
            DebugSettingPrototype(title: "Dump()", kind: .action({ [weak self] in
                self?.dump()
            }))
        ]

        prototypes += [
            DebugSettingPrototype(title: "Animation Tests", kind: .section),
            DebugSettingPrototype(title: "Play Winner", kind: .action({
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                    var note = Notification(name: FieldEntity.winnerNotificationName)
                    note.object = Team.teamA
                    NotificationCenter.default.post(note)
                }
            })),
            DebugSettingPrototype(title: "Play Draw", kind: .action({
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                    let note = Notification(name: FieldEntity.drawNotificationName)
                    NotificationCenter.default.post(note)
                }
            }))
        ]

        prototypes += [
            userDefaultsSettingBool(title: "Show Thermal State",
                                    userDefaultsKey: UserSettings.$showThermalState)
        ]

        prototypes += [
            userDefaultsSettingBool(title: "Show Collaborative Mapping State",
                                    userDefaultsKey: UserSettings.$showTrackingState) { [weak self] _ in
                                        self?.configureTrackingState()
            },
            userDefaultsSettingBool(title: "Show Collaborative Mapping Debug",
                                    userDefaultsKey: UserSettings.$showCollabMappingDebug) { [weak self] _ in
                                        self?.configureCollaborativeMapping()
            }
        ]

        prototypes += [
            tunableSetting(tunableBool: UserSettingsTunables.peopleOcclusion, name: "peopleOcclusion") { [weak self] _ in
                guard let self = self else { return }
                self.gameSessionManager?.arSessionManager.updatePeopleOcclusion()
                let peopleOcclusion = self.gameSessionManager?.arSessionManager.configuration.peopleOcclusion ?? false
                self.realityView.updateRealityKitRenderOptions(peopleOcclusion)
            },
            userDefaultsSettingBool(title: "Enable AR Auto Focus",
                                    userDefaultsKey: UserSettings.$enableARAutoFocus) { [weak self] _ in
                                        self?.gameSessionManager?.arSessionManager.enableAutoFocus(UserSettings.enableARAutoFocus)
            },
            userDefaultsSettingBool(title: "Show AR Mapping State",
                                    userDefaultsKey: UserSettings.$showARMappingState) { [weak self] _ in
                                        self?.updateMappingUI()
            }
        ]

        func arViewDebugSetControlEntry(_ label: String, _ arViewDebugOption: ARView.DebugOptions) -> OptionSetControl.MapEntry {
            let optionSetRawValue = OptionSetControl.RawValue(arViewDebugOption.rawValue)
            return OptionSetControl.MapEntry(label, optionSetRawValue)
        }

        let arViewDebugOptionsMap = [
            arViewDebugSetControlEntry("Physics Debug", .showPhysics),
            arViewDebugSetControlEntry("Statistics", .showStatistics),
            arViewDebugSetControlEntry("World Origin", .showWorldOrigin),
            arViewDebugSetControlEntry("Anchor Origins", .showAnchorOrigins),
            arViewDebugSetControlEntry("Anchor Geometry", .showAnchorGeometry),
            arViewDebugSetControlEntry("Feature Points", .showFeaturePoints)
        ]

        prototypes += [
            DebugSettingPrototype(key: "ARDebugOptions",
                                  title: "AR Debug Options",
                                  cellHeight: 140,
                                  config: OptionSetControl.Config(options: UserSettings.arDebugOptions,
                                                                  map: arViewDebugOptionsMap,
                                                                  buttonsPerColumn: 3)
            ) { [weak self] newOptions in
                UserSettings.arDebugOptions = newOptions
                guard let arView = self?.realityView else { return }
                arView.updateDebugOptions()
            }
        ]

        prototypes += [
            DebugSettingPrototype(key: "musicValume",
                                  title: "Music Volume",
                                  kind: .slider(minValue: 0.0, maxValue: 1.0),
                                  defaultValue: UserSettings.musicVolume
            ) { newValue in
                UserSettings.musicVolume = newValue
            },
            DebugSettingPrototype(key: "effectsValume",
                                  title: "Effects Volume",
                                  kind: .slider(minValue: 0.0, maxValue: 1.0),
                                  defaultValue: UserSettings.effectsVolume,
                                  controlWasReleased: {
                                    if DebugSettingsVariables.effectsVolumeBeep == nil {
                                        DebugSettingsVariables.effectsVolumeBeep = ButtonBeep(name: "Crowd_Cheer_Mono_050819_02.wav",
                                                                       volume: UserSettings.effectsVolume)
                                    }
                                    DebugSettingsVariables.effectsVolumeBeep.play()
                                  }) { newValue in
                                    UserSettings.effectsVolume = newValue
            },
            DebugSettingPrototype(key: "enableReverb",
                                  title: "Enable Reverb",
                                  kind: .checkbox,
                                  defaultValue: UserSettings.enableReverb
            ) { [weak self] newValue in
                UserSettings.enableReverb = Bool(newValue)
                guard let self = self else { return }
                if UserSettings.enableReverb {
                     // use reverb only for player hand held devices...
                    self.realityView.environment.reverb = .preset(.smallRoom)
                 } else {
                    self.realityView.environment.reverb = .noReverb
                 }
            }
        ]

        prototypes += [
            DebugSettingPrototype(RendererQualityControlTunable.powerManagementEnabled)
        ]

        func rkRenderOptionSetControlEntry(_ label: String, _ rkRenderOption: ARView.RenderOptions) -> OptionSetControl.MapEntry {
            let optionSetRawValue = OptionSetControl.RawValue(rkRenderOption.rawValue)
            return OptionSetControl.MapEntry(label, optionSetRawValue)
        }

        let rkRenderOptionsMap = [
            /// Disable the image noise effect.
            rkRenderOptionSetControlEntry("Disable Camera Grain", .disableCameraGrain),
            /// Disable rendering of ambient occlusion and shadows that ground objects in an AR scene.
            rkRenderOptionSetControlEntry("Disable Grounding Shadows", .disableGroundingShadows),
            /// Disable motion blur for all virtual content.
            rkRenderOptionSetControlEntry("Disable Motion Blur", .disableMotionBlur),
            /// Disable depth of field for all virtual content.
            rkRenderOptionSetControlEntry("Disable Depth Of Field", .disableDepthOfField),
            /// Disable HDR.
            rkRenderOptionSetControlEntry("Disable HDR", .disableHDR),
            /// Disables automatic face occlusion. (By default, ARKit detects users and hides virtual
            /// objects behind a user's face.)
            rkRenderOptionSetControlEntry("Disable AR Environment Lighting", .disableAREnvironmentLighting)
        ]

        prototypes += [
            DebugSettingPrototype(key: "RKRenderOptions",
                                  title: "RealityKit Render Options",
                                  config: OptionSetControl.Config(options: OptionSetControl.RawValue(UserSettings.rkRenderOptions),
                                                                  map: rkRenderOptionsMap,
                                                                  buttonsPerColumn: 7)
            ) { [weak self] newOptions in
                UserSettings.rkRenderOptions = UInt(newOptions)
                guard let arView = self?.realityView else { return }
                let peopleOcclusion = self?.gameSessionManager?.arSessionManager.configuration.peopleOcclusion ?? false
                arView.updateRealityKitRenderOptions(peopleOcclusion)
            }
        ]

        DebugSettings.shared.setPrototypes(prototypes)
    }

    func dump() {
        print("Dumping realityView tree", to: &logViewStream)
        realityView.scene.anchors.forEach {
            let dumpLog = $0.dump()
            os_log(.default, log: GameLog.general, "DUMP:\n%@", dumpLog)
        }
        bannerManager?.setBanner(text: "Anchors dumped to console", for: .notification, persistent: false)
    }

    private func tunableSetting(tunableBool: TunableBool,
                                name: String,
                                completion: ((_ newValue: Bool) -> Void)? = nil) -> DebugSettingPrototype {
        return DebugSettingPrototype(tunableBool) { [weak self] in
            guard let self = self else { return }
            if let completion = completion {
                completion(tunableBool.value)
            }
            os_log(.default, log: GameLog.debugSettings, "debug setting %s set to %s", "\(name)", "\(tunableBool.value)")
            self.bannerManager?.setBanner(text: "\(name) changed to \(tunableBool.value)", for: .notification, persistent: false)
        }
    }

    private func userDefaultsSettingBool(title: String,
                                         userDefaultsKey: String,
                                         completion: ((_ newValue: Bool) -> Void)? = nil) -> DebugSettingPrototype {
        let value = UserSettings.getBool(forKey: userDefaultsKey)
        return DebugSettingPrototype(key: title, title: title, kind: .checkbox, defaultValue: value) { [weak self] newValue in
            guard let self = self else { return }
            UserSettings[userDefaultsKey] = newValue
            if let completion = completion {
                completion(newValue)
            }
            self.bannerManager?.setBanner(text: "\(title) changed to \(newValue)", for: .notification, persistent: false)
        }
    }

    private func userDefaultsSettingInt(title: String,
                                        userDefaultsKey: String,
                                        tunable: TunableScalar<Int>,
                                        completion: ((_ newValue: Int) -> Void)? = nil) -> DebugSettingPrototype {
        return DebugSettingPrototype(tunable) { [weak self] in
            guard let self = self else { return }
            let newValue = tunable.value
            UserSettings[userDefaultsKey] = newValue
            if let completion = completion {
                completion(Int(newValue))
            }
            self.bannerManager?.setBanner(text: "\(title) changed to \(newValue)", for: .notification, persistent: false)
        }
    }

}
