/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Main game view controller
*/

import ARKit
import Combine
import os.signpost
import RealityKit
import UIKit

extension VisualMode {
    var exposureCompensation: Float {
        switch self {
        case .normal: return 0.0
        case .cosmic: return UserSettings.cosmicExposureCompensation
        }
    }
}

class GameViewController: UIViewController, UIGestureRecognizerDelegate {

    // instanced externally after GameViewController is instanced - once
    var musicCoordinator: MusicCoordinator!
    var sfxCoordinator: SFXCoordinator!
    var levelLoader: LevelLoader!
    var networkSession: NetworkSession?

    // instanced in viewDidLoad() - once per game
    private(set) var bannerManager: BannerNotificationManager?
    private var forceStartGameRecognizer: UITapGestureRecognizer?
    private var forceEndGameRecognizer: UITapGestureRecognizer?
    private var forceEndGame5TapRecognizer: UITapGestureRecognizer?
    private var pewPewGestureRecongnizer: UITapGestureRecognizer?
    private var audioCollisionFilter: AudioCollisionFilter?
    private var viewObservers = [NSObjectProtocol]()

    // instanced in createGameManager() from viewWillAppear() - for every game/match
    private(set) var entityCache: EntityCache!
    private var uprightCoordinator: UprightCoordinator!
    private var pinTransparencyManager: PinTransparencyManager?
    private var trackerArrowManager: TrackerArrowManager!
    private var componentWatcher: ComponentWatcher?
    private(set) var gameSessionManager: GameSessionManager?
    private var playerSoundController: PlayerSoundController?

    // instanced in startMatch() called from gameSessionManagerReady() from gamePlayManagerReady() from GamePlayManager.startMatch()
    private var currentMatch: Match?
    private var matchObserver: MatchObserver?
    private var syncSoundPublisher: SyncSoundPublisher?
    private var syncSoundObserver: SyncSoundObserver?

    var realityView: GameView {
        return view as! GameView
    }

    private var arViewContentScaleFactor: CGFloat = 0.0
    private var lastRendererResolutionFactor: Float = 0.0

    override var prefersStatusBarHidden: Bool {
        return true
    }

    // Maps UI
    @IBOutlet var mappingStateLabel: UILabel!
    @IBOutlet var trackingStateLabel: UILabel!
    @IBOutlet var thermalStateLabel: UILabel!

    @IBOutlet weak var settingsButton: UIButton!
    @IBOutlet weak var arFrameDebugText: UITextView!

    var iblResource: EnvironmentResource?

    // publishers
    var matchCancellables = [AnyCancellable]()

    var mappingStatus: ARFrame.WorldMappingStatus = .notAvailable {
        didSet {
            guard oldValue != mappingStatus else {
                return
            }
            updateMappingStatus()
        }
    }

    override var prefersHomeIndicatorAutoHidden: Bool { true }

    var shouldShowMappingState: Bool = false

    var teamAWasToRightOfCamera: Bool = false
    var lastScore: MatchScore?

    @objc
    func handleForceStartGame(_ gesture: UITapGestureRecognizer) {
        os_log("three finger tap %s", "\(gesture)")
        guard UserSettings.spectator else { return }
        NotificationCenter.default.post(name: .forceStartSelected, object: nil)
    }
    
    @objc
    func handleForceEndGame(_ gesture: UITapGestureRecognizer) {
        os_log("four finger tap %s", "\(gesture)")
        guard UserSettings.spectator else { return }
        NotificationCenter.default.post(name: .forceEndSelected, object: nil)
    }

    /// Create a cube that collides with any collision object.
    @objc
    func pewpew(_ gesture: UITapGestureRecognizer) {
        os_log("two finger tap %s", "\(gesture)")
        guard UserSettings.enablePewPew,
        let camera = realityView.session.currentFrame?.camera,
        let levelEntity = levelLoader.activeLevel?.content else { return }
        let projectileSize: Float = 0.1
        let projectileForce: Float
        if UserSettings.isTableTop {
            // scaled value because physics world is same scale,
            // but this is in world scale
            projectileForce = 1200.0
        } else {
            projectileForce = 600.0
        }
        let paddleRadiusScale: Float = 1.2    // 1.2 scale on collision radius to escape any initial collisions
        let forwardOffset = Constants.paddleRadius * paddleRadiusScale
        levelEntity.pewpew(camera: camera, size: projectileSize, force: projectileForce, forwardOffset: forwardOffset,
                           group: .all, mask: [.ground, .gutter, .ball, .pin])
    }

    private func addGestures() {
        // set up docent gesture recognizer
        forceStartGameRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleForceStartGame(_:)))
        forceStartGameRecognizer!.numberOfTouchesRequired = 3
        forceStartGameRecognizer!.delegate = self
        realityView.addGestureRecognizer(forceStartGameRecognizer!)

        forceEndGameRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleForceEndGame(_:)))
        forceEndGameRecognizer!.numberOfTouchesRequired = 4
        forceEndGameRecognizer!.delegate = self
        realityView.addGestureRecognizer(forceEndGameRecognizer!)

        forceEndGame5TapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleForceEndGame(_:)))
        forceEndGame5TapRecognizer!.numberOfTouchesRequired = 5
        forceEndGame5TapRecognizer!.delegate = self
        realityView.addGestureRecognizer(forceEndGame5TapRecognizer!)

        pewPewGestureRecongnizer = UITapGestureRecognizer(target: self, action: #selector(pewpew(_:)))
        pewPewGestureRecongnizer!.numberOfTouchesRequired = 2
        pewPewGestureRecongnizer!.name = "pewpew"
        pewPewGestureRecongnizer!.delegate = self
        realityView.addGestureRecognizer(pewPewGestureRecongnizer!)
    }

    deinit {
        viewObservers.forEach { observer in
            NotificationCenter.default.removeObserver(observer)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        bannerManager = BannerNotificationManager(notificationBannerView: realityView.topBanner, instructionBannerView: realityView.bottomBanner)

        let observer = NotificationCenter.default.addObserver(forName: ProcessInfo.thermalStateDidChangeNotification,
                                                              object: nil,
                                                              queue: .main) { [weak self] note in
            guard let processInfo = note.object as? ProcessInfo else { return }
            self?.updateThermalStateIndicator(processInfo.thermalState)
        }
        viewObservers.append(observer)

        // save original scale factor
        arViewContentScaleFactor = view.contentScaleFactor
        os_log(.default, log: GameLog.general, "ARView content scale factor %.02f", Float(view.contentScaleFactor))

        realityView.debugButton.isHidden = UserSettings.spectator ? false : !UserSettings.debugEnabled
        if UserSettings.disableInGameUI
        || (UserSettings.spectator && !UserSettings.debugEnabled) {
            var rect = realityView.debugButton.frame
            rect = rect.insetBy(dx: -5.0, dy: -5.0)
            realityView.debugButton.setTitle("", for: .normal)         // invisible button
            realityView.debugButton.frame = rect
        }
        debugHook()

        addGestures()

        audioCollisionFilter = AudioCollisionFilter()
        sfxCoordinator.variantSelectors.append(PinEntity.selectPinSoundVariant)
        sfxCoordinator.motionFilters["Ball"] = BallEntity.audioMotionFilter
        sfxCoordinator.collisionFilter = audioCollisionFilter?.collisionFilter
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        #if DEBUG
        realityView.scene.dump()
        #endif

        configureView(.setup)
        createGameSessionManager(for: networkSession)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        destroyGameSessionManager()
        bannerManager = nil

        sfxCoordinator.collisionFilter = nil
        audioCollisionFilter = nil

        #if DEBUG
        realityView.scene.dump()
        #endif
    }

    private func createGameSessionManager(for networkSession: NetworkSession?) {
        // create the entity cache instance in the scope of this
        // GameViewController (which owns the scene)
        // we need to reset the cache when we destroy the scene
        // and all the entities to restart/quit the game
        entityCache = EntityCache(realityView.scene)

        uprightCoordinator = UprightCoordinator(uprightsPerTeam: 10)

        pinTransparencyManager = PinTransparencyManager(entityCache: entityCache)

        if !UserSettings.disableInGameUI
        && !UserSettings.spectator {
            trackerArrowManager = TrackerArrowManager(entityCache: entityCache, realityView: realityView)
        }

        guard sfxCoordinator != nil else {
            fatalError("sfxCoordinator is not set")
        }
        guard levelLoader.activeLevel != nil else {
            fatalError("active level is not set")
        }

        componentWatcher = ComponentWatcher()

        gameSessionManager = GameSessionManager(view: realityView,
                                                level: levelLoader.reckoning,
                                                levelLoader: levelLoader,
                                                netowrkSession: networkSession,
                                                musicCoordinator: musicCoordinator,
                                                sfxCoordinator: sfxCoordinator,
                                                uprightCoordinator: uprightCoordinator,
                                                entityCache: entityCache,
                                                componentWatcher: componentWatcher!)
        gameSessionManager?.delegate = self

        // Start the controller for UI sounds on the current device
        playerSoundController = PlayerSoundController(sfxCoordinator: sfxCoordinator,
                                                      scene: realityView.scene,
                                                      entityCache: entityCache)
    }

    private func destroyGameSessionManager() {
        gameSessionManager?.destroy()

        networkSession = nil

        playerSoundController?.destroy()
        playerSoundController = nil

        componentWatcher = nil

        trackerArrowManager = nil
        pinTransparencyManager = nil
        uprightCoordinator = nil
        entityCache = nil

        gameSessionManager = nil
    }

    private func updateThermalStateIndicator(_ thermalState: ProcessInfo.ThermalState) {
        DispatchQueue.main.async {
            // Show thermal state label if default enabled and state is critical
            self.thermalStateLabel.isHidden = !(UserSettings.showThermalState && thermalState == .critical)
        }
    }

    func configureTrackingState() {
        trackingStateLabel.isHidden = !UserSettings.showTrackingState || UserSettings.disableInGameUI
    }

    func configureCollaborativeMapping() {
        arFrameDebugText.isHidden = !UserSettings.showCollabMappingDebug || UserSettings.disableInGameUI
        arFrameDebugText.superview?.isHidden = !UserSettings.showCollabMappingDebug || UserSettings.disableInGameUI
    }

    private func updateContentScaleFactor() {
        let newFactor = RendererQualityControl.renderResolutionFactor()
        if newFactor != lastRendererResolutionFactor {
            lastRendererResolutionFactor = newFactor
            view.contentScaleFactor = arViewContentScaleFactor * CGFloat(newFactor)
            os_log(.default, log: GameLog.general, "ARView content scale factor %.02f (%.02f * %.02f)",
                   Float(view.contentScaleFactor), Float(arViewContentScaleFactor), newFactor)
        }
    }

    private func iblFileName() -> String {
        var options = Asset.Options()
        if UserSettings.isTableTop {
            options = options.union(.tabletop)
        }
        return Asset.name(for: .ibl, options: options)
    }

    func configureIbl() {
        realityView.environment.lighting.resource = UserSettings.useIbl ? iblResource : nil
    }

    private func configureGameUI() {
        // Hide all in game UI elements if the user as disabled in the settings
        if UserSettings.disableInGameUI {
            realityView.countdownTimerView.isHidden = true
            realityView.pinStatusView.isHidden = true
            realityView.rightPinStatusView.isHidden = true
            realityView.leftPinStatusView.isHidden = true
            realityView.quitButton.isHidden = true
            realityView.activityIndicator.isHidden = true
            trackingStateLabel.isHidden = true
            bannerManager?.isHidden = true
            arFrameDebugText.isHidden = true
            mappingStateLabel.isHidden = true
            thermalStateLabel.isHidden = true
        }

        // Hide all debug UI elements if we're not in debug mode
        if !UserSettings.debugEnabled {
            trackingStateLabel.isHidden = true
            arFrameDebugText.isHidden = true
            arFrameDebugText.superview?.isHidden = true
        }
    }

    func configureView(_ state: GameSessionManager.State) {
        // we only need to do the realityView setup for the environment once!
        if state == .setup {
            realityView.environment.lighting.intensityExponent = UserSettings.lightingIntensity

            if iblResource == nil {
                iblResource = try? EnvironmentResource.load(named: iblFileName())
            }
            configureIbl()

            realityView.environment.background = .cameraFeed(exposureCompensation:
                UserSettings.visualMode.exposureCompensation)

            if UserSettings.enableReverb {
                // use reverb only for player hand held devices...
                realityView.environment.reverb = .preset(.smallRoom)
            } else {
                realityView.environment.reverb = .noReverb
            }
        }

        let peopleOcclusion = gameSessionManager?.arSessionManager.configuration.peopleOcclusion ?? false
        realityView.configureOptions(peopleOcclusion)

        realityView.countdownTimerView.isHidden = true
        if state == .gameInProgress {
            if UserSettings.spectator {
                realityView.rightPinStatusView.isHidden = false
                realityView.leftPinStatusView.isHidden = false
                realityView.rightPinStatusView.transform = CGAffineTransform(rotationAngle: -CGFloat.pi / 2)
                realityView.leftPinStatusView.transform = CGAffineTransform(rotationAngle: CGFloat.pi / 2)
            } else {
                realityView.pinStatusView.isHidden = false
            }

            realityView.countdownTimerView.enableDebug = UserSettings.debugCountdownTimerView
            realityView.pinStatusView.enableDebug = UserSettings.debugPinStatusView
        } else {
            if UserSettings.spectator {
                realityView.rightPinStatusView.isHidden = true
                realityView.leftPinStatusView.isHidden = true
            } else {
                realityView.pinStatusView.isHidden = true
            }
        }

        realityView.quitButton.isHidden = state == .setup

        configureTrackingState()

        if let bannerManager = self.bannerManager {
            if let localizedInstruction = state.localizedInstruction {
                bannerManager.setBanner(text: localizedInstruction, for: .instruction, animated: false)
            } else {
                bannerManager.clearBanner(for: .instruction)
            }
        }

        if state == .waitingForBoard {
            realityView.activityIndicator.startAnimating()
        } else {
            realityView.activityIndicator.stopAnimating()
        }

        configureMappingUI(state)
        updateThermalStateIndicator(ProcessInfo.processInfo.thermalState)
        configureCollaborativeMapping()

        configureGameUI()
    }

    @IBAction func quitGamePressed(_ sender: UIButton) {
        os_log(.default, log: GameLog.navigation, "Quit game pressed")

        let leaveAction = UIAlertAction(title: NSLocalizedString("Leave", comment: ""), style: .cancel) { _ in
            os_log(.default, log: GameLog.navigation, "Leave game pressed")
            self.leaveGame()
        }
        let stayAction = UIAlertAction(title: NSLocalizedString("Stay", comment: ""), style: .default)
        let actions = [stayAction, leaveAction]

        let localizedTitle = NSLocalizedString("Are you sure you want to leave the game?", comment: "")
        var localizedMessage: String?

        if let gameManager = gameSessionManager, gameManager.mode == .server {
            localizedMessage = NSLocalizedString("You’re the host, so if you leave now the other players will have to leave too.", comment: "")
        }

        showAlert(title: localizedTitle, message: localizedMessage, actions: actions)
    }

    private func leaveGame() {
        gameSessionManager?.exitGame()
        endMatch()
        perform(.unwindToMainMenu)
    }

    private func startMatch() {
        guard let gameSessionManager = gameSessionManager else {
            fatalError("Must have gameSessionManager in order to startMatch()")
        }

        // only start Match on host
        if gameSessionManager.mode != .client {
            let currentMatch = Match(scene: realityView.scene, mode: gameSessionManager.mode)
            self.currentMatch = currentMatch
            currentMatch.matchEvents
                .sink { gameSessionManager.dispatchToMain($0) }
                .store(in: &matchCancellables)
        }

        // start observer on all devices

        let matchObserver = MatchObserver(scene: realityView.scene)
        self.matchObserver = matchObserver
        matchObserver.matchOutputEvents
            .sink { [weak self] in
                self?.bannerManager?.updateInstructionBanner(input: $0.message)
                self?.playerSoundController?.matchDidChangeState(to: $0)
            }
            .store(in: &matchCancellables)

        audioCollisionFilter?.startMatch()
        updateViews(matchObserver.matchOutputEvents)

        syncSoundPublisher = SyncSoundPublisher(scene: realityView.scene, entityCache: entityCache)
        guard let sfxCoordinator = sfxCoordinator else {
            fatalError("sfxCoordinator is not set")
        }
        syncSoundObserver = SyncSoundObserver(scene: realityView.scene, entityCache: entityCache, sfxCoordinator: sfxCoordinator)

        gameSessionManager.newGame()
    }

    private func endMatch() {
        matchCancellables = []
        currentMatch = nil
        matchObserver = nil
        syncSoundPublisher = nil
        syncSoundObserver = nil
        entityCache.reset()
    }

    private func restartMatch() {
        endMatch()
        playerSoundController?.gameReset()
        startMatch()
    }
}

extension GameViewController {

    func updateTimerView() {
        let frequency = 1.0 / 20.0  // fast enough for smooth update of progress bar in countdown timer view
        DispatchQueue.main.asyncAfter(deadline: .now() + frequency) { [weak self] in
            if let self = self {
                self.realityView.countdownTimerView.tick()
                self.updateTimerView()
            }
        }
    }

    func updateViews(_ publisher: AnyPublisher<MatchOutput, Never>) {

        updateTimerView()

        let scores = publisher
            .compactMap { (matchOutput) -> (MatchScore?, CountdownTime?) in
                if case MatchOutput.matchStarted(score: let score, matchTime: let matchTime) = matchOutput {
                    return (score, matchTime)
                } else {
                    return (nil, nil)
                }
            }
            .eraseToAnyPublisher()

        let realityView = self.realityView

        if UserSettings.spectator {
            scores
                .sink { [weak self] (scoreEntry, timeEntry) in
                    if let score = scoreEntry {
                        self?.lastScore = score
                        self?.updatePinStatusViewScores()
                    }
                    if let timerView = realityView.countdownTimerView, let time = timeEntry {
                        timerView.isHidden = time.duration == 0.0
                        timerView.setRange(time)
                    }
                }
                .store(in: &matchCancellables)
        } else {
            let pinStatusView = realityView.pinStatusView!
            scores
                .sink { (scoreEntry, timeEntry) in
                    if let score = scoreEntry {
                        // we don't know which team the view wants, so send both
                        pinStatusView.uprightStateChanged(team: .teamA, mask: score.teamA)
                        pinStatusView.uprightStateChanged(team: .teamB, mask: score.teamB)
                    }
                    if let timerView = realityView.countdownTimerView, let time = timeEntry {
                        timerView.isHidden = time.duration == 0.0
                        timerView.setRange(time)
                    }
                }
                .store(in: &matchCancellables)
        }
    }

    private func updatePinStatusViewScores() {
        guard let lastScore = lastScore else { return }
        var rightTeam = Team.teamA
        var leftTeam = Team.teamB
        if let right = gameSessionManager?.teamAIsToRightOfCamera, !right {
            rightTeam = .teamB
            leftTeam = .teamA
        }
        realityView.rightPinStatusView!.uprightStateChanged(team: rightTeam, mask: lastScore[rightTeam])
        realityView.leftPinStatusView!.uprightStateChanged(team: leftTeam, mask: lastScore[leftTeam])
    }

    private func updatePinStatusViewTeams() {
        if let newRight = gameSessionManager?.teamAIsToRightOfCamera,
        newRight != teamAWasToRightOfCamera {
            teamAWasToRightOfCamera = newRight
            if newRight {
                realityView.rightPinStatusView.displayedTeam = Team.teamA
                realityView.leftPinStatusView.displayedTeam = Team.teamB
            } else {
                realityView.rightPinStatusView.displayedTeam = Team.teamB
                realityView.leftPinStatusView.displayedTeam = Team.teamA
            }
            // if we swapped teams, we need to update the scores as well
            updatePinStatusViewScores()
        }
    }

    func update(_ timeDelta: TimeInterval) {
        updateContentScaleFactor()
        pinTransparencyManager?.updatePinTransparency()
        if UserSettings.spectator {
            updatePinStatusViewTeams()
        }
    }

}

extension GameViewController {

    func playerLocationEntityFromId(id: UUID) -> PlayerLocationEntity? {
        // PlayerLocationEntities are the first children of an anchor
        // in the scene
        for anchor in realityView.scene.anchors {
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

    func playerTeamEntityFromId(id: UUID) -> PlayerTeamEntity? {
        // search for a PlayerLocationEntity that has a PlayerTeamEntity
        guard let playerLocationEntity = playerLocationEntityFromId(id: id) else { return nil }

        for child in playerLocationEntity.children where child is PlayerTeamEntity {
            guard let playerTeamEntity = child as? PlayerTeamEntity else { continue }

            if playerTeamEntity.deviceUUID == id {
                return playerTeamEntity
            }
        }

        guard let remoteEntity = remoteEntityFromId(id: id) else { return nil }
        for child in remoteEntity.children where child is PlayerTeamEntity {
            guard let playerTeamEntity = child as? PlayerTeamEntity else { continue }

            if playerTeamEntity.deviceUUID == id {
                return playerTeamEntity
            }
        }
        return nil
    }

}

extension GameViewController: GameSessionManagerDelegate {

    func gameSessionManagerReady(_ manager: GameSessionManager) {
        startMatch()

        // If we are in spectator mode, we have a special listener configuration
        // because the audio will be played from speakers at WWDC. Since the
        // speakers have a fixed position relative to the court, we want to
        // use an audio listener at a fixed position relative to the court.
        if UserSettings.spectator
        && (manager.mode == .solo || manager.mode == .server) {
            let listeners = entityCache.entityList(componentType: SpectatorListenerComponent.self, forceRefresh: true)
            if let spectatorListener = listeners.first {
                os_log(.default, log: GameLog.audio, "Setting specator mode listener.")
                realityView.audioListener = spectatorListener
            }
        }
    }

    func gameSessionManager(_ manager: GameSessionManager, generatedAlert alert: String) {
        self.showAlert(title: alert)
    }

    func gameSessionManager(_ manager: GameSessionManager, joiningPlayer player: Player) {
        DispatchQueue.main.async {
            let text = String.localizedStringWithFormat(NSLocalizedString("%@ joined the game.", comment: "In game notification"), player.username)
            self.bannerManager?.setBanner(text: text, for: .notification, persistent: false)
        }
    }
    
    func gameSessionManager(_ manager: GameSessionManager, leavingPlayer player: Player) {
        DispatchQueue.main.async {
            let text = String.localizedStringWithFormat(NSLocalizedString("%@ left the game.", comment: "In game notification"), player.username)
            self.bannerManager?.setBanner(text: text, for: .notification, persistent: false)
        }
    }
    
    func gameSessionManager(_ manager: GameSessionManager, joiningHost host: Player) {
        DispatchQueue.main.async {
            let text = NSLocalizedString("You joined the game.", comment: "In game notification")
            self.bannerManager?.setBanner(text: text, for: .notification, persistent: false)
        }
    }
    
    func gameSessionManager(_ manager: GameSessionManager, leavingHost host: Player) {
        DispatchQueue.main.async {
            // the game can no longer continue
            let text = NSLocalizedString("The host left the game. Please join another game or start your own!", comment: "In game notification")
            self.bannerManager?.setBanner(text: text, for: .notification)
        }
    }
    
    func gameSessionManager(_ manager: GameSessionManager, hasNetworkDelay: Bool) {
        
    }
    
    func gameSessionManagerDidUnloadLevel(_ manager: GameSessionManager) {
        DispatchQueue.main.async {
            self.gameSessionManager = nil
        }
    }
    
    func gameSessionManager(_ manager: GameSessionManager, updatedSession state: GameSessionManager.State) {
        DispatchQueue.main.async {
            self.configureView(state)
        }
    }

    func gameSessionManager(_ manager: GameSessionManager, tickTimeDelta timeDelta: TimeInterval) {
        update(timeDelta)
    }

    func gameSessionManager(_ manager: GameSessionManager, updated mappingStatus: ARFrame.WorldMappingStatus) {
        self.mappingStatus = mappingStatus
    }
    
    func gameSessionManager(_ manager: GameSessionManager, updated trackingState: ARCamera.TrackingState) {
        trackingStateLabel.text = "Tracking: \(trackingState)"
    }
    
    func gameSessionManager(_ manager: GameSessionManager, failedWith error: Error) {
        // Get localized strings from error
        let nsError = error as NSError
        let messages = [
            nsError.localizedDescription,
            nsError.localizedFailureReason,
            nsError.localizedRecoverySuggestion
        ]

        // Use `compactMap(_:)` to remove optional error messages.
        let errorMessage = messages.compactMap { $0 }.joined(separator: "\n")

        // Present the error message to the user
        showAlert(title: "Session Error", message: errorMessage, actions: nil)
    }
    
    func gameSessionManagerInterruptedSession(_ manager: GameSessionManager) {
        let text = NSLocalizedString("Point the camera towards the table and move around.", comment: "")
        bannerManager?.setInstruction(text: text, push: true)
    }

    func gameSessionManager(_ manager: GameSessionManager, updateDisplayTeam team: Team) {
        realityView.pinStatusView.displayedTeam = team
    }

}

extension GameViewController: UserSettingsNavigationControllerDelegate {
    func gameSettingsViewController() -> UIViewController {
        let storyboard = UIStoryboard(name: "GameSettings", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "GameSettingsTableViewController")
        return viewController
    }
}

