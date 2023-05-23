/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Asset loading
*/

import Foundation

struct AssetToLoad: EntityToLoad {
    var asset: Asset

    var key: Asset.Options
    var filename: String { return Asset.name(for: asset, options: key) }

    init(for asset: Asset, options: Asset.Options) {
        self.asset = asset
        self.key = options
    }
}

enum Asset {

    struct Options: OptionSet, Hashable {
        let rawValue: Int
        static let none = Options([])
        static let cosmic = Options(rawValue: 1 << 0)
        static let noGutter = Options(rawValue: 1 << 1)
        static let transparent = Options(rawValue: 1 << 2)
        static let unlit = Options(rawValue: 1 << 3)
        static let tabletop = Options(rawValue: 1 << 4)

        // Reserve 2 bits @ bit 8 for BeamOfLightState (shift rawValue by 8)
        static let ready = Options(rawValue: BeamOfLightEntity.State.ready.rawValue << 8)
        static let waiting = Options(rawValue: BeamOfLightEntity.State.waiting.rawValue << 8)

        // Reserve remaining bits @ bit 16 for teams (plenty of room for more teams) (shift rawValue by 16)
        static let teamA = Options(rawValue: Team.teamA.intValue << 16)
        static let teamB = Options(rawValue: Team.teamB.intValue << 16)
    }

    case ball
    case pin
    case court
    case ibl
    case winnerSign
    case drawSign
    case strikeSign
    case startLightsBeam
    case startLightsGlow
    case striker
    case person
    case target

    static func optionsConditionalCombine(_ options: Options = [], _ useModifier: Bool, _ modifiers: Options = []) -> Options {
        guard useModifier else { return options }
        return options.union(modifiers)
    }

    static func name(for asset: Asset, options: Options = []) -> String {
        var opt = options
        if UserSettings.visualMode == .cosmic {
            opt.insert(.cosmic)
        }
        switch (asset, opt) {

        // Ball
        case (.ball, []):
            return "ballA"
        case (.ball, [.cosmic]):
            return "ballA_cosmic"

        // Pins
        case (.pin, [.teamA]):
            return "pinA_physics"
        case (.pin, [.teamA, .cosmic]):
            return "pinA_cosmic_physics"
        case (.pin, [.teamA, .transparent]):
            return "pinA_transp"
        case (.pin, [.teamA, .transparent, .cosmic]):
            return "pinA_cosmic_transp"
        case (.pin, [.teamA, .unlit, .cosmic]):
            return "pinA_cosmic_off"
        case (.pin, [.teamA, .unlit, .transparent, .cosmic]):
            return "pinA_cosmic_off_transp"
        case (.pin, [.teamB]):
            return "pinB_physics"
        case (.pin, [.teamB, .cosmic]):
            return "pinB_cosmic_physics"
        case (.pin, [.teamB, .transparent]):
            return "pinB_transp"
        case (.pin, [.teamB, .transparent, .cosmic]):
            return "pinB_cosmic_transp"
        case (.pin, [.teamB, .unlit, .cosmic]):
            return "pinB_cosmic_off"
        case (.pin, [.teamB, .unlit, .transparent, .cosmic]):
            return "pinB_cosmic_off_transp"

        // Court
        case (.court, []):
            return "courtA"
        case (.court, [.cosmic]):
            return "courtA_cosmic"

        // IBL
        case (.ibl, []):
            return "WWDC_2019_Daytime"
        case (.ibl, [.cosmic]):
            return "WWDC_2019_Cosmic"
        case (.ibl, [.tabletop]):
            return "generic_studioKeyFill"
        case (.ibl, [.tabletop, .cosmic]):
            return "generic_studioKeyFill_cosmic"

        // Signs
        case (.winnerSign, []), (.winnerSign, [.cosmic]):
            return "neonWinner"
        case (.strikeSign, []), (.strikeSign, [.cosmic]):
            return "neonStrike_scale"
        case (.drawSign, []), (.drawSign, [.cosmic]):
            return "neonDraw"

        // Start Lights
        case (.startLightsBeam, [.waiting]), (.startLightsBeam, [.waiting, .cosmic]):
            return "startLights_standing_waiting"
        case (.startLightsBeam, [.ready]), (.startLightsBeam, [.ready, .cosmic]):
            return "startLights_standing_ready"
        case (.startLightsBeam, [.waiting, .tabletop]), (.startLightsBeam, [.waiting, .cosmic, .tabletop]):
            return "startLights_tabletop_waiting"
        case (.startLightsBeam, [.ready, .tabletop]), (.startLightsBeam, [.ready, .cosmic, .tabletop]):
            return "startLights_tabletop_ready"
        case (.startLightsGlow, [.waiting]), (.startLightsGlow, [.waiting, .cosmic]):
            return "startLights_arrowA1floorGlow_waiting"
        case (.startLightsGlow, [.ready]), (.startLightsGlow, [.ready, .cosmic]):
            return "startLights_arrowA1floorGlow_ready"

        // Table Top Remote
        case (.striker, [.none]):
            return "paddle_airhockey"
        case (.striker, [.teamA]):
            return "paddle_airhockeyA"
        case (.striker, [.teamB]):
            return "paddle_airhockeyB"
        case (.striker, [.none, .cosmic]):
            return "paddle_airhockey_cosmic"
        case (.striker, [.teamA, .cosmic]):
            return "paddle_airhockeyA_cosmic"
        case (.striker, [.teamB, .cosmic]):
            return "paddle_airhockeyB_cosmic"

        // Table Top Target
        case (.target, [.none]):
            return "paddle_Indicator"
        case (.target, [.teamA]):
            return "paddle_IndicatorA"
        case (.target, [.teamB]):
            return "paddle_IndicatorB"
        case (.target, [.none, .cosmic]):
            return "paddle_Indicator_cosmic"
        case (.target, [.teamA, .cosmic]):
            return "paddle_IndicatorA_cosmic"
        case (.target, [.teamB, .cosmic]):
            return "paddle_IndicatorB_cosmic"

        // Failure
        default:
            fatalError("Invalid asset \(asset) / \(options)")
        }
    }

    static func url(for asset: Asset, options: Options = []) -> URL {
        let name = self.name(for: asset, options: options)
        guard let url = Bundle.main.url(forResource: name, withExtension: "usdz") else {
            fatalError("Asset could not be located")
        }
        return url
    }

}
