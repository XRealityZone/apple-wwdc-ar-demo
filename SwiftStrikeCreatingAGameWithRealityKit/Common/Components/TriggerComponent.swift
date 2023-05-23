/*
See LICENSE folder for this sample’s licensing information.

Abstract:
TriggerComponent
*/

import RealityKit

// TriggerComponent
// is added to the BeamOfLightEnitty and
// is used by game side collision
// detection when PlayerTeamComponent is
// "inside" a starting beam of light.
// triggered is set when a PlayerTeamComponent
// "begins" collision with the beam, and is cleared
// when the collision "ends"
struct TriggerComponent: Component {
    var triggered: Bool = false
}

extension TriggerComponent: Codable {}

protocol HasTrigger where Self: Entity {}

extension HasTrigger {

    var trigger: TriggerComponent {
        get { return components[TriggerComponent.self] ?? TriggerComponent() }
        set { components[TriggerComponent.self] = newValue }
    }

    var triggered: Bool {
        get { return trigger.triggered }
        set { trigger.triggered = newValue }
    }

}

extension TriggerComponent {
    static func eitherIsTrigger(_ entityA: Entity, _ entityB: Entity) -> Bool {
        return (entityA is HasTrigger) || (entityB is HasTrigger)
    }
}

extension CollisionEvents.Began {
    var isTriggerEvent: Bool {
        return TriggerComponent.eitherIsTrigger(entityA, entityB)
    }
}

extension CollisionEvents.Ended {
    var isTriggerEvent: Bool {
        return TriggerComponent.eitherIsTrigger(entityA, entityB)
    }
}

extension CollisionEvents.Updated {
    var isTriggerEvent: Bool {
        return TriggerComponent.eitherIsTrigger(entityA, entityB)
    }
}
