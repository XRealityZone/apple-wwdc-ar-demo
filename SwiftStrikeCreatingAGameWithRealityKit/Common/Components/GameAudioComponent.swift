/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Simple wrapper for UI audio effects.
*/

import Foundation
import RealityKit

/// This component contains the configuration of what collision and movement sounds
/// to play when this object collides with another.
struct GameAudioConfiguration: Codable {

    /// User definable comment string
    let comment: String?

    struct Mapping: Codable {
        /// Minimum input in mapping function. Values below this will
        /// be clamped to this value.
        let minInput: Float

        /// Maximum input in mapping function. Values above this will
        /// be clamped to this value.
        let maxInput: Float

        /// Minimum output value.
        let minOutput: Float

        /// Maximum output value
        let maxOutput: Float

        /// An exponent to be applied to the normalized impulse (input) value.
        /// If not present, a value of 1.0 will be used, which is linear.
        let exponent: Float?

        /// Convert an input impulse value through the mapping function defined by
        /// the values in this Mapping struct.
        func value(for impulse: Float) -> Float {
            precondition(impulse >= 0)
            precondition(maxInput > minInput)
            let clamped = max(minInput, min(maxInput, impulse))
            let normalized = (clamped - minInput) / (maxInput - minInput)
            let curved = pow(normalized, exponent ?? Float(1.0))
            return minOutput + curved * (maxOutput - minOutput)
        }

        init(minInput: Float,
             maxInput: Float,
             minOutput: Float,
             maxOutput: Float,
             exponent: Float?) {
            self.minInput = minInput
            self.maxInput = maxInput
            self.minOutput = minOutput
            self.maxOutput = maxOutput
            self.exponent = exponent
        }
    }

    struct Variant: Codable {

        /// User definable comment string
        let comment: String?

        /// This is the impulse threshold required to play a sound. Physics collisions with an impulse
        /// less that this will not play.
        let impulseThreshold: Float

        /// An array of sounds to be played when the conditions of this entry and this variant are met.
        /// One of the sounds in this list will be chosen at random for each collision.
        let sounds: [String]
    }

    struct CollisionEntry: Codable {

        /// User definable comment string
        let comment: String?

        /// The collision group to match against. This is the collision group of the other object hitting this one.
        /// For example, if this is a Pin, and you want to configure the sound it makes hitting the floor, use
        /// the group number for floor here.
        let group: Int

        /// A mapping function for converting impulse values to adjustments in audio playback
        /// gain adjustments. If not provided, no gain adjustment will be made and the sound will
        /// be played at the level defined in the sounds.json file. If provided the result of this
        /// mapping function will be added to that gain.
        let gain: Mapping?

        /// A mapping function for converting impulse values to adjustments in audio playback speed
        /// adjustments. If not provided, no adjustment will be made and the sound will be
        /// played at the speed defined in the sounds.json file. If provided, the playback speed from
        /// this function will be multiplied with the playback speed in the sounds.json file.
        let playbackSpeed: Mapping?

        /// If present, any collision sound on this entity will not be triggered if a prior collision sound was
        /// successfully triggered within the time interval specified here.
        let coolDown: TimeInterval?

        /// Define a variety of sounds that can play in response to collision triggers on this entity.
        let variants: [String: [Variant]]
    }

    struct MotionEntry: Codable {
        /// This is the minimum velocity the object needs to reach to play a sound.
        let minimumVelocity: Float

        /// A mapping function
        let gain: Mapping

        let speed: Mapping

        let sound: String
    }

    let collisions: [CollisionEntry]
    let motion: [MotionEntry]?
    let motionMappingFunction: String?      // name of the function registered with SFXCoordinator

    static let defaultVariant = "default"
    static let defaultInstance = GameAudioConfiguration(comment: nil,
                                                        collisions: [],
                                                        motion: [],
                                                        motionMappingFunction: nil)
}

struct GameAudioComponent: Component {
    var configurationName: String?

    static let defaultInstance = GameAudioComponent(configurationName: nil)
}

extension GameAudioComponent: Codable {}

extension GameAudioComponent {
    var configuration: GameAudioConfiguration {
        return GameAudioConfiguration.fetchConfig(named: configurationName)
    }
}

/// This struct contains the state that mutates over time, keeping track
/// of the last sound that played and when that was.
struct GameAudioStateComponent: Component, Codable {
    var lastImpact: Date = Date.distantPast
    var lastImpulse: Float = 0
    var previousSpeed: Float = 0
    var fastDecay = false
    var playingMotionSounds = Set<String>()
}

class AudioStateEntity: Entity & HasGameAudioStateComponent {
    required init() {
        super.init()
        self.audioState = GameAudioStateComponent()
        self.name = "AudioStateEntity"
    }
}

protocol HasGameAudioComponent: HasCollision, HasPhysicsMotion {}

protocol HasGameAudioStateComponent where Self: Entity {}

extension HasGameAudioComponent {
    var audio: GameAudioComponent {
        get { return components[GameAudioComponent.self] ?? GameAudioComponent.defaultInstance }
        set { components[GameAudioComponent.self] = newValue }
    }

    func setupAudioState() {
        _ = self.localAudioChildEntity
    }
}

extension Entity {
    /// Return a child entity for playing local sounds.
    /// This creates a new child entity if one does not exist as a child of this entity.
    /// The child entity is explicitly opted out of network synchronization so it will
    /// be on the local device only.
    func localAudioChildEntity() -> Entity & HasGameAudioStateComponent {
        if let entity = children.entities(with: GameAudioStateComponent.self).first {
            return entity as! Entity & HasGameAudioStateComponent
        }
        let stateEntity = AudioStateEntity()
        // explicitly opt out of synchronization for this entity:
        stateEntity.components[SynchronizationComponent.self] = nil
        self.addChild(stateEntity)
        return stateEntity
    }
}

extension HasGameAudioStateComponent {
    var audioState: GameAudioStateComponent {
        get { return components[GameAudioStateComponent.self] ?? GameAudioStateComponent() }
        set { components.set(newValue) }
    }
}

extension GameAudioConfiguration {

    struct CollisionSoundParameters {
        let name: String
        let gain: Double
        let coolDown: TimeInterval
        let speed: Double
    }

    func soundForCollisionWith(group: CollisionGroup, impulse: Float, variant: String?) -> CollisionSoundParameters? {
        let raw = Int(group.rawValue)
        for entry in collisions where (entry.group & raw) != 0 {
            if let variants = (variant.map { entry.variants[$0] } ?? entry.variants[GameAudioConfiguration.defaultVariant]),
                let variant = variants.first(where: { impulse >= $0.impulseThreshold }) {
                let index = Int(arc4random_uniform(UInt32(variant.sounds.count)))
                let name = variant.sounds[index]
                let gain = entry.gain?.value(for: impulse) ?? 0.0
                let speed = entry.playbackSpeed?.value(for: impulse) ?? 1.0
                let coolDown = entry.coolDown ?? 0
                return CollisionSoundParameters(name: name,
                                                gain: Double(gain),
                                                coolDown: coolDown,
                                                speed: Double(speed))
            }
        }
        return nil
    }

    static private var cache = [String: GameAudioConfiguration]()

    @discardableResult
    static func load(named name: String) -> GameAudioConfiguration {
        if let result = cache[name] {
            return result
        }
        do {
            let url = Bundle.main.url(forResource: name, withExtension: "json")!
            let data = try Data(contentsOf: url)
            let config = try JSONDecoder().decode(GameAudioConfiguration.self, from: data)
            cache[name] = config
            return config
        } catch {
            fatalError("Failed to load audio collision configuration from file named '\(name).json'. Error: \(error)")
        }
    }

    static func fetchConfig(named name: String?) -> GameAudioConfiguration {
        if let name = name, let result = cache[name] {
            return result
        }
        return GameAudioConfiguration.defaultInstance
    }
}

extension GameAudioComponent {
    static func load(named name: String) -> GameAudioComponent {
        GameAudioConfiguration.load(named: name)
        return GameAudioComponent(configurationName: name)
    }
}
