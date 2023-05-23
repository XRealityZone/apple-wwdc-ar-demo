/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Manages playback of sound effects.
*/

import AVFoundation
import Combine
import os.log
import RealityKit
import UIKit

class SFXCoordinator: NSObject {

    struct SoundConfig: Codable {
        let filename: String
        let gain: Double // decibels
        let playbackSpeed: Double?
        let loops: Bool
    }

    /// Debug flag to always play the ball sound regardless of its velocity
    var debugAlwaysPlayBallSound = false

    private(set) static var soundConfigs = [String: SoundConfig]()
    static var audioResources = [String: AudioFileResource]()

    /// This is an entity the game should attach to an anchor locked to
    /// the camera for playing sounds that may be spatial but are always
    /// positioned relative to the camera.
    let cameraLockedEntity = Entity()

    /// If a physicsOrigin is used on ARView, supply it here so that collision
    /// positions can be converted from that entity to the object's local coordinate systems.
    weak var physicsOrigin: Entity?

    var audioSamplers = [AudioPlaybackController]()
    var pooledCollisionEntities = [String: [Entity]]()
    var timer: DispatchSourceTimer?
    var renderToSimulationTransform = float4x4.identity

    static var effectsGain: AudioPlaybackController.Decibel = 0

    /// This is the default reverb send level that will be applied to sound effects played
    /// by SFXCoordinator
    static var globalReverbSendLevel: AudioPlaybackController.Decibel = -20

    typealias VariantSelector = (_ entity: Entity, _ impactPosition: SIMD3<Float>) -> String?
    var variantSelectors = [VariantSelector]()

    class AudioMotionPlayer {
        let entity: HasGameAudioComponent
        let sound: String
        let resource: AudioFileResource
        private var _player: AudioPlaybackController?
        var player: AudioPlaybackController? {
            if _player == nil && entity.isActive {
                // prepare the playback controller on the non-synced child entity
                // which is active for both client and server processes.
                _player = entity.localAudioChildEntity().prepareAudio(resource)
            }
            return _player
        }
        var isFadingOut = false

        init(entity: Entity & HasGameAudioComponent,
             sound: String,
             resource: AudioFileResource) {
            self.entity = entity
            self.sound = sound
            self.resource = resource
        }
    }
    var audioMotionPlayers = [AudioMotionPlayer]()

    /// Filter function to determine if a collision should play on the given
    /// entity. Return true to play the sound.
    var collisionFilter: ((Entity, Entity) -> Bool)?

    /// A dictionary of motion filters. GameAudioComponents can specify a filter by name and this
    /// function will be used to return a velocity value to use for the entity.
    struct MotionState {
        let active: Bool
        let velocity: SIMD3<Float>
        let gain: AudioPlaybackController.Decibel
        let playbackSpeed: Double
        let scalarVelocity: Float

        init(active: Bool,
             velocity: SIMD3<Float> = [0, 0, 0],
             gain: AudioPlaybackController.Decibel = -.infinity,
             playbackSpeed: Double = 1.0, scalarVelocity: Float = 0) {
            self.active = active
            self.velocity = velocity
            self.gain = gain
            self.playbackSpeed = playbackSpeed
            self.scalarVelocity = scalarVelocity
        }
    }

    // as a workaround, the inline spec works:
    typealias AudioMotionClosure = (HasGameAudioComponent, GameAudioConfiguration.MotionEntry, TimeInterval) -> MotionState
    var motionFilters = [String: AudioMotionClosure]()
    private var motionFading = Set<Entity.ID>()

    let logDetails = false

    let logToFile = false
    var logFileMotion: FileHandle?
    var logFileMotionURL: URL?
    var logFileCollision: FileHandle?
    var logFileCollisionURL: URL?
    var logQueue = DispatchQueue(label: "SFXCoordinator.logWriting", qos: .default, attributes: [], autoreleaseFrequency: .workItem)

    private static var loadCancellables = [AnyCancellable]()

    override init() {
        super.init()

        cameraLockedEntity.name = "SFXCoordinator"
        // this entity is not required to sync because each device will have its own
        // instance attached to its local camera anchor.
        cameraLockedEntity.components[SynchronizationComponent.self] = nil

        // Subscribe to notifications of user defaults changing so that we can apply them to
        // sound effects.
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleDefaultsDidChange(_:)),
                                               name: UserDefaults.didChangeNotification,
                                               object: nil)

        if logToFile {
            let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            let motionFilename = String(format: "audio-motion-%d.log", Int(getpid()))
            let motionURL = tempURL.appendingPathComponent(motionFilename)
            let collisionFilename = String(format: "audio-collision-%d.log", Int(getpid()))
            let collisionURL = tempURL.appendingPathComponent(collisionFilename)

            do {
                os_log(.default, log: GameLog.audio, "Logging to file: %s", collisionURL.path)
                FileManager.default.createFile(atPath: collisionURL.path, contents: nil, attributes: nil)
                logFileCollision = try FileHandle(forWritingTo: collisionURL)
                logFileCollisionURL = collisionURL
                os_log(.default, log: GameLog.audio, "Logging to file: %s", motionURL.path)
                FileManager.default.createFile(atPath: motionURL.path, contents: nil, attributes: nil)
                logFileMotion = try FileHandle(forWritingTo: motionURL)
                logFileMotionURL = motionURL
            } catch {
                fatalError("Failed to write to log file: \(error)")
            }
        }
    }

    /// Commence loading all of the sound effects in the used in this game, and invoke
    /// the completion block on the main queue when done.
    static func loadAudioFiles(completion: @escaping () -> Void) {

        // Kick off the load of our configuration to a background queue
        DispatchQueue.global().async {
            var usedSounds = [String]()
            var unusedSounds = [String]()

            if let soundsURL = Bundle.main.url(forResource: "sounds", withExtension: "json") {
                var throwFilename: String
                do {
                    throwFilename = "sounds.json"
                    let data = try Data(contentsOf: soundsURL)
                    let decoder = JSONDecoder()
                    soundConfigs = try decoder.decode([String: SoundConfig].self, from: data)

                    let audioFiles = ["pin-audio", "ball-audio", "paddle-audio", "gutter-audio"]
                    for audioFile in audioFiles {
                        if let theURL = Bundle.main.url(forResource: audioFile, withExtension: "json") {
                            throwFilename = audioFile + ".json"
                            let data = try Data(contentsOf: theURL)
                            let config = try JSONDecoder().decode(GameAudioConfiguration.self, from: data)
                            for entry in config.collisions {
                                for (_, variants) in entry.variants {
                                    for variant in variants {
                                        usedSounds += variant.sounds
                                    }
                                }
                            }
                        }
                    }
                    os_log(.default, log: GameLog.audio, "Scanned used audio files (%d)", usedSounds.count)
                } catch {
                    fatalError("Failed to load '\(throwFilename)'. Error = \(error)")
                }
            }

            // Even though the loading audio resources is asynchronous, these API calls
            // to RealityKit must be made on the main queue.

            let loadGroup = DispatchGroup()
            loadGroup.enter()
            DispatchQueue.main.async {
                for (name, config) in self.soundConfigs {
                    loadGroup.enter()
                    // loading must be called on the main queue.
                    loadAudioResource(name: name, config: config) {
                        loadGroup.leave()
                    }?
                    .store(in: &loadCancellables)

                    if !usedSounds.contains(name) {
                        unusedSounds.append(name)
                    }
                }

                loadGroup.leave()
            }

            loadGroup.notify(queue: DispatchQueue.main) {
                os_log(.default, log: GameLog.audio, "Loaded %d used audio files", usedSounds.count)
                os_log(.default, log: GameLog.audio, "Skipping loading of %d unused audio files", unusedSounds.count)
                loadCancellables = []
                completion()
            }
        }
    }

    @objc
    private func handleDefaultsDidChange(_ notification: Notification) {
        updateEffectsVolume()
    }

    /// Update the effects volume on the audioEnvironment node.
    /// Assumes the loading lock is held by the caller.
    func updateEffectsVolume() {
        let effectsVolume = UserSettings.effectsVolume
        // Map the slider value from 0...1 to a more natural curve:
        SFXCoordinator.effectsGain = AudioPlaybackController.Decibel(20.0 * log10(effectsVolume * effectsVolume))
    }

    static func urlForSound(named name: String) -> URL? {
        let exts: [String?] = [nil, "wav", "m4a"]
        for ext in exts {
            let filename = "Sounds/\(name)"
            if let url = Bundle.main.url(forResource: filename, withExtension: ext) {
                return url
            }
        }
        return nil
    }

    /// Return a loaded audio file resource. This will return nil
    /// if the audio file resource has not yet loaded, or if it failed
    /// to load.
    static func audioResource(named name: String) -> AudioFileResource? {
        return SFXCoordinator.audioResources[name]
    }

    /// Prepare a sound for playback on a specific entity with its
    /// gain and playback speed already configured based on the sounds.json
    /// configuration file.
    static func prepareSound(named name: String, on entity: Entity) -> AudioPlaybackController? {
        guard let resource = audioResource(named: name), let config = soundConfigs[name] else {
            return nil
        }
        let player = entity.prepareAudio(resource)
        player.gain = config.gain + SFXCoordinator.effectsGain
        player.reverbSendLevel = SFXCoordinator.globalReverbSendLevel
        player.speed = config.playbackSpeed ?? 1.0
        return player
    }

    /// Begin loading the audio file resource asynchronously.
    /// This must be called on the main queue. It's completion block will be invoked on
    /// the main queue.
    static func loadAudioResource(name: String, config: SoundConfig, completionClosure: @escaping () -> Void) -> AnyCancellable? {
        dispatchPrecondition(condition: .onQueue(.main))

        var cancellable: AnyCancellable?

        if audioResources[name] == nil {
            guard let url = urlForSound(named: config.filename) else {
                fatalError("Failed to load sound: \(config.filename)")
            }

            let loadRequest = AudioFileResource.loadAsync(contentsOf: url,
                                                          withName: name,
                                                          inputMode: .spatial,
                                                          loadingStrategy: .preload,
                                                          shouldLoop: config.loops)
            cancellable = loadRequest
                .sink(receiveCompletion: { (completion) in
                    // called on main queue
                    if case let .failure(error) = completion {
                        fatalError("Failed to load audio file '\(name)', error = \(error)")
                    }
                    completionClosure()
                }) { (resource) in
                    // called on main queue
                    SFXCoordinator.audioResources[name] = resource
                }
        } else {
            completionClosure()
        }
        return cancellable
    }

    func playUISound(named name: String) {
        guard let sound = SFXCoordinator.soundConfigs[name], let resource = SFXCoordinator.audioResources[name] else {
            os_log(.error, log: GameLog.audio, "No audio resource loaded with name '%s'", name)
            return
        }
        let player = cameraLockedEntity.prepareAudio(resource)
        player.gain = sound.gain + SFXCoordinator.effectsGain
        player.reverbSendLevel = SFXCoordinator.globalReverbSendLevel
        sound.playbackSpeed.map { player.speed = $0 }
        player.play()
    }

    // MARK: - GameAudioComponent Collision handling

    var logCollisionAudio = false
    static var collisionLogImpulseThreshold: Float = 0.00

    var maxCollisionPlayers: Int? = nil {
        didSet {
            guard let maxCollisionPlayers = maxCollisionPlayers else { return }

            if maxCollisionPlayers < 1 {
                fatalError("You must allow at least one collision player")
            }

            // if the new value is less than the previous value, clean up some players
            let previousValue = oldValue ?? 0
            if maxCollisionPlayers < previousValue && activeCollisionPlayers.count > maxCollisionPlayers {
                for _ in 0..<(previousValue - maxCollisionPlayers) {
                    activeCollisionPlayers.remove(at: 0).stop()
                }
            }
        }
    }

    // new players are appended to the end, old players are popped off the front
    var activeCollisionPlayers = [AudioPlaybackController]()
    var playbackCompletedSubscriptions = [AnyCancellable]()

    func handleCollisionBegan(_ event: CollisionEvents.Began) {
        let impactPositionRelativeToEntityA = event.entityA.convert(position: event.position, from: physicsOrigin)

        func debugName(_ entity: Entity) -> String {
            if let collisionComponent = entity.components[CollisionComponent.self] as? CollisionComponent {
                let group = collisionComponent.filter.group.rawValue
                let mask = collisionComponent.filter.mask.rawValue
                return String(format: "'%@'(0x%02x/0x%02x)", entity.name, group, mask)
            } else {
                // this should never occur:
                return String(format: "'%@'(missing)", entity.name)
            }
        }

        if logCollisionAudio {
            if event.impulse > SFXCoordinator.collisionLogImpulseThreshold {
                os_log(.default, log: GameLog.audio, "CollisionBegan, impulse = %5.9f, A = %s, B = %s, position: %s",
                       event.impulse, debugName(event.entityA), debugName(event.entityB),
                       String(describing: impactPositionRelativeToEntityA))
            }
        }

        if logToFile, let collisionFile = logFileCollision {
            let timestamp = CFAbsoluteTimeGetCurrent()
            let line = String(format: "%9.3f\t%@\t%@\t%9.6f\n",
                              timestamp, debugName(event.entityA), debugName(event.entityB),
                              event.impulse)
            logQueue.async {
                collisionFile.write(line.data(using: .utf8)!)
            }
        }

        if let filter = collisionFilter {
            if !filter(event.entityA, event.entityB) {
                return
            }
        }

        if let audioEntity = event.entityA as? HasGameAudioComponent,
            let collisionA: CollisionComponent = event.entityA.components[CollisionComponent.self],
            let collisionB: CollisionComponent = event.entityB.components[CollisionComponent.self] {

            let collisionGroupA = collisionA.filter.group
            let collisionGroupB = collisionB.filter.group

            let sameGroup = collisionGroupA == collisionGroupB
            if sameGroup {
                // for collisions between objects of the same group, only play the
                // collision for the lower of the two objects. For example, pin hits pin.
                let id1 = ObjectIdentifier(event.entityA)
                let id2 = ObjectIdentifier(event.entityB)
                if id1 > id2 {
                    return
                }
            }

            if collisionGroupB.rawValue == 0 && collisionGroupA.rawValue == 8 /* ball */ {
                os_log(.debug, log: GameLog.audio, "Ball hit group 0!, %d", Int(collisionA.filter.group.rawValue))
            }

            let variant = variantSelectors.lazy.compactMap { $0(audioEntity, impactPositionRelativeToEntityA) }
                .first

            if let soundParams =
                audioEntity.audio.configuration.soundForCollisionWith(group: collisionGroupB,
                                                               impulse: event.impulse,
                                                               variant: variant) {

                let audioStateEntity = audioEntity.localAudioChildEntity()
                let now = Date()
                if soundParams.coolDown > 0 {
                    let delta = now.timeIntervalSince(audioStateEntity.audioState.lastImpact)
                    if delta < soundParams.coolDown {

                        if event.impulse > audioStateEntity.audioState.lastImpulse * 2.0 {
                            os_log(.default, log: GameLog.audio,
                                   "SFXCoordinator: we got a big impulse in a cooldown! New impulse = %6.5f, old = %6.5f",
                                   event.impulse, audioStateEntity.audioState.lastImpulse)
                        }

                        if logDetails {
                            os_log(.default, log: GameLog.audio, "Abort Play sound due to cooldown: %s, delta = %f", soundParams.name, delta)
                        }
                        // skip playing the sound
                        return
                    }
                    audioStateEntity.audioState.lastImpact = now
                    audioStateEntity.audioState.lastImpulse = event.impulse
                }

                // if this entity has a motion sound configured, put it in fast decay
                // mode since the collision may stop the movement.
                audioStateEntity.audioState.fastDecay = true

                guard let config = SFXCoordinator.soundConfigs[soundParams.name],
                    let resource = SFXCoordinator.audioResources[soundParams.name] else {
                        os_log(.error, log: GameLog.audio, "collision said to play a sound that isn't loaded: '%s'", soundParams.name)
                        return
                }

                // if there are too many sounds, prune the oldest one
                if let maxCollisionPlayers = maxCollisionPlayers, activeCollisionPlayers.count > maxCollisionPlayers {
                    os_log(.default, log: GameLog.audio, "Maximum collision sounds reached, pruning old sound")
                    activeCollisionPlayers.remove(at: 0).stop()
                }

                if logDetails {
                    os_log(.default, log: GameLog.audio, "Play sound: %s, impulse = %5.9f gain = %3.3f (variant: %s)",
                           soundParams.name, event.impulse, config.gain + Double(soundParams.gain), variant ?? "-")
                }
                let player = audioStateEntity.prepareAudio(resource)
                player.reverbSendLevel = SFXCoordinator.globalReverbSendLevel
                player.gain = config.gain + soundParams.gain
                player.speed = soundParams.speed * (config.playbackSpeed ?? 1.0)

                // save the player and remove upon completion
                activeCollisionPlayers.append(player)
                audioStateEntity.scene?.publisher(for: AudioEvents.PlaybackCompleted.self, on: audioStateEntity)
                    .sink { [weak self] event in
                        self?.activeCollisionPlayers.removeAll(where: { $0 === event.playbackController })
                    }
                    .store(in: &playbackCompletedSubscriptions)

                player.play()

            } else {
                if logCollisionAudio {
                    os_log(.default, log: GameLog.audio, "Failed to find a collision sound between '%s' and '%s', impulse = %6.5f",
                           event.entityA.name, event.entityB.name, event.impulse)
                }
            }
        }
    }

    lazy var collisionReceiver: (CollisionEvent) -> Void = {
        if case let CollisionEvent.began(event) = $0 {
            self.handleCollisionBegan(event)
        }
    }

    // MARK: - GameAudioComponent motion handling

    func addAudioEntities(_ entities: [Entity & HasGameAudioComponent]) {
        for entity in entities {
            guard let motionEntries = entity.audio.configuration.motion else { continue }
            for entry in motionEntries {
                if let resource = SFXCoordinator.audioResource(named: entry.sound) {
                    let motionPlayer = AudioMotionPlayer(
                        entity: entity,
                        sound: entry.sound,
                        resource: resource
                    )
                    audioMotionPlayers.append(motionPlayer)
                }
            }
        }
    }

    func removeAudioEntities(_ entities: [Entity & HasGameAudioComponent]) {
        for entity in entities {
            audioMotionPlayers.removeAll(where: { $0.entity == entity })
        }
    }

    func removeAllAudioEntities() {
        audioMotionPlayers.removeAll()
    }

    var logMotionEvents = false

    func update(timeDelta: TimeInterval) {
        for motionPlayer in audioMotionPlayers where motionPlayer.entity.isActive {
            guard let motionEntries = motionPlayer.entity.audio.configuration.motion else { continue }
            if let entry = motionEntries.first(where: { $0.sound == motionPlayer.sound }),
                let funcName = motionPlayer.entity.audio.configuration.motionMappingFunction {

                guard let motionFunc = motionFilters[funcName] else {
                    fatalError("Undefined motion processing function with key '\(funcName)'")
                }
                let motionState = motionFunc(motionPlayer.entity, entry, timeDelta)

                if let logFileMotion = logFileMotion,
                    let velocity = motionPlayer.entity.physicsMotion?.linearVelocity {
                    let timestamp = CFAbsoluteTimeGetCurrent()

                    let line = String(format: "%9.3f\t%@\t%4.3f\t%4.3f\t%4.3f\t%4.3f\t%4.3f\n",
                                      timestamp, motionPlayer.entity.name,
                                      velocity.x, velocity.y, velocity.z,
                                      sqrtf(velocity.x * velocity.x + velocity.z * velocity.z),
                                      motionState.scalarVelocity)
                    logQueue.async {
                        logFileMotion.write(line.data(using: .utf8)!)
                    }
                }

                let isPlaying = motionPlayer.entity.localAudioChildEntity().audioState.playingMotionSounds.contains(motionPlayer.sound)
                let scalarVelocity = motionState.scalarVelocity

                if let player = motionPlayer.player {
                    if motionState.active || debugAlwaysPlayBallSound {
                        if debugAlwaysPlayBallSound {
                            player.gain = 0
                        } else {
                            // fade for the duration of 1 frame:
                            if !motionFading.contains(motionPlayer.entity.id) {
                                if logDetails {
                                    os_log(.default, log: GameLog.audio,
                                           "Fade motion sound '%s' to gain: %f", motionPlayer.sound, motionState.gain)
                                }
                                player.fade(to: motionState.gain, duration: timeDelta)
                                motionFading.insert(motionPlayer.entity.id)
                            } else {
                                if logDetails {
                                    os_log(.default, log: GameLog.audio,
                                           "SKIP Fade motion sound '%s' to gain: %f", motionPlayer.sound, motionState.gain)
                                }
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + timeDelta + 0.005) {
                                self.motionFading.remove(motionPlayer.entity.id)
                            }
                        }
                        player.speed = motionState.playbackSpeed
                        player.reverbSendLevel = SFXCoordinator.globalReverbSendLevel

                        if logMotionEvents && scalarVelocity > 1e-6 {
                            os_log(.default, log: GameLog.audio,
                                   "Motion tracking on '%s', active velocity = %5.5f, gain = %4.3fdB, playbackSpeed=%4.3f",
                                   motionPlayer.entity.name, scalarVelocity, motionState.gain, motionState.playbackSpeed)
                        }

                        if !isPlaying {
                            os_log(.default, log: GameLog.audio, "Starting motion sound '%s'", motionPlayer.sound)
                            player.play()
                            motionPlayer.isFadingOut = false
                            motionPlayer.entity.localAudioChildEntity().audioState.playingMotionSounds.insert(motionPlayer.sound)
                        }

                    } else {
                        if logMotionEvents && scalarVelocity > 1e-6 {
                            os_log(.default, log: GameLog.audio, "Motion tracking on '%s', inactive velocity = %5.5f",
                                   motionPlayer.entity.name, scalarVelocity)
                        }

                        if isPlaying {
                            os_log(.default, log: GameLog.audio, "Stopping motion sound '%s'", motionPlayer.sound)
                            let fadeout = TimeInterval(0.1)

                            player.fade(to: .off, duration: fadeout)
                            motionPlayer.isFadingOut = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + fadeout) {
                                // check if we have been asked to play again and abort the pause command.
                                if motionPlayer.isFadingOut {
                                    player.pause()
                                }
                            }
                            motionPlayer.entity.localAudioChildEntity().audioState.playingMotionSounds.remove(motionPlayer.sound)
                        }
                    }
                }
            }
        }
    }

}
