/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Manages ARsession callbacks
*/

import ARKit
import os.log

class ARSessionManager: NSObject {
    weak var gameSessionManager: GameSessionManager?
    var configuration = ARWorldTrackingConfiguration()
    var runOptions: ARSession.RunOptions = []
    var isSessionInterrupted: Bool = false
    var loadingFromMap = false
    weak var arSession: ARSession?
    init(session: ARSession) {
        self.arSession = session
        super.init()

        arSession?.delegate = self
    }
}

extension ARSession.RunOptions: Hashable {
    var debugDescription: String {
        let descriptions: [ARSession.RunOptions: String] = [
            .resetTracking: ".resetTracking",
            .removeExistingAnchors: ".removeExistingAnchors",
            .stopTrackedRaycasts: ".stopTrackedRaycasts"
        ]
        var builder: String = "["
        descriptions.forEach { (key, description) in
            if contains(key) {
                if builder.count > 1 {
                    builder += ", "
                }
                builder += description
            }
        }
        builder += "]"
        return builder
    }
}

// MARK: - Configuration
extension ARSessionManager {

    private func updateConfiguration(_ state: GameSessionManager.State) -> Bool {
        // Create a session configuration
        switch state {
        case .setup:
            // in setup
            os_log(.default, log: GameLog.levelLifeCycle, "AR session paused")
            arSession?.pause()
            return false

        case .lookingForSurface, .waitingForBoard:
            // both server and client, go ahead and start tracking the world
            configuration.planeDetection = [.horizontal]
            // find board based on the imageAnchor
            let floorDecalImageName = "Floor_Decal"
            if let trackingImage = UIImage(named: floorDecalImageName)?.cgImage {
                let imgSize = CGFloat(UserSettings.floorDecalDiameter)
                let refImg = ARReferenceImage(trackingImage, orientation: .up, physicalWidth: imgSize)
                configuration.detectionImages = [refImg]
                configuration.maximumNumberOfTrackedImages = 1
            }
            runOptions = []

        case .placingBoard:
            os_log(.default, log: GameLog.levelLifeCycle, "still looking for level, no config change")
            // we've found at least one surface, but should keep looking.
            return false

        case .adjustingBoard:
            os_log(.default, log: GameLog.levelLifeCycle, "adjusting gameboard state, no config change")
            return false

        case .localizingToWorldMap(let targetWorldMap):
            os_log(.default, log: GameLog.levelLifeCycle, "localizing to world map")
            loadingFromMap = true
            configuration.initialWorldMap = targetWorldMap
            configuration.planeDetection = []
            configuration.detectionImages = []
            configuration.setPeopleOcclusion(true)

            runOptions = [.resetTracking, .removeExistingAnchors]

            gameSessionManager?.hideBoardBorder()

        case .localizingCollaboratively(let targetWorldMap):
            loadingFromMap = true
            if let targetWorldMap = targetWorldMap {
                os_log(.default, log: GameLog.levelLifeCycle, "localizing collaboratively to world map")
                configuration.initialWorldMap = targetWorldMap
                gameSessionManager?.hideBoardBorder()
            }
            configuration.planeDetection = []
            configuration.detectionImages = []
            configuration.setPeopleOcclusion(true)

            runOptions = [.resetTracking, .removeExistingAnchors]

        case .gameInProgress:
            os_log(.default, log: GameLog.levelLifeCycle, "game in progress, no config change")
            // If we are loading from a map we have already turned off plane and image detection.
            if loadingFromMap {
                return false
            }
            // otherwise run the session again and turn off image and plane detection
            configuration.planeDetection = []
            configuration.detectionImages = []
            configuration.setPeopleOcclusion(true)
            // We purposefully fall through to the asSession.run() to update
            // the configuration with these changes.
            // Unfortunately this triggers a relocalization
            // by the ARSession, but it's necessary.
            runOptions = []

        case .exitGame:
            os_log(.default, log: GameLog.levelLifeCycle, "exit game, clear config")
            configuration.planeDetection = []
            configuration.detectionImages = []
            configuration.setPeopleOcclusion(false)
            runOptions = [.resetTracking, .removeExistingAnchors]
        }

        configuration.isLightEstimationEnabled = true

        return true
    }

    func configureARSession(_ state: GameSessionManager.State) {
        os_log(.default, log: GameLog.arFlags, "setting state to %s", String(describing: state))

        configuration.isAutoFocusEnabled = UserSettings.enableARAutoFocus
        configuration.isCollaborationEnabled = UserSettings.boardLocatingMode == .collaborative && gameSessionManager?.mode != .solo

        if !updateConfiguration(state) {
            return
        }

        os_log(.default, log: GameLog.arFlags, "Setting AR-Session Configuration:")
        os_log(.default, log: GameLog.arFlags, "    collaboration is %s", "\(configuration.isCollaborationEnabled)")
        os_log(.default, log: GameLog.arFlags, "    peopleOcclusion is %s", "\(configuration.peopleOcclusion)")
        os_log(.default, log: GameLog.arFlags, "    runOptions are %s", runOptions.debugDescription)
        os_log(.default, log: GameLog.arFlags, "    enableAutoFocus = %s", "\(configuration.isAutoFocusEnabled)")

        arSession?.run(configuration, options: runOptions)
    }

    func enableAutoFocus(_ enable: Bool) {
        configuration.isAutoFocusEnabled = enable

        os_log(.default, log: GameLog.arFlags, "Setting AR-Session Configuration:")
        os_log(.default, log: GameLog.arFlags, "    enableAutoFocus = %s", "\(configuration.isAutoFocusEnabled)")

        arSession?.run(configuration, options: runOptions)
    }

    func updatePeopleOcclusion() {
        configuration.updatePeopleOcclusion()

        os_log(.default, log: GameLog.arFlags, "Setting AR-Session Configuration:")
        os_log(.default, log: GameLog.arFlags, "    peopleOcclusion is %s", "\(configuration.peopleOcclusion)")

        arSession?.run(configuration, options: runOptions)
    }
}

// MARK: - World map management
extension ARSessionManager {
    private func compressMap(map: ARWorldMap, _ closure: @escaping (Result<Data, Error>) -> Void) {
        DispatchQueue.global().async {
            do {
                let data = try map.asCompressedData()
                closure(.success(data))
            } catch {
                os_log(.error, log: GameLog.levelLifeCycle, "archiving failed %s", "\(error)")
                closure(.failure(error))
            }
        }
    }

    func getWorldMapData(closure: @escaping (Result<Data, Error>) -> Void) {
        os_log(.default, log: GameLog.levelLifeCycle, "in getCurrentWordMapData")
        // When loading a map, send the loaded map and not the current extended map.
        os_log(.default, log: GameLog.general, "asking ARSession for the world map")
        arSession?.getCurrentWorldMap { map, error in
            os_log(.default, log: GameLog.levelLifeCycle, "ARSession getCurrentWorldMap returned")
            if let error = error {
                os_log(.error, log: GameLog.levelLifeCycle, "didn't work! %s", "\(error)")
                closure(.failure(error))
                return
            }
            guard let map = map else { os_log(.error, log: GameLog.levelLifeCycle, "no map either!"); return }
            os_log(.default, log: GameLog.levelLifeCycle, "got a worldmap, compressing it")
            self.compressMap(map: map, closure)
        }
    }
}

extension ARSessionManager: ARSessionDelegate {
    // Callbacks occur on the main thread
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let gameSessionManager = gameSessionManager else { return }
        // Update game board placement in physical world
        // Update mapping status for saving maps
        gameSessionManager.delegate?.gameSessionManager(gameSessionManager, updated: frame.worldMappingStatus)

        // Update debug info for collaborative mapping
        gameSessionManager.update(frame: frame, session: session)
    }

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            os_log(.default, log: GameLog.levelLifeCycle, "added anchor %s", "\(anchor)")
            gameSessionManager?.anchorAdded(anchor)
        }
    }

}

// MARK: - ARSessionObserver
extension ARSessionManager: ARSessionObserver {

    // Callbacks occur on the main thread
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        guard let gameSessionManager = gameSessionManager else { return }
        os_log(.default, log: GameLog.levelLifeCycle, "camera tracking state changed to %s", "\(camera.trackingState)")

        DispatchQueue.main.async {
            gameSessionManager.delegate?.gameSessionManager(gameSessionManager, updated: camera.trackingState)
        }

        switch camera.trackingState {
        case .normal:
            // Resume game if previously interrupted
            if isSessionInterrupted {
                isSessionInterrupted = false
            }

            // Show the game content
            gameSessionManager.fadeIn()
        case .limited:
            // Hide the game content if tracking is limited
            gameSessionManager.fadeOut()
        default:
            break
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        guard let gameSessionManager = gameSessionManager else { return }
        gameSessionManager.delegate?.gameSessionManager(gameSessionManager, failedWith: error as NSError)
    }

    func sessionWasInterrupted(_ session: ARSession) {
        guard let gameSessionManager = gameSessionManager else { return }
        os_log(.default, log: GameLog.levelLifeCycle, "[sessionWasInterrupted]")
        // Inform the user that the session has been interrupted
        isSessionInterrupted = true

        // Hide game content
        gameSessionManager.fadeOut()
        gameSessionManager.delegate?.gameSessionManagerInterruptedSession(gameSessionManager)
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        os_log(.default, log: GameLog.levelLifeCycle, "[sessionInterruptionEnded]")
    }

    func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
        return true
    }
}
