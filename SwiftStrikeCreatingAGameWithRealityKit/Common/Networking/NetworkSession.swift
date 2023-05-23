/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Manages the multipeer networking for a game.
*/

import MultipeerConnectivity
import os.log
import os.signpost
import RealityKit

protocol NetworkSessionDelegate: AnyObject {
    func networkSession(_ networkSession: NetworkSession, joining player: Player)
    func networkSession(_ networkSession: NetworkSession, leaving player: Player)
    func networkSession(_ networkSession: NetworkSession, receivedBoardAction boardAction: BoardSetupAction, from player: Player)
}

// kMCSessionMaximumNumberOfPeers is the maximum number in a session; because we only track
// others and not ourself, decrement the constant for our purposes.
private let maxPeers = kMCSessionMaximumNumberOfPeers - 1

/// - Tag: NetworkSession
class NetworkSession: NSObject {

    let myself: Player
    private var peers: Set<Player> = []

    let isServer: Bool
    let mcSession: MCSession
    let host: Player
    let appIdentifier: String

    weak var delegate: NetworkSessionDelegate?

    private var serviceAdvertiser: MCNearbyServiceAdvertiser?
    private var serviceBrowser: MCNearbyServiceBrowser?

    private let decoder = PropertyListDecoder()
    private let encoder = PropertyListEncoder()

    init(myself: Player, asServer: Bool, host: Player, serviceBrowser: MCNearbyServiceBrowser?) {
        // If this is the server, must not pass in a serviceBrowser and vice-versa.
        precondition((serviceBrowser == nil) == asServer, "incorrect initialization")
        self.myself = myself
        mcSession = MCSession(peer: myself.peerID, securityIdentity: nil, encryptionPreference: .required)
        isServer = asServer
        self.host = host
        // if the appIdentifier is missing from the main bundle, that's
        // a significant build error and we should crash.
        appIdentifier = Bundle.main.appIdentifier!
        self.serviceBrowser = serviceBrowser
        os_log(.default, log: GameLog.networkConnect, "my appIdentifier is %s", appIdentifier)
        super.init()
        mcSession.delegate = self
    }

    deinit {
        stopAdvertising()
    }

    func connectToHost() {
        os_log(.default, log: GameLog.networkConnect, "requesting connection to host %s", "\(host)")

        let hostIdentifier = host.peerID
        guard let serviceBrowser = serviceBrowser else {
            fatalError("should have provided service browser")
        }
        serviceBrowser.invitePeer(hostIdentifier, to: mcSession, withContext: nil, timeout: 30)
    }

    // for use when acting as game server
    func startAdvertising() {
        guard serviceAdvertiser == nil else { return } // already advertising

        os_log(.default, log: GameLog.networkConnect, "ADVERTISING %@", myself.peerID)
        let buildInfoString = BuildInfoNetworkBundle.asString()
        let settingsString = SettingsNetworkBundle.asString()
        var realityKitNetworkVersion = ""
        if let data = try? JSONEncoder().encode(NetworkCompatibilityToken.local) {
            realityKitNetworkVersion = data.base64EncodedString()
        }
        let discoveryInfo: [String: String] = [
            SwiftStrikeGameAttribute.appIdentifier.asString: appIdentifier,
            SwiftStrikeGameAttribute.buildInfoBundle.asString: buildInfoString,
            SwiftStrikeGameAttribute.settingsBundle.asString: settingsString,
            SwiftStrikeGameAttribute.realityKitNetworkVersion.asString: realityKitNetworkVersion
        ]
        let totalSpace = discoveryInfo.reduce(0) { sum, value in
            return sum + value.key.count + value.value.count
        }
        os_log(.default, log: GameLog.networkConnect, "Network Discovery %d bytes should be < 300", totalSpace)
        let advertiser = MCNearbyServiceAdvertiser(peer: myself.peerID,
                                                   discoveryInfo: discoveryInfo,
                                                   serviceType: GameService.type)
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        serviceAdvertiser = advertiser
    }

    func stopAdvertising() {
        os_log(.default, log: GameLog.networkConnect, "stop advertising")
        serviceAdvertiser?.stopAdvertisingPeer()
        serviceAdvertiser = nil
    }

    // MARK: Actions
    func send(action: BoardSetupAction) {
        guard !peers.isEmpty else { return }
        do {
            let data = try encoder.encode(action)
            let peerIds = peers.map { $0.peerID }
            try mcSession.send(data, toPeers: peerIds, with: .reliable)
            os_log(.default, log: GameLog.networkPackets, "Sending %s to all (%d bytes)", String(describing: action), data.count)
            os_signpost(.event, log: GameLog.networkDataSent, name: .networkActionSent, signpostID: .networkDataSent,
                        "Action : %s", action.description)
        } catch {
            os_log(.error, log: GameLog.networkConnect, "sending failed: %s", "\(error)")
        }
    }

    func send(action: BoardSetupAction, to player: Player) {
        do {
            let data = try encoder.encode(action)
            os_log(.default, log: GameLog.networkPackets, "Sending %d bytes to %s", data.count, String(describing: player))
            if data.count > 10_000 {
                try sendLarge(data: data, to: player.peerID)
            } else {
                try sendSmall(data: data, to: player.peerID)
            }
            os_log(.default, log: GameLog.networkPackets, "Sending %s to all (%d bytes)", String(describing: action), data.count)
            os_signpost(.event, log: GameLog.networkDataSent, name: .networkActionSent, signpostID: .networkDataSent,
                        "Action : %s", action.description)
        } catch {
            os_log(.error, log: GameLog.networkConnect, "sending failed: %s", "\(error)")
        }
    }

    func sendSmall(data: Data, to peer: MCPeerID) throws {
        try mcSession.send(data, toPeers: [peer], with: .reliable)
    }

    func sendLarge(data: Data, to peer: MCPeerID) throws {
        let fileName = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try data.write(to: fileName)
        mcSession.sendResource(at: fileName, withName: "Action", toPeer: peer) { error in
            if let error = error {
                os_log(.error, log: GameLog.networkConnect, "sending failed: %s", "\(error)")
                return
            }
            os_log(.default, log: GameLog.networkConnect, "send succeeded, removing temp file")
            do {
                try FileManager.default.removeItem(at: fileName)
            } catch {
                os_log(.error, log: GameLog.networkConnect, "removing failed: %s", "\(error)")
            }
        }
    }

    func receive(data: Data, from peerID: MCPeerID) {
        guard let player = peers.first(where: { $0.peerID == peerID }) else {
            os_log(.default, log: GameLog.networkConnect, "peer %@ unknown!", peerID)
            return
        }
        do {
            let decoder = PropertyListDecoder()
            let action = try decoder.decode(BoardSetupAction.self, from: data)
            dispatch(action, from: player)
            os_log(.debug, log: GameLog.networkPackets, "Received %s from %s", String(describing: action), String(describing: player))
            os_signpost(.event, log: GameLog.networkDataReceived, name: .networkActionReceived, signpostID: .networkDataReceived,
                        "Action : %s", action.description)
        } catch {
            os_log(.error, log: GameLog.networkConnect, "deserialization error: %s", "\(error)")
        }
    }

    private func dispatch(_ action: BoardSetupAction, from player: Player) {
        delegate?.networkSession(self, receivedBoardAction: action, from: player)
    }
}

/// - Tag: NetworkSession-MCSessionDelegate
extension NetworkSession: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        os_log(.default, log: GameLog.networkConnect, "MCSessionDelegate - peer %@ state is now %d", peerID, state.rawValue)
        let player = Player(peerID: peerID)
        switch state {
        case .connected:
            peers.insert(player)
            delegate?.networkSession(self, joining: player)
        case .connecting:
            break
        case.notConnected:
            peers.remove(player)
            delegate?.networkSession(self, leaving: player)
        @unknown default:
            break
        }
        // on the server, check to see if we're at the max number of players
        guard isServer else { return }
        if peers.count >= maxPeers {
            stopAdvertising()
        } else {
            startAdvertising()
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        os_log(.default, log: GameLog.networkPackets, "MCSessionDelegate - received data, %d bytes, from peer %@", data.count, peerID)
        receive(data: data, from: peerID)
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        os_log(.default, log: GameLog.networkConnect, "MCSessionDelegate - received stream '%s' from peer %@", streamName, peerID)
    }

    func session(_ session: MCSession,
                 didStartReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID,
                 with progress: Progress) {
        os_log(.default, log: GameLog.networkConnect, "MCSessionDelegate - receiving resource '%s' from peer %@", resourceName, peerID)
    }

    func session(_ session: MCSession,
                 didFinishReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        os_log(.default, log: GameLog.networkConnect, "MCSessionDelegate - done receiving resource '%s' from peer %@", resourceName, peerID)
        if let error = error {
            os_log(.error, log: GameLog.networkConnect, "MCSessionDelegate - failed to receive, error: '%s'", "\(error)")
            return
        }
        guard let url = localURL else {
            os_log(.error, log: GameLog.networkConnect, "MCSessionDelegate - what what no url?")
            return
        }

        do {
            // .mappedIfSafe makes the initializer attempt to map the file directly into memory
            // using mmap(2), rather than serially copying the bytes into memory.
            // this is faster and our app isn't charged for the memory usage.
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            receive(data: data, from: peerID)
            // removing the file is done by the session, so long as we're done with it before the
            // delegate method returns.
        } catch {
            os_log(.error, log: GameLog.networkConnect, "MCSessionDelegate - dealing with resource failed: '%s'", "\(error)")
        }
    }
}

extension NetworkSession: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        os_log(.error, log: GameLog.networkConnect, "MCNearbyServiceAdvertiserDelegate - didNotStartAdvertisingPeer: %s", "\(error)")
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        os_log(.default, log: GameLog.networkConnect, "MCNearbyServiceAdvertiserDelegate - invitation from %@", peerID)
        if peers.count >= maxPeers {
            os_log(.error, log: GameLog.networkConnect, "MCNearbyServiceAdvertiserDelegate - game full, refusing connection", peerID)
            invitationHandler(false, nil)
        } else {
            os_log(.default, log: GameLog.networkConnect, "MCNearbyServiceAdvertiserDelegate - accepting invitation from %@", peerID)
            invitationHandler(true, mcSession)
        }
    }
}

