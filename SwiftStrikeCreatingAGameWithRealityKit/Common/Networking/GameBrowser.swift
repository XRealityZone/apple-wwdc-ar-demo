/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Finds games in progress on the local network.
*/

import Foundation
import MultipeerConnectivity
import os.log
import RealityKit

enum GameService {
    static let type = "swiftstrike"
}

enum SwiftStrikeGameAttribute: CaseIterable {
    case appIdentifier
    case buildInfoBundle
    case settingsBundle
    case realityKitNetworkVersion

    init?(value: String) {
        switch value {
        case "0": self = .appIdentifier
        case "1": self = .buildInfoBundle
        case "2": self = .settingsBundle
        case "3": self = .realityKitNetworkVersion
        default: return nil
        }
    }

    var asString: String {
        switch self {
        case .appIdentifier: return "0"
        case .buildInfoBundle: return "1"
        case .settingsBundle: return "2"
        case .realityKitNetworkVersion: return "3"
        }
    }
}

protocol GameBrowserDelegate: AnyObject {
    func gameBrowser(_ browser: GameBrowser, sawGames: [NetworkGame])
    func gameBrowser(_ browser: GameBrowser, presentDialog: ErrorsAlertViewController, animated: Bool, completion: (() -> Void)?)
}

class GameBrowser: NSObject {
    private let myself: Player
    private let serviceBrowser: MCNearbyServiceBrowser
    weak var delegate: GameBrowserDelegate?

    fileprivate var games: Set<NetworkGame> = []

    init(myself: Player) {
        self.myself = myself
        self.serviceBrowser = MCNearbyServiceBrowser(peer: myself.peerID, serviceType: GameService.type)
        super.init()
        self.serviceBrowser.delegate = self
    }

    func start() {
        os_log(.default, log: GameLog.networkConnect, "looking for peers")
        serviceBrowser.startBrowsingForPeers()
    }

    func stop() {
        os_log(.default, log: GameLog.networkConnect, "stopping the search for peers")
        serviceBrowser.stopBrowsingForPeers()
    }

    func join(game: NetworkGame) -> NetworkSession? {
        guard games.contains(game) else {
            os_log(.default, log: GameLog.networkConnect, "Host lost connection")
            return nil
        }

        let titleAndErrors = game.validate()
        guard titleAndErrors == nil else {
            showSettingsErrorsDialog(title: titleAndErrors!.0, titleAndErrors!.1)
            return nil
        }

        // we are going to join the session, to copy the necessary
        // UserSettings from the host to make the connection compatible
        if let errors = game.settingsCopy() {
            showSettingsErrorsDialog(title: "Settings Could Not Be Copied", errors)
            return nil
        }

        let session = NetworkSession(myself: myself, asServer: false, host: game.host, serviceBrowser: serviceBrowser)
        return session
    }
}

/// - Tag: GameBrowser-MCNearbyServiceBrowserDelegate
extension GameBrowser: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        os_log(.default, log: GameLog.networkConnect, "found peer %@", peerID)
        guard peerID != myself.peerID else {
            os_log(.default, log: GameLog.networkConnect, "found myself, ignoring peer")
            return
        }
        guard let info = info else {
            os_log(.error, log: GameLog.networkConnect, "peer not sending config info, ignoring peer")
            return
        }
        guard let appIdentifier = info[SwiftStrikeGameAttribute.appIdentifier.asString] else {
            os_log(.error, log: GameLog.networkConnect, "peer appIdentifier missing, ignoring peer")
            return
        }
        guard let myAppIdentifier = Bundle.main.appIdentifier else {
            os_log(.error, log: GameLog.networkConnect, "cannot get my Bundle.main.appIdentifier to compare, ignoring peer")
            return
        }
        guard appIdentifier == myAppIdentifier else {
            os_log(.error, log: GameLog.networkConnect, "peer appIdentifier %s doesn't match %s, ignoring peer",
                   "\(appIdentifier)",
                   "\(myAppIdentifier)")
            return
        }

        var buildInfoBundle: BuildInfoNetworkBundle?
        if let settingsBase64String = info[SwiftStrikeGameAttribute.buildInfoBundle.asString] {
            buildInfoBundle = BuildInfoNetworkBundle.fromString(base64String: settingsBase64String)
        }

        var realityKitNetworkVersion: NetworkCompatibilityToken?
        if let realityKitNetworkVersionBase64String = info[SwiftStrikeGameAttribute.realityKitNetworkVersion.asString],
        let realityKitNetworkVersionData = Data(base64Encoded: realityKitNetworkVersionBase64String) {
            realityKitNetworkVersion = try? JSONDecoder().decode(NetworkCompatibilityToken.self, from: realityKitNetworkVersionData)
        }

        var settingsBundle: SettingsNetworkBundle?
        if let settingsBase64String = info[SwiftStrikeGameAttribute.settingsBundle.asString] {
            settingsBundle = SettingsNetworkBundle.fromString(base64String: settingsBase64String)
        }

        DispatchQueue.main.async {
            let player = Player(peerID: peerID)
            let game = NetworkGame(host: player,
                                   buildInfoBundle: buildInfoBundle,
                                   settingsBundle: settingsBundle,
                                   networkVersion: realityKitNetworkVersion,
                                   unexpectedValues: info.count != SwiftStrikeGameAttribute.allCases.count)
            self.games.insert(game)
            self.delegate?.gameBrowser(self, sawGames: Array(self.games))
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        os_log(.default, log: GameLog.networkConnect, "lost peer id %@", peerID)
        DispatchQueue.main.async {
            self.games = self.games.filter { $0.host.peerID != peerID }
            self.delegate?.gameBrowser(self, sawGames: Array(self.games))
        }
    }

    func refresh() {
        delegate?.gameBrowser(self, sawGames: Array(games))
    }
}

extension GameBrowser {
    private func showSettingsErrorsDialog(title: String, _ errors: [String], completion: (() -> Void)? = nil) {
        let dialog = ErrorsAlertViewController.createInstanceFromStoryboard(title: title, lines: errors, completion: completion)
        delegate?.gameBrowser(self, presentDialog: dialog, animated: true, completion: nil)
    }
}
