/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Manages placing the board, players joining and leaving the game
*/

import ARKit
import Foundation
import os.log
import RealityKit

protocol GameSessionManagerDelegate: AnyObject {
    func gameSessionManager(_ manager: GameSessionManager, joiningPlayer player: Player)
    func gameSessionManager(_ manager: GameSessionManager, leavingPlayer player: Player)
    func gameSessionManager(_ manager: GameSessionManager, joiningHost host: Player)
    func gameSessionManager(_ manager: GameSessionManager, leavingHost host: Player)
    func gameSessionManager(_ manager: GameSessionManager, hasNetworkDelay: Bool)
    func gameSessionManagerDidUnloadLevel(_ manager: GameSessionManager)

    func gameSessionManager(_ manager: GameSessionManager, updatedSession state: GameSessionManager.State)

    func gameSessionManager(_ manager: GameSessionManager, tickTimeDelta timeDelta: TimeInterval)

    func gameSessionManager(_ manager: GameSessionManager, updated mappingStatus: ARFrame.WorldMappingStatus)
    func gameSessionManager(_ manager: GameSessionManager, updated trackingState: ARCamera.TrackingState)
    func gameSessionManager(_ manager: GameSessionManager, failedWith error: Error)

    func gameSessionManagerReady(_ manager: GameSessionManager)

    func gameSessionManagerInterruptedSession(_ manager: GameSessionManager)

    func gameSessionManager(_ manager: GameSessionManager, generatedAlert alert: String)

    func gameSessionManager(_ manager: GameSessionManager, updateDisplayTeam team: Team)
}

enum TouchType {
    case tapped
    case began
    case ended
}

class GameSessionManager: NSObject {
    enum State: Equatable {
        case setup

        // manual board placement:
        case lookingForSurface // finding a suitable plane
        case placingBoard // suitable plane found, adjusting board based on updates to that plane
        case adjustingBoard // user has started manually adjusting the board

        // automated placement:
        case waitingForBoard // waiting for an ARWorldMap
        case localizingToWorldMap(ARWorldMap)
        case localizingCollaboratively(ARWorldMap?)

        // board placed, time to play!
        case gameInProgress

        // exit game to main menu
        case exitGame
    }

    enum Errors: LocalizedError {
        case sessionDisconnectedBeforeLocalization

        var localizedDescription: String {
            return NSLocalizedString("The host disappeared before we were able to localize.",
                                     comment: "Error message for failure during localization process.")
        }
    }

    static let anchorName = "GameBoard"
    private var state: State = .setup {
        didSet {
            guard oldValue != state else { return }
            os_log(.default, log: GameLog.levelLifeCycle, "Changing state from %s to %s", String(describing: oldValue), String(describing: state))
            delegate?.gameSessionManager(self, updatedSession: state)
            arSessionManager.configureARSession(state)
            board.isHidden = !canAdjustBoard
        }
    }
    
    var canAdjustBoard: Bool {
        return state == .placingBoard || state == .adjustingBoard
    }

    private var playManager: GamePlayManager?
    private weak var networkSession: NetworkSession?
    private var level: GameLevel
    private let levelLoader: LevelLoaderProtocol
    private let musicCoordinator: MusicCoordinator
    private let sfxCoordinator: SFXCoordinator
    private let uprightCoordinator: UprightCoordinator
    let entityCache: EntityCache
    private let componentWatcher: ComponentWatcher

    let view: ARView

    private var mapFromFile: Data?

    private let board: GameBoard
    private var anchorIdentifier: UUID? {
        didSet {
            updateBoardAnchor()
        }
    }
    
    private var addedAnchors: [ARAnchor] = []

    private let gestureRecognizer: GameViewGestureRecognizer

    var arSessionManager: ARSessionManager

    var mode: GameMode
    weak var delegate: GameSessionManagerDelegate? {
        didSet {
            delegate?.gameSessionManager(self, updatedSession: state)
        }
    }

    var teamAIsToRightOfCamera: Bool { playManager?.teamAIsToRightOfCamera ?? false }

    init(view: ARView,
         level: GameLevel,
         levelLoader: LevelLoaderProtocol,
         netowrkSession: NetworkSession?,
         musicCoordinator: MusicCoordinator,
         sfxCoordinator: SFXCoordinator,
         uprightCoordinator: UprightCoordinator,
         entityCache: EntityCache,
         componentWatcher: ComponentWatcher) {
        self.view = view
        self.level = level
        self.levelLoader = levelLoader
        self.networkSession = netowrkSession
        self.musicCoordinator = musicCoordinator
        self.sfxCoordinator = sfxCoordinator
        self.uprightCoordinator = uprightCoordinator
        self.entityCache = entityCache
        self.componentWatcher = componentWatcher

        if let networkSession = networkSession {
            self.mode = networkSession.isServer ? .server : .client
            if self.mode == .server {
                self.board = GameBoard(level: level, placementUILoader: levelLoader.placementUILoader)
            } else {
                self.board = GameBoard(level: level, placementUILoader: nil)
            }
            self.state = networkSession.isServer ? .lookingForSurface : .waitingForBoard
        } else {
            self.mode = .solo
            self.board = GameBoard(level: level, placementUILoader: levelLoader.placementUILoader)
            self.state = .lookingForSurface
        }
        view.scene.anchors.append(self.board.anchorEntity)

        self.arSessionManager = ARSessionManager(session: view.session)
        self.gestureRecognizer = GameViewGestureRecognizer()
        super.init()

        arSessionManager.gameSessionManager = self

        arSessionManager.configureARSession(self.state)

        self.networkSession?.delegate = self

        board.isHidden = true

        if let networkSession = networkSession {
            view.scene.synchronizationService = try? MultipeerConnectivityService(session: networkSession.mcSession)
        }
        gestureRecognizer.configure(with: self, levelIsResizable: level.isResizable)
        os_log(.default, log: GameLog.levelLifeCycle, "Adding board to rootNode")
        self.levelLoader.preLoad(level)
        if mode == .client {
            networkSession?.connectToHost()
        }
    }

    func handleTouch(_ touch: TouchType) {
        if state == .placingBoard || state == .adjustingBoard {
            if board.isShowingPlacementUI, touch == .tapped {
                os_log(.default, log: GameLog.levelLifeCycle, "User tapped while placing/adjusting board.")
                boardLocationSelected()
            }
        }
    }

    func fadeIn() {
        board.isHidden = false
    }

    func fadeOut() {
        board.isHidden = true
    }

    func newGame() {
        playManager?.newGame()
    }

    func exitGame() {
        board.reset()
        if let anchor = board.anchor {
            view.session.remove(anchor: anchor)
            board.anchor = nil
        }
        view.scene.anchors.remove(board.anchorEntity)
        view.scene.synchronizationService = nil

        playManager?.exitGame()
        arSessionManager.configureARSession(.exitGame)
        delegate?.gameSessionManager(self, updatedSession: .setup)
        arSessionManager.configureARSession(.setup)
        delegate?.gameSessionManagerDidUnloadLevel(self)
        sfxCoordinator.removeAllAudioEntities()
        levelLoader.reset()
        networkSession?.stopAdvertising()
    }

    func destroy() {
        playManager = nil
    }

    func removeBoardFromPlane() {
        // Only allow this in placing/adjusting state, not after the game has begun.
        guard state == .placingBoard || state == .adjustingBoard else { return }
        
        board.reset()
        addedAnchors.removeAll()
        state = .lookingForSurface
    }

    // MARK: - message handling
    private func process(_ action: BoardSetupAction, from player: Player) {
        switch action {
        case .boardLocation(let description, let levelInfo):
            board.uniformScale = description.scale
            switch description.location {
            case .worldMapData(let data, let uuid):
                os_log(.default, log: GameLog.levelLifeCycle, "Received WorldMap data. Size: %d, uuid: %s", data.count, uuid.uuidString)
                anchorIdentifier = uuid
                loadWorldMap(from: data)
            case .manual:
                os_log(.default, log: GameLog.levelLifeCycle, "Received a manual board placement")
                state = .lookingForSurface
            case .collaborative(let uuid):
                os_log(.default, log: GameLog.levelLifeCycle, "Received collaborative mapping board identifier %s", "\(uuid)")
                anchorIdentifier = uuid
                localizeCollaboratively(nil)
            }
            setLevel(levelInfo)
        case .requestBoardLocation:
            sendWorldTo(player)
        }
    }

    private func setLevel(_ levelName: String) {
        guard let level = levelLoader.level(for: levelName) else {
            os_log(.error, log: GameLog.general, "Unknown level name %s", levelName)
            return
        }
        self.level = level
    }

    // MARK: world map management
    /// Localize to data loaded from local disk.
    func localizeToSavedMapData(_ savedData: Data) {
        mapFromFile = savedData
        loadWorldMap(from: savedData)
    }

    func loadWorldMap(from archivedData: Data) {
        DispatchQueue.global().async {
            do {
                let worldMap = try ARWorldMap.fromData(archivedData)
                DispatchQueue.main.async {
                    os_log(.default, log: GameLog.levelLifeCycle, "received worldMap with anchors %s", "\(worldMap.anchors)")

                    // When loading world map from file need to set the ID for the board anchor explicitly.
                    // When the map comes from the network this is done elsewhere.
                    self.updateBoardAnchor(from: worldMap.anchors)

                    self.localizeToWorldMap(worldMap)
                }
            } catch {
                DispatchQueue.main.async {
                    let alert = NSLocalizedString("An error occured while loading the WorldMap (\(error))",
                        comment: "In game alert shown when something goes wrong.")
                    self.delegate?.gameSessionManager(self, generatedAlert: alert)
                    self.mapExtractionFailed()
                }
            }
        }
    }

    private func sendWorldTo(_ player: Player) {
        let levelName = level.key
        let scale = board.uniformScale
        guard let uuid = board.anchor?.identifier else {
            fatalError("board not placed")
        }
        switch UserSettings.boardLocatingMode {
        case .worldMap:
            sendCurrentWorldMap(to: player, levelName: levelName, scale: scale, uuid: uuid)
        case .manual:
            let description = GameBoardDescription(scale: scale, location: .manual)
            networkSession?.send(action: .boardLocation(description, levelName), to: player)
        case .collaborative:
            if mapFromFile != nil {
                os_log(.default, log: GameLog.levelLifeCycle, "collaborative mapping, sending loaded world map to %s", "\(player)")
                sendCurrentWorldMap(to: player, levelName: levelName, scale: scale, uuid: uuid)
            } else {
                os_log(.default, log: GameLog.levelLifeCycle, "collaborative mapping, sending board UUID %s to %s", "\(uuid)", "\(player)")
                let location = GameBoardLocation.collaborative(uuid)
                let description = GameBoardDescription(scale: scale, location: location)
                networkSession?.send(action: .boardLocation(description, levelName), to: player)
            }
        }
    }

    private func sendCurrentWorldMap(to player: Player, levelName: String, scale: Float, uuid: UUID) {
        os_log(.default, log: GameLog.levelLifeCycle, "generating worldmap for %s", "\(player)")
        requestCurrentWorldMap { (result) in
            switch result {
            case .failure(let error):
                os_log(.error, log: GameLog.general, "didn't work! %s", "\(error)")
                DispatchQueue.main.async {
                    self.delegate?.gameSessionManager(self, failedWith: error as NSError)
                }
            case .success(let data):
                os_log(.default, log: GameLog.levelLifeCycle, "got a compressed map, sending to %s, size %d", "\(player)", data.count)
                let location = GameBoardLocation.worldMapData(data, uuid)
                let description = GameBoardDescription(scale: scale, location: location)
                os_log(.default, log: GameLog.general, "sending worldmap to %s", "\(player)")
                self.networkSession?.send(action: .boardLocation(description, levelName), to: player)
            }
        }

    }

    func requestCurrentWorldMap(closure: @escaping (Result<Data, Error>) -> Void) {
        if let savedMap = mapFromFile {
                closure(.success(savedMap))
        } else {
            arSessionManager.getWorldMapData(closure: closure)
        }
    }

    func localizeToWorldMap(_ map: ARWorldMap) {
        switch UserSettings.boardLocatingMode {
        case .collaborative:
            state = .localizingCollaboratively(map)
        case .worldMap:
            state = .localizingToWorldMap(map)
        default:
            break
        }
    }

    func localizeCollaboratively(_ map: ARWorldMap?) {
        state = .localizingCollaboratively(map)
    }

    func mapExtractionFailed() {
        state = .setup
    }

    // MARK: board placement process/UI
    func hideBoardBorder(duration: TimeInterval = 0.5) {
        board.isShowingPlacementUI = false
    }

    func useDefaultScale() {
        guard canAdjustBoard else { return }
        state = .adjustingBoard
        board.useDefaultScale()
    }

    func scaleBoard(by scale: Float) {
        guard canAdjustBoard else { return }
        state = .adjustingBoard
        board.scale(by: scale)
    }

    func rotateBoard(by rotation: Float) {
        guard canAdjustBoard else { return }
        state = .adjustingBoard
        board.rotationAboutY -= rotation
    }

    private var panOffset = SIMD3<Float>()
    func panStartedAt(_ worldPosition: SIMD3<Float>) {
        guard canAdjustBoard else { return }
        state = .adjustingBoard
        panOffset = worldPosition - board.position
    }

    func panMovedTo(_ worldPosition: SIMD3<Float>) {
        guard canAdjustBoard else { return }
        state = .adjustingBoard
        board.position = worldPosition - panOffset
    }
    
    func anchorAdded(_ anchor: ARAnchor) {
        if anchorIdentifier == nil {
            addedAnchors.append(anchor)
        }
        if anchor.identifier == anchorIdentifier {
            boardAnchorFound(anchor)
        }

        guard let imageAnchor = anchor as? ARImageAnchor else { return }

        //only place the board based on the image if there is a map in an ok state
        if let frame = view.session.currentFrame,
        (frame.worldMappingStatus == .mapped || frame.worldMappingStatus == .extending) {

            board.position = imageAnchor.transform.translation
            // initial rotation is 90 from camera
            board.rotationAboutY = imageAnchor.transform.rotationAboutY - (Float.pi / 2)
            state = .adjustingBoard

            //if a plane anchor already exists place the height of the board to the plane
            view.session.currentFrame?.anchors.forEach { anchor in
                // only use plane whose one dimension is larger than 0.5 m
                if let anchor = anchor as? ARPlaneAnchor, anchor.extent.x > 0.5 || anchor.extent.z > 0.5 {
                    board.position = SIMD3<Float>(board.position.x, anchor.transform.translation.y, board.position.z)
                    return
                }
            }
        } else {
                //if the tracking state was not in a good state remove the
                //image anchor so that the anchor could be added again.
                //Using the didupdate Anchors would be an alternative
                view.session.remove(anchor: imageAnchor)
        }
    }

    func updateBoardAnchor(from anchors: [ARAnchor]) {
        guard let boardAnchor = (anchors.first { $0.name == GameSessionManager.anchorName }) else { return }
        anchorIdentifier = boardAnchor.identifier
    }
    
    func updateBoardAnchor() {
        defer {
            addedAnchors.removeAll()
        }
        guard let boardAnchor = addedAnchors.first(where: { $0.identifier == anchorIdentifier }) else {
            return
        }
        boardAnchorFound(boardAnchor)
    }

    private var screenCenter: CGPoint {
        let bounds = view.bounds
        return CGPoint(x: bounds.midX, y: bounds.midY)
    }

    func update(frame: ARFrame, session: ARSession) {
        // automatically update board when looking for surface or placing board
        // Perform hit testing only when ARKit tracking is in a good state.

        // after the initial placement keep on updating the board height based on
        // the plane anchor updates
        if case .lookingForSurface = state, case .normal = frame.camera.trackingState {
            board.isShowingPlacementUI = true
            board.isHidden = false
            board.orientToCamera(frame.camera)
            board.useMinimumScale()

            if let result = view.raycast(from: screenCenter, allowing: .existingPlaneGeometry, alignment: .horizontal).first {
                // Ignore results that are too close to the camera when initially placing
                let distance = length(result.worldTransform.translation - frame.camera.transform.translation)
                guard distance > 0.5 else { return }
                if let planeAnchor = result.anchor as? ARPlaneAnchor, board.didLookLongEnoughAtPlane(planeAnchor) {
                    state = .placingBoard
                    board.update(with: result, camera: frame.camera)
                }
            }
        } else if canAdjustBoard, case .normal = frame.camera.trackingState {
            //keep updating the board height based on the plane anchor
            if let result = view.raycast(from: screenCenter, allowing: .existingPlaneGeometry, alignment: .horizontal).first,
                let planeAnchor = result.anchor as? ARPlaneAnchor, board.didLookLongEnoughAtPlane(planeAnchor) {
                    // set the full position so that the position setter is called
                    board.position = SIMD3<Float>(board.position.x, planeAnchor.transform.translation.y, board.position.z)
            }
        }
    }

    private func startLevel(_ level: GameLevel, activeLevel: ActiveLevel) {
        let playManager = GamePlayManager(view: view,
                                          level: level,
                                          levelLoader: levelLoader,
                                          netowrkSession: networkSession,
                                          musicCoordinator: musicCoordinator,
                                          sfxCoordinator: sfxCoordinator,
                                          uprightCoordinator: uprightCoordinator,
                                          entityCache: entityCache,
                                          componentWatcher: componentWatcher,
                                          mode: mode)
        playManager.delegate = self
        playManager.startOnBoard(board, activeLevel: activeLevel)
        self.playManager = playManager
        self.playManager?.newGame()
    }

    // the user has selected a location for the board; insert the anchor into
    // the ARSession and hide the UI.
    private func boardLocationSelected() {
        let anchor = ARAnchor(name: GameSessionManager.anchorName, transform: removeScale(board.transform))
        anchorIdentifier = anchor.identifier
        view.session.add(anchor: anchor)

        board.isShowingPlacementUI = false
    }

    // Anchor for the board has been found; set up the level.
    private func boardAnchorFound(_ anchor: ARAnchor) {
        os_signpost(.begin, log: GameLog.setupLevel, name: .setupLevel, signpostID: .setupLevel,
                    "Setting up Level")
        defer { os_signpost(.end, log: GameLog.setupLevel, name: .setupLevel, signpostID: .setupLevel,
                            "Finished Setting Up Level") }
        board.anchor = anchor
        //rotate the VIO world so that it matches the IBL
        if let transform = board.anchor?.transform {
            view.session.setWorldOrigin(relativeTransform: transform)
        }

        GameTime.setLevelStartTime()

        state = .gameInProgress

        guard let activeLevel = levelLoader.activeLevel else {
            fatalError("Active level was not loaded (GameSessionManager).")
        }
        startLevel(level, activeLevel: activeLevel)
    }

    func updateAllPinsStatus() {
        uprightCoordinator.acquireUprightsStatus(entityCache: entityCache)
    }

    func processHostLeaving() {
        switch state {
        case .waitingForBoard, .localizingToWorldMap, .localizingCollaboratively:
            os_log(.error, log: GameLog.levelLifeCycle, "host left while localizing")
            state = .setup
            delegate?.gameSessionManager(self, failedWith: Errors.sessionDisconnectedBeforeLocalization)
        default:
            break
        }
    }
}

// MARK: - NetworkSessionDelegate
extension GameSessionManager: NetworkSessionDelegate {
    func networkSession(_ networkSession: NetworkSession, joining player: Player) {
        if player == networkSession.host {
            // if we're waiting for a map, ask the network session for it
            if state == .waitingForBoard {
                networkSession.send(action: .requestBoardLocation, to: player)
            }
            delegate?.gameSessionManager(self, joiningHost: player)
        } else {
            delegate?.gameSessionManager(self, joiningPlayer: player)
        }
    }

    func networkSession(_ networkSession: NetworkSession, leaving player: Player) {
        DispatchQueue.main.async {
            if player == networkSession.host {
                self.delegate?.gameSessionManager(self, leavingHost: player)
                self.processHostLeaving()
            } else {
                self.delegate?.gameSessionManager(self, leavingPlayer: player)
            }
        }
    }

    func networkSession(_ networkSession: NetworkSession, receivedBoardAction boardAction: BoardSetupAction, from player: Player) {
        process(boardAction, from: player)
    }
}

// MARK: - GamePlayManagerDelegate
extension GameSessionManager: GamePlayManagerDelegate {

    func gamePlayManager(_ manager: GamePlayManager, hasNetworkDelay: Bool) {
        delegate?.gameSessionManager(self, hasNetworkDelay: hasNetworkDelay)
    }

    func gamePlayManagerReady(_ manager: GamePlayManager) {
        delegate?.gameSessionManagerReady(self)
    }

    func gamePlayManager(_ manager: GamePlayManager, tickTimeDelta timeDelta: TimeInterval) {
        delegate?.gameSessionManager(self, tickTimeDelta: timeDelta)
    }

    func gamePlayManager(_ manager: GamePlayManager, updateDisplayTeam team: Team) {
        delegate?.gameSessionManager(self, updateDisplayTeam: team)
    }

}
