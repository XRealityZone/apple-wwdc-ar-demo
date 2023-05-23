/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Identifies a networked game session.
*/

import os.log
import RealityKit

class NetworkGame: Hashable {
    let name: String
    let host: Player
    private var buildInfo: BuildInfoNetworkBundle?
    private var settings: SettingsNetworkBundle?
    private var networkVersion: NetworkCompatibilityToken?
    private var unexpectedValues: Bool

    private var valid: Bool!

    var settingsValid: Bool {
        if valid == nil {
            valid = validate() == nil
        }
        return valid
    }

    init(host: Player,
         buildInfoBundle: BuildInfoNetworkBundle?,
         settingsBundle: SettingsNetworkBundle?,
         networkVersion: NetworkCompatibilityToken?,
         unexpectedValues: Bool) {
        self.host = host
        self.name = "\(host.username)'s Game"
        self.buildInfo = buildInfoBundle
        self.settings = settingsBundle
        self.networkVersion = networkVersion
        self.unexpectedValues = unexpectedValues
    }

    static func ==(lhs: NetworkGame, rhs: NetworkGame) -> Bool {
        // we do not want to compare settings here as this is done
        // later with a dialog reporting any mismatches
        // for Equitable, we only need the host to match
        return lhs.host == rhs.host
    }

    func hash(into hasher: inout Hasher) {
        name.hash(into: &hasher)
        host.hash(into: &hasher)
    }

    private enum NetworkCompatibility {
        case compatible
        case notCompatible(error: String)
        case unknown(error: String)
    }

    private var networkCompatibility: NetworkCompatibility? {
        guard let networkVersion = networkVersion else {
            return nil
        }
        let compatibility = NetworkCompatibilityToken.local.compatibilityWith(networkVersion)
        switch compatibility {
        case .compatible:
            return .compatible
        case .sessionProtocolVersionMismatch:
            return .notCompatible(error: "version protocol mismatch")
        default:
            return .unknown(error: String(format: "Unknown case %s", "\(compatibility)"))
        }
    }

    func validate() -> (String, [String])? {
        // before joining, make sure our BuildInfo is compatible
        guard let buildInfo = buildInfo else {
            return ("BuildInfo Missing", ["missing network build info bundle"])
        }
        if let errors = buildInfo.compare() {
            return ("BuildInfo Does Not Match", errors)
        }

        // before joining, make sure our RealityKit Network Compatibility is equal
        guard let compatibility = networkCompatibility else {
            return ("RealityKit Network Compatibility", ["missing network compatibility value"])
        }
        switch compatibility {
        case .compatible:
            os_log(.default, log: GameLog.networkConnect, "Found compatible peer.")
        case .notCompatible(let error):
            return ("RealityKit Network Compatibility", [error])
        case .unknown(let error):
            os_log(.error, log: GameLog.networkConnect, "RealityKit Network Compatibility: %s", error)
            return ("RealityKit Network Compatibility Error", [error])
        }

        // before joining, make sure our UserSettings are compatible
        guard let settings = settings else {
            return ("Settings Missing", ["missing network settings bundle"])
        }
        if let errors = settings.compare() {
            return ("Settings Do Not Match", errors)
        }

        // we are going to join the session, to copy the necessary
        // UserSettings from the host to make the connection compatible
        if let errors = settings.compare(mode: .copy) {
            return ("Settings Could Not Be Copied", errors)
        }

        return nil
    }

    func settingsCopy() -> [String]? {
        guard let settings = settings else {
            fatalError("settings were here during validate(), but gone now????")
        }
        return settings.compare(mode: .copy)
    }
}

