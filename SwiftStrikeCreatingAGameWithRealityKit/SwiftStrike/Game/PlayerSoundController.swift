/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Match
*/

import Combine
import Foundation
import os.log
import RealityKit

var distanceThreshold = Float(1.3)
var velocityThreshold = Float(1.5)

/// This is a class for generating device specific sounds, such as UI sounds, that only play
/// on the current device - or have special behaviors in spectator mode.

class PlayerSoundController: NSObject {

    let logDetails = false

    let sfxCoordinator: SFXCoordinator
    let scene: Scene
    let entityCache: EntityCache

    /// This is the PlayerLocationEntity for the local device only.
    weak var playerLocationEntity: PlayerLocationEntity? // owned by the local device
    weak var playerStateEntity: PlayerTeamEntity? // owned by the host of the game, contains PlayerTeamComponent (entity.team)
    var playerBeamLoop: AudioPlaybackController? {
        willSet {
            if let old = playerBeamLoop {
                old.fadeOutAndStop(duration: 0.2)
            }
        }
    }

    /// The local player's paddle entity.
    weak var forceFieldOwnerEntity: ForceFieldOwnerEntity?
    weak var forceFieldEntity: ForceFieldEntity?
    var playingPushBallSound = false
    var canInteractWithBall = false
    var pushKickPlayer: AudioPlaybackController?
    var pushLoopPlayer: AudioPlaybackController?
    var pushLoopPlayerLastUpdateTime = CFAbsoluteTime(0)
    var pushLoopPlayerLastGain = -AudioPlaybackController.Decibel.infinity
    var pushLoopPlayerGainThreshold = AudioPlaybackController.Decibel(0.1)
    let pushLoopTimeThreshold = TimeInterval(0.060)
    let pushLoopTimeFadeDuration = TimeInterval(0.050)
    let pushLoopMapping = GameAudioConfiguration.Mapping(minInput: 7,
                                                         maxInput: 14,
                                                         minOutput: -30,
                                                         maxOutput: -1,
                                                         exponent: 1)
    var canPushKick = true

    var hasWonGame = false

    var cancellables = [AnyCancellable]()
    var observers = [NSObjectProtocol]()

    private func cancelSubscriptions() {
        cancellables = []
        observers.forEach { observer in
            NotificationCenter.default.removeObserver(observer)
        }
        observers = []
    }

    private func makeSubscriptions() {
        scene.publisher(for: CollisionEvents.Began.self)
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: handleCollisionBegan)
            .store(in: &cancellables)
        scene.publisher(for: CollisionEvents.Ended.self)
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: handleCollisionEnd)
            .store(in: &cancellables)
        scene.publisher(for: SceneEvents.Update.self)
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: handleScenenUpdate)
            .store(in: &cancellables)

        let intendedObservers: [(Notification.Name, (Notification) -> Void)] = [
            (RadiatingForceFieldComponent.applyForceNotification, handleRadiatingForce),
            (RadiatingForceFieldComponent.applyKickNotification, handleRadiatingForceKick),
            (RadiatingForceFieldComponent.resetKickNotification, resetRadiatingForceKick),
            (RemoteEntity.remoteCollisionNotification, remoteCollisionEvent)
        ]
        intendedObservers.forEach { (notificationName, closure) in
            let observer = NotificationCenter.default.addObserver(forName: notificationName,
                                                                  object: nil, queue: OperationQueue.main,
                                                                  using: closure)
            observers.append(observer)
        }
    }

    init(sfxCoordinator: SFXCoordinator, scene: Scene, entityCache: EntityCache) {
        self.sfxCoordinator = sfxCoordinator
        self.scene = scene
        self.entityCache = entityCache
        super.init()

        makeSubscriptions()
    }

    deinit {
        cancelSubscriptions()
    }

    func destroy() {
        cancelSubscriptions()
    }

    func update(deltaTime: TimeInterval) {
        findPlayerEntity()
    }

    func playerEnteredTrigger(_ playerTeamEntity: PlayerTeamEntity) {
        guard let playerLocationEntity = playerTeamEntity.playerLocationEntity(scene: scene) else { return }
        if UserSettings.spectator {
            // Special handling for spectator mode: Play a sound on the location of the player.
            let audioEntity = playerLocationEntity.localAudioChildEntity()
            guard let resource = SFXCoordinator.audioResource(named: "Player_Step_On_C") else {
                fatalError("Failed to load sound")
            }
            audioEntity.playAudio(resource)
        } else {
            // In the normal case, this sound plays only on the device that entered the trigger.
            if playerLocationEntity.isOwner {
                sfxCoordinator.playUISound(named: "Player_Step_On_C")
                playerBeamLoop = SFXCoordinator.prepareSound(named: "Pillar_Glow_F_Loop", on: playerLocationEntity)
                playerBeamLoop?.play()
            }

            // start the ball push loop, but with the volume off to avoid a click when starting it later when the interaction starts...
            if playerLocationEntity.isOwner {
                if let player = pushLoopPlayer {
                    player.gain = -90
                } else {
                    let newPlayer = SFXCoordinator.prepareSound(named: "Ball_Push_Loop_1", on: playerLocationEntity)
                    pushLoopPlayer = newPlayer
                    newPlayer?.play()
                }
            }
        }
    }

    func playerExitedTrigger(_ playerTeamEntity: PlayerTeamEntity) {
        guard let playerLocationEntity = playerTeamEntity.playerLocationEntity(scene: scene) else { return }
        if UserSettings.spectator {
            // Special handling for spectator mode: Play a sound on the location of the player.
            let audioEntity = playerLocationEntity.localAudioChildEntity()
            guard let resource = SFXCoordinator.audioResource(named: "Player_step_off_3") else {
                fatalError("Failed to load sound")
            }
            audioEntity.playAudio(resource)
        } else {
            // In the normal case, this sound plays only on the device that exited the trigger.
            if playerLocationEntity.isOwner {
                sfxCoordinator.playUISound(named: "Player_step_off_3")
                playerBeamLoop = nil
            }
        }
    }

    var playerCollisionVelocityMapping = GameAudioConfiguration.Mapping(minInput: 0.5,
                                                                        maxInput: 20,
                                                                        minOutput: -20,
                                                                        maxOutput: -6,
                                                                        exponent: 1.0)

    func playerHitPlayer(_ playerTeamEntity: PlayerTeamEntity, impulse: Float) {
        guard let playerLocationEntity = playerTeamEntity.playerLocationEntity(scene: scene) else { return }
        let soundName = "Player_Impact_Player_3"

        let audioEntity = playerLocationEntity.localAudioChildEntity()
        guard let resource = SFXCoordinator.audioResource(named: soundName) else {
            fatalError("Failed to load sound")
        }

        let player = audioEntity.prepareAudio(resource)
        os_log(.debug, log: GameLog.audio, "PlayerVsPlayer impact, impulse = %5.3f", impulse)

        player.gain = AudioPlaybackController.Decibel(playerCollisionVelocityMapping.value(for: impulse))

        player.play()
    }

    func matchDidChangeState(to state: MatchOutput) {
        switch state {
        case let .countingDownToStart(secondsRemaining: remaining):
            if remaining == 0 {
                sfxCoordinator.playUISound(named: "countdown_complete_high_F")
                playerBeamLoop = nil
            } else {
                sfxCoordinator.playUISound(named: "countdown_complete_C_note")
            }
            canInteractWithBall = true
        case .matchStarted:
            playerBeamLoop = nil
        case let .matchWonBy(team):
            canInteractWithBall = false
            _stopForceFieldInteraction()

            os_log(.debug, log: GameLog.audio, "team won = %d", 1)

            // delay the cheer event a little to give room for the pin sounds and
            // the animation to start.
            DispatchQueue.main.asyncAfter(wallDeadline: .now() + 0.5) {
                self.playWinningCheer(team: team)
            }
        default:
            // no action
            break
        }
    }

    func playWinningCheer(team: Team) {

        // choose a sound to play:
        let sounds = [
            "Crowd_Cheer_Mono_050819_01",
            "Crowd_Cheer_Mono_050819_02",
            "Crowd_Cheer_Mono_050819_03"
        ]
        let drawSounds = [
            "Claps_Cheer_Layer_050819_09",
            "Claps_Cheer_Layer_050819_10",
            "Claps_Cheer_Layer_050819_11"
        ]

        guard let sound = sounds.randomElement(),
            let drawSound = drawSounds.randomElement() else {
                fatalError("Failed to get audio resource for winning game.")
        }

        if UserSettings.spectator {
            if team == .none {
                // draw
                let field: Entity? = scene.findEntity(named: "Audio_Center")
                SFXCoordinator.prepareSound(named: drawSound, on: field!.localAudioChildEntity())?.play()
            } else {
                // in spectator mode, find the player that one and play the sound on them.
                let playerTeamEntities = entityCache.entityList(entityType: PlayerTeamEntity.self)
                if let playerTeamEntity = playerTeamEntities.first(where: { $0.onTeam == team }) {
                    // Matt?  Should this be PlayerLocationEntity?
                    SFXCoordinator.prepareSound(named: sound, on: playerTeamEntity.localAudioChildEntity())?.play()
                }
            }
        } else {
            // for players, only play the sound if we are the team that won.
            if let playerLocationEntity = playerLocationEntity,
                let playerStateEntity = playerStateEntity {
                if team == .none {
                    SFXCoordinator.prepareSound(named: drawSound, on: playerLocationEntity)?.play()
                } else if team == playerStateEntity.onTeam {
                    SFXCoordinator.prepareSound(named: sound, on: playerLocationEntity)?.play()
                }
            }
        }
    }

    func findPlayerEntity() {
        // search for this device' player location entity. We
        // cache the result so that we don't have to incur this cost
        // every frame for the entire game.
        if playerLocationEntity == nil {
            // PlayerTeamComponent
            let playerTeamEntities = entityCache.entityList(entityType: PlayerTeamEntity.self)
            for playerTeamEntity in playerTeamEntities {
                if let locationEntity = playerTeamEntity.playerLocationEntity(scene: scene), locationEntity.isOwner {
                    playerLocationEntity = locationEntity
                    playerStateEntity = playerTeamEntity
                    break
                }
            }
        }
    }

    func startForceFieldInteraction(forceFieldOwner: ForceFieldOwnerEntity) {
        guard let playerLocationEntity = playerLocationEntity, playerLocationEntity.isOwner else {
            return
        }
        // spectator does not play these sounds.
        guard !UserSettings.spectator else {
            return
        }

        self.forceFieldOwnerEntity = forceFieldOwner
        self.forceFieldEntity = forceFieldOwner.forceFieldEntity

        guard canInteractWithBall else {
            return
        }
        canPushKick = true

        if pushKickPlayer == nil {
            os_log(.default, log: GameLog.audio, "PlayerSoundController: SFXCoordinator.prepareSound(named: Ball_Push_6)")
            pushKickPlayer = SFXCoordinator.prepareSound(named: "Ball_Push_6", on: playerLocationEntity)
        }

        guard !playingPushBallSound else {
            return
        }

        os_log(.default, log: GameLog.audio, "PlayerSoundController: SFXCoordinator.prepareSound(named: Ball_Push_Loop_1)")
        if pushLoopPlayer == nil {
            pushLoopPlayer = SFXCoordinator.prepareSound(named: "Ball_Push_Loop_1", on: playerLocationEntity)
            pushLoopPlayer?.play()
        } else {
            pushLoopPlayer?.gain = -90
        }
        pushLoopPlayerLastGain = -90
        pushLoopPlayerLastUpdateTime = CFAbsoluteTimeGetCurrent()

        os_log(.default, log: GameLog.audio, "PlayerSoundController: start paddle loop")
        #if DEBUG
        logViewStream.write(String(format: "PlayerSoundController: start paddle loop\n"))
        #endif

        playingPushBallSound = true
    }

    func stopForceFieldInteraction(forceFieldOwner: ForceFieldOwnerEntity) {
        os_log(.default, log: GameLog.audio, "PlayerSoundController: stop paddle interaction(1)")
        #if DEBUG
        logViewStream.write(String(format: "PlayerSoundController: stop paddle interaction(1)\n"))
        #endif

        guard forceFieldOwnerEntity === forceFieldOwner else {
            return
        }

        _stopForceFieldInteraction()
    }

    private func _stopForceFieldInteraction() {
        os_log(.default, log: GameLog.audio, "PlayerSoundController: stop paddle loop(2)")
        if playingPushBallSound {
            playingPushBallSound = false
            os_log(.default, log: GameLog.audio, "PlayerSoundController: stop paddle loop(2) - fade out and stop")
            pushLoopPlayer?.fade(to: .off, duration: 0.2)
            canPushKick = true
        }
        forceFieldOwnerEntity = nil
        forceFieldEntity = nil
    }

    private func handleRadiatingForceKick(_ note: Notification) {
        // spectator does not play these sounds.
        guard !UserSettings.spectator else {
            return
        }

        if let force = note.userInfo?["force"] as? Float {
            os_log(.default, log: GameLog.audio, "PlayerSoundController: kick, force = %5.4f", force)
            #if DEBUG
            logViewStream.write(String(format: "PlayerSoundController: kick, force = %5.4f\n", force))
            #endif
        }
        if let pushKickPlayer = pushKickPlayer, canPushKick {
            pushKickPlayer.gain = -5
            pushKickPlayer.play()
            canPushKick = false
        }
    }

    private func resetRadiatingForceKick(_ note: Notification) {
        os_log(.default, log: GameLog.audio, "reset kick from radiating force component.")
        canPushKick = true
    }

    private func handleRadiatingForce(_ note: Notification) {
        // spectator does not play these sounds.
        guard !UserSettings.spectator else {
            return
        }

        if let force = note.userInfo?["force"] as? Float {
            let gain = AudioPlaybackController.Decibel(pushLoopMapping.value(for: force))
            #if DEBUG
            logViewStream.write(String(format: "PlayerSoundController: radiate, force = %5.4f, gain = %5.4f", force, gain))
            #endif
            if let pushLoopPlayer = pushLoopPlayer {
                let gainDelta = abs(pushLoopPlayerLastGain - gain)
                let now = CFAbsoluteTimeGetCurrent()
                if now - pushLoopPlayerLastUpdateTime > pushLoopTimeThreshold && gainDelta > pushLoopPlayerGainThreshold {
                    pushLoopPlayerLastUpdateTime = now
                    pushLoopPlayerLastGain = gain
                    if logDetails {
                        os_log(.default, log: GameLog.audio, "PlayerSoundController: radiate, force = %5.4f, gain = %5.4f", force, gain)
                    }
                    pushLoopPlayer.fade(to: gain + SFXCoordinator.effectsGain, duration: pushLoopTimeFadeDuration)
                } else {
                    if logDetails {
                        os_log(.default, log: GameLog.audio, "PlayerSoundController: radiate SKIPPING, force = %5.4f, gain = %5.4f", force, gain)
                    }
                }
            }
        }
    }

    private func remoteCollisionEvent(_ event: Notification) {
        // spectator does not play these sounds.
        guard !UserSettings.spectator else {
            return
        }

        if let remoteCollisionEvent = event.userInfo?["event"] as? RemoteCollisionEvent {
            guard let playerTeamEntityA = remoteCollisionEvent.entity0.playerTeamEntity(),
            let playerTeamEntityB = remoteCollisionEvent.entity1.playerTeamEntity() else { return }
            if !playerTeamEntityA.isLocalPlayer && !playerTeamEntityB.isLocalPlayer {
                fatalError("need a better way to detect who owns what.")
            }
            let playerTeamEntity: PlayerTeamEntity
            let impulseMagnitude: Float
            if playerTeamEntityA.isLocalPlayer {
                playerTeamEntity = playerTeamEntityA
                impulseMagnitude = length(remoteCollisionEvent.impulse0)
            } else {
                playerTeamEntity = playerTeamEntityB
                impulseMagnitude = length(remoteCollisionEvent.impulse1)
            }
            os_log(.default, log: GameLog.audio, "PlayerSoundController: remote, %s, impulse = %5.4f",
                   playerTeamEntity.name, impulseMagnitude)
            #if DEBUG
            logViewStream.write(String(format: "PlayerSoundController: remote, %s,  impulse = %5.4f",
                                       playerTeamEntity.name, impulseMagnitude))
            #endif
            playerHitPlayer(playerTeamEntity, impulse: impulseMagnitude)
        }

    }

    private func handleCollisionBegan(_ input: CollisionEvents.Began) {
        if let playerTeamEntity = isCollisionBetweenPlayerAndBeam(input.entityA, input.entityB) {
            os_log(.default, log: GameLog.audio, "PlayerSoundController: player entity entered trigger: %s", playerTeamEntity.name)
            playerEnteredTrigger(playerTeamEntity)
        }
        if let forceFieldOwnerEntity = isCollisionBetweenForceFieldOwnerAndBall(input.entityA, input.entityB) {
            os_log(.default, log: GameLog.audio, "PlayerSoundController: Start tracking ForceFieldOwner")
            #if DEBUG
            logViewStream.write("PlayerSoundController: Start tracking ForceFieldOwner\n")
            #endif
            startForceFieldInteraction(forceFieldOwner: forceFieldOwnerEntity)
        }
    }

    private func handleCollisionEnd(_ input: CollisionEvents.Ended) {
        if let playerTeamEntity = isCollisionBetweenPlayerAndBeam(input.entityA, input.entityB) {
            os_log(.default, log: GameLog.audio, "PlayerSoundController: player entity exited trigger: %s", playerTeamEntity.name)
            playerExitedTrigger(playerTeamEntity)
        }
        if let forceFieldOwnerEntity = isCollisionBetweenForceFieldOwnerAndBall(input.entityA, input.entityB) {
            os_log(.default, log: GameLog.audio, "PlayerSoundController: Stop tracking ForceFieldOwner")
            #if DEBUG
            logViewStream.write("PlayerSoundController: Stop tracking ForceFieldOwner\n")
            #endif
            stopForceFieldInteraction(forceFieldOwner: forceFieldOwnerEntity)
        }
    }

    private func handleScenenUpdate(_ input: SceneEvents.Update) {
        update(deltaTime: input.deltaTime)
    }
}

/// Determine if entity "a" collision (begin or end) with entity "b" is with the a player
private func isCollisionBetweenPlayerAndBeam(_ entityA: Entity, _ entityB: Entity) -> PlayerTeamEntity? {
    if entityB is HasTrigger, let playerTeamEntity = entityA as? PlayerTeamEntity {
        return playerTeamEntity
    }
    return nil
}

private func isCollisionBetweenForceFieldOwnerAndBall(_ entityA: Entity, _ entityB: Entity) -> ForceFieldOwnerEntity? {
    if entityB is BallEntity, let forceFieldOwner = entityA as? ForceFieldOwnerEntity {
        return forceFieldOwner
    }
    return nil
}

extension PlayerSoundController: GameResettable {
    func gameReset() {
        playerBeamLoop = nil
        if let pushLoopPlayer = pushLoopPlayer {
            pushLoopPlayer.fadeOutAndStop(duration: 0.3)
            self.pushLoopPlayer = nil
        }
        playingPushBallSound = false
    }
}

