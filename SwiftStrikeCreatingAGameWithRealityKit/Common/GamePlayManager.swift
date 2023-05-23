/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Responsible for tracking the state of the game: which objects are where, who's in the game, etc.
*/

import AVFoundation
import Combine
import GameplayKit
import os.signpost
import RealityKit

protocol GamePlayManagerDelegate: AnyObject {
    func gamePlayManager(_ manager: GamePlayManager, hasNetworkDelay: Bool)
    func gamePlayManagerReady(_ manager: GamePlayManager)
    func gamePlayManager(_ manager: GamePlayManager, tickTimeDelta timeDelta: TimeInterval)
    func gamePlayManager(_ manager: GamePlayManager, updateDisplayTeam team: Team)
}

enum GameMode {
    case server
    case client
    case solo
}

/// - Tag: GamePlayManager
class GamePlayManager: NSObject {

    static let scaleNodeName = "PhysicsOrigin"

    // Interactions with the scene and the resources it owns, like nodes being rendered, should only happen in
    // the render loop callbacks below.
    private var level: GameLevel
    private let levelLoader: LevelLoaderProtocol
    private weak var levelAnchor: AnchorEntity?
    private weak var cameraAnchor: AnchorEntity?

    // scene is loaded into the view
    private let view: ARView
    private var gameBoard: GameBoard?

    private weak var networkSession: NetworkSession?
    private let musicCoordinator: MusicCoordinator
    private let sfxCoordinator: SFXCoordinator
    private let uprightCoordinator: UprightCoordinator
    let entityCache: EntityCache
    private let componentWatcher: ComponentWatcher

    let collisionEventPublisher: AnyPublisher<CollisionEvent, Never>
    let sceneEventPublisher: AnyPublisher<SceneEvents.Update, Never>

    private let currentPlayer = UserDefaults.standard.myself

    let mode: GameMode
    var isServer: Bool {
        return mode != .client
    }

    static weak var physicsOrigin: Entity?

    weak var delegate: GamePlayManagerDelegate?

    // We want to ensure we don't try to run renderer callback methods until our game state
    // is fully set up.
    private var readyForRendering = false

    private weak var myPlayerAnchor: AnchorEntity?
    private weak var myPlayerLocationEntity: PlayerLocationEntity?
    private static weak var myRemoteEntity: RemoteEntity?
    private weak var myTargetEntity: TargetEntity?

    private var playerDeviceUUIDsServer: [UUID] = []
    private var playerDeviceUUIDs: [UUID] = []

    private var cancellables: [AnyCancellable] = []

    private(set) var teamAIsToRightOfCamera: Bool = false

    static var localRemoteEntity: RemoteEntity? { return myRemoteEntity }

    init(view: ARView,
         level: GameLevel,
         levelLoader: LevelLoaderProtocol,
         netowrkSession: NetworkSession?,
         musicCoordinator: MusicCoordinator,
         sfxCoordinator: SFXCoordinator,
         uprightCoordinator: UprightCoordinator,
         entityCache: EntityCache,
         componentWatcher: ComponentWatcher,
         mode: GameMode) {
        // we will replace the scene of the sceneView
        self.view = view
        self.level = level
        self.levelLoader = levelLoader
        self.networkSession = netowrkSession
        self.musicCoordinator = musicCoordinator
        self.sfxCoordinator = sfxCoordinator
        self.uprightCoordinator = uprightCoordinator
        self.entityCache = entityCache
        self.componentWatcher = componentWatcher
        self.mode = mode

        let cameraAnchor = AnchorEntity(.camera)
        cameraAnchor.addChild(sfxCoordinator.cameraLockedEntity)
        view.scene.addAnchor(cameraAnchor)
        self.cameraAnchor = cameraAnchor

        let began = view.scene.publisher(for: CollisionEvents.Began.self).map(CollisionEvent.began)
        let update = view.scene.publisher(for: CollisionEvents.Updated.self).map(CollisionEvent.updated)
        let ended = view.scene.publisher(for: CollisionEvents.Ended.self).map(CollisionEvent.ended)
        collisionEventPublisher = began.merge(with: update, ended).eraseToAnyPublisher()
        sceneEventPublisher = view.scene.publisher(for: SceneEvents.Update.self).eraseToAnyPublisher()

        super.init()

        collisionEventPublisher
            .sink(receiveValue: sfxCoordinator.collisionReceiver)
            .store(in: &self.cancellables)
    }

    // Get access to the camera transform
    var cameraTransform: Transform { view.cameraTransform }

    // only do this after we unpause the level
    private func initDelegates() {
        sceneEventPublisher
            .sink { [weak self] (event) in
                self?.update(timeDelta: event.deltaTime)
            }
            .store(in: &self.cancellables)

        // SwiftStrike Paddle leaf blower force effect and kick effect
        collisionEventPublisher
            .sink { (event) in
                event.applyRadiatingForceOnColliders()
            }
            .store(in: &self.cancellables)

        readyForRendering = true
        startMatch()
    }

    func startMatch() {
        delegate?.gamePlayManagerReady(self)
    }

    private func removeSubscribers() {
        cancellables = []
        readyForRendering = false
    }

    private func endGame() {
        removeSubscribers()

        myPlayerLocationEntity?.removeFromParent()
        myTargetEntity?.removeFromParent()
        GamePlayManager.myRemoteEntity?.removeFromParent()
        view.physicsOrigin?.removeFromParent()
        sfxCoordinator.cameraLockedEntity.removeFromParent()

        myPlayerAnchor?.removeFromParent()      // removes myPlayerLocationEntity as well, because it is a child
        levelAnchor?.removeFromParent()
        cameraAnchor?.removeFromParent()

        playerDeviceUUIDsServer = []
        playerDeviceUUIDs = []
    }

    // MARK: update
    // Called from rendering loop once per frame
    /// - Tag: GamePlayManager-update
    private func update(timeDelta: TimeInterval) {
        os_signpost(.begin, log: GameLog.renderLoop, name: .logicUpdate, signpostID: .renderLoop,
                    "Game logic update started")
        defer { os_signpost(.end, log: GameLog.renderLoop, name: .logicUpdate, signpostID: .renderLoop,
                            "Game logic update finished") }

        GameTime.updateAtTime(time: timeDelta)
        createPlayerEntitiesAsNeeded()
        moveOwnedEntities()
        updateOtherEntities(timeDelta)
        processStandUprightEntities()
        processBillboardEntities()
        // must update TeamA relative to camera before calling GamePlayManager delegate
        updateTeamAIsToRightOfCamera()
        delegate?.gamePlayManager(self, tickTimeDelta: timeDelta)
        sfxCoordinator.update(timeDelta: timeDelta)
        uprightCoordinator.updateUprightEntities(entityCache: entityCache)

        KinematicVelocityManager.update(timeDelta: timeDelta)
        componentWatcher.tick()
    }

    func playerLocationEntityFromId(id: UUID) -> PlayerLocationEntity? {
        // PlayerLocationEntities are the first children of an anchor
        // in the scene
        for anchor in view.scene.anchors {
            for entity in anchor.children where entity is PlayerLocationEntity {
                guard let playerLocationEntity = entity as? PlayerLocationEntity else { continue }

                if playerLocationEntity.deviceUUID == id {
                    return playerLocationEntity
                }
            }
        }
        return nil
    }

    func remoteEntityFromId(id: UUID) -> RemoteEntity? {
        // RemoteEntities are the first children of the physics origin
        guard let root = GamePlayManager.physicsOrigin else { return nil }

        for child in root.children where child is RemoteEntity {
            guard let remoteEntity = child as? RemoteEntity else { continue }

            if remoteEntity.deviceUUID == id {
                return remoteEntity
            }
        }
        return nil
    }

    func targetEntityFromId(id: UUID) -> TargetEntity? {
        // RemoteEntities are the first children of the physics origin
        guard let root = GamePlayManager.physicsOrigin else { return nil }

        for child in root.children where child is TargetEntity {
            guard let targetEntity = child as? TargetEntity else { continue }

            if targetEntity.deviceUUID == id {
                return targetEntity
            }
        }
        return nil
    }

    private func createPlayerEntitiesAsNeeded() {
        // For any given PlayerLocationEntity, we must have various
        // player entities that are created/owned
        // by the host/server.  This work should really only need
        // to be done when a new PlayerLocationEntity is
        // added to the scene either locally, or from the
        // network.  However, we don't actually get an event
        // for Entities being added to the sceen, so we need
        // to poll.  Once the game has entered the "waitForBallDrop"
        // state, no new players can "join" and therefore no new
        // PlayerLocationEntity can be added to scene.  Once this
        // occurs, we could stop the polling.
        if isServer {
            view.scene.anchors.forEach { anchor in
                guard !anchor.children.isEmpty,
                    let playerLocationEntity = anchor.children[0] as? PlayerLocationEntity,
                    playerLocationEntity.playerTeamEntity(scene: view.scene) == nil else { return }

                let id = playerLocationEntity.deviceUUID
                guard !playerDeviceUUIDsServer.contains(id) else { return }

                let isSpectatorPlayerLocationEntity = UserSettings.spectator && id == myPlayerLocationEntity?.deviceUUID

                // PlayerLocationEntity, and if Table Top, RemoteEntity, and TargetEntity,
                // are created at the same time on each device that hosts or joins
                // (in addDevicePlayerEntities), and so all should exist together
                // If remoteEntity == nil, then we are in Full Court mode,
                // and don't have a RemoteEntity.  Network delays can cause
                // these entities to get transfered on different frames.
                let remoteEntity = remoteEntityFromId(id: id)

                // for table top, when we get a PlayerLocationEntity,
                // we need to wait until we have its RemoteEntity
                if UserSettings.isTableTop, !isSpectatorPlayerLocationEntity {
                    guard remoteEntity != nil else {
                        os_log(.default, log: GameLog.player, "TableTop non-spectator PlayerLocationEntity, but no RemoteEntity for UUID %s", "\(id)")
                        return
                    }
                }

                // Only execute this code once per device ID
                // have to wait until there is a PlayerLocationEntity with
                // no PlayerTeamEntity on the server/host, then add the
                // necessary host entities
                playerDeviceUUIDsServer.append(id)

                // ignore self if spectator, since spectator does not get any gameplay
                // entities
                guard !UserSettings.spectator || id != myPlayerLocationEntity?.deviceUUID else {
                    os_log(.default, log: GameLog.player, "no player representation for spectator UUID %s", "\(id)")
                    return
                }

                // A PlayerLocationEntity with no PlayerTeamEntity using the same
                // device ID indicates a brand new PlayerLocationEntity was created
                // locally, or remotely on a client.  Now we need to add the required
                // entities owned by the host/server
                levelLoader.addHostPlayerRepresentation(playerLocationEntity: playerLocationEntity, remoteEntity: remoteEntity)
                os_log(.default, log: GameLog.player, "appended player representation %sUUID %s", remoteEntity != nil ? "with remote " : "", "\(id)")
            }
        }

        // On the host/server and clients, some entities related to gameplay such as
        // PlayerLocationEntity, RemoteEntity, and TargetEntity are
        // created on each device (client or host) which defines a player,
        // and then have children added to them by the
        // host/server which needs to own those children, i.e. PlayerTeamComponent.
        // Here we can add the component watchers for the host/server and clients so
        // we know when data has changed in certain components, i.e. PlayerTeamComponent
        view.scene.anchors.forEach { anchor in
            guard !anchor.children.isEmpty else { return }
            anchor.children.forEach { entity in
                guard let playerLocationEntity = entity as? PlayerLocationEntity,
                let playerTeamEntity = playerLocationEntity.playerTeamEntity(scene: view.scene) else { return }

                // Check to see if we have already "registered" this
                // device ID
                let playerDeviceUUID = playerTeamEntity.deviceUUID
                guard !playerDeviceUUIDs.contains(playerDeviceUUID) else { return }

                // Only execute this code once per device ID
                // have to wait until the PlayerTeamEntity is added to the
                // hierarchy by the host or transported to the client
                playerDeviceUUIDs.append(playerDeviceUUID)
                os_log(.default, log: GameLog.player, "Found Team Entity UUID %s", "\(playerDeviceUUID)")
                componentWatcher.watch(entity: playerTeamEntity, with: PlayerTeamComponent.self) { [weak self] entity in
                    guard let self = self,
                    let playerTeamEntity = entity as? PlayerTeamEntity else { return }

                    if let remoteEntity = self.remoteEntityFromId(id: playerTeamEntity.deviceUUID) {
                        remoteEntity.newTeam(playerTeamEntity.onTeam)
                    }
                    if let targetEntity = self.targetEntityFromId(id: playerTeamEntity.deviceUUID) {
                        targetEntity.newTeam(playerTeamEntity.onTeam)
                    }
                    if self.myPlayerLocationEntity?.deviceUUID == playerTeamEntity.deviceUUID {
                        self.delegate?.gamePlayManager(self, updateDisplayTeam: playerTeamEntity.onTeam)
                    }
                }
            }
        }
    }

    private func moveOwnedEntities() {
        guard let playerLocationEntity = myPlayerLocationEntity else { return }

        playerLocationEntity.setTransformMatrix(cameraTransform.matrix, relativeTo: nil)
    }

    private func updateOtherEntities(_ timeDelta: TimeInterval) {
        entityCache.entityList(entityType: TargetEntity.self, forceRefresh: true).forEach { entity in
            entity.update(timeDelta, scene: view.scene)
        }

        let remotes = entityCache.entityList(entityType: RemoteEntity.self, forceRefresh: true)
        RemoteEntity.moveWithCollision(timeDelta, remotes)
    }

    private func processStandUprightEntities() {

        guard isServer else { return }

        entityCache.forEachEntity { entity in
            guard let entity = entity as? Entity & HasStandUpright else {
                return
            }
            entity.forceStandUpright()
        }
    }

    func playWinSound() { // InteractionDelegate
        musicCoordinator.playMusic(name: "music_win")
    }

    private func commonLevelSetup() {
        guard let camera = view.session.currentFrame?.camera else { fatalError() }

        sfxCoordinator.physicsOrigin = view.physicsOrigin
        GamePlayManager.physicsOrigin = view.physicsOrigin

        // must be called after physicsOrigin is set
        let team = cameraTeamSide()
        (myPlayerAnchor, myPlayerLocationEntity, GamePlayManager.myRemoteEntity, myTargetEntity) =
            levelLoader.addDevicePlayerRepresentation(scene: view.scene,
                                                      camera: camera,
                                                      named: currentPlayer.username,
                                                      cameraTeam: team)

        sfxCoordinator.addAudioEntities(entityCache.entityList(componentType: GameAudioComponent.self) as! [Entity & HasGameAudioComponent])
    }

    // Configures the entities from the level to be placed on the provided board.
    // After the content has been loaded, we want to end up with this hierarchy:
    // AnchorEntity <- connected to board anchor
    //   scaleNode  <- chosen level scale applied here
    //     activeLevel.content <- parent of all blocks/etc in the scene
    private func addLevel(board: GameBoard, activeLevel: ActiveLevel, completion: @escaping () -> Void) {
        guard let boardAnchor = board.anchor else { fatalError() }

        gameBoard = board

        if self.mode == .client {
            let entity = view.scene.findEntity(named: GamePlayManager.scaleNodeName)
            if view.physicsOrigin != entity {
                assertionFailure("our scale node is not the physics origin")
            }

            commonLevelSetup()

            os_log(.default, log: GameLog.levelLifeCycle, "level %s loaded, waiting for RE magic to add it to the scene", level.key)
            completion()
            return
        }

        let scaleNode = Entity(named: GamePlayManager.scaleNodeName)

        // activeLevel.scaleFactor is the scale to apply to make the content appear 1m wide.
        // board.uniformScale is the scale to apply to make a 1m wide board appear at the width the
        // user has chosen.
        let finalScale = activeLevel.scaleFactor * board.uniformScale
        scaleNode.transform.scale = SIMD3<Float>(repeating: finalScale)

        let anchor = AnchorEntity(anchor: boardAnchor)
        anchor.name = boardAnchor.identifier.uuidString
        view.scene.anchors.append(anchor)
        levelAnchor = anchor
        anchor.children.append(scaleNode)
        scaleNode.children.append(activeLevel.content)

        // must be set before the physics-based content is added to the scene.
        if view.physicsOrigin != nil {
            assertionFailure("already have a physics origin, this will create another which will cause problems")
        }
        view.physicsOrigin = scaleNode

        commonLevelSetup()

        completion()
    }

    // Initializes all the objects and interactions for the game, and prepares
    // to process user input.
    func startOnBoard(_ board: GameBoard, activeLevel: ActiveLevel) {
        // Start advertising game
        if let networkSession = networkSession, networkSession.isServer {
            networkSession.startAdvertising()
        }

        addLevel(board: board, activeLevel: activeLevel) {
            self.initDelegates()
        }
    }

    func newGame() {
    }

    func exitGame() {
        endGame()
    }

    private func updateTeamAIsToRightOfCamera() {
        guard let cameraAnchor = self.cameraAnchor else { return }
        let cameraAnchorRotation = cameraAnchor.orientation(relativeTo: GamePlayManager.physicsOrigin)
        let cameraRightWs = cameraAnchorRotation.act([1, 0, 0])
        let dotProduct = dot(cameraRightWs, [0, 0, 1])
        teamAIsToRightOfCamera = dotProduct >= 0.0
    }

    func cameraTeamSide() -> Team {
        guard let cameraAnchor = self.cameraAnchor else {
            fatalError("Don't have a cameraAnchor when needed for initial team determnination")
        }
        let cameraPosition = cameraAnchor.position(relativeTo: GamePlayManager.physicsOrigin) * [1, 0, 1]
        let toCameraNormal = normalize(cameraPosition)
        let dotProduct = dot([0, 0, Team.teamA.zSign], toCameraNormal)
        let team = dotProduct >= 0.0 ? Team.teamA : Team.teamB
        os_log(.default, log: GameLog.gameboard, "Camera pos = %0.2f, %0.2f, team = %s", cameraPosition.x, cameraPosition.z, "\(team)")
        return team
    }
}
