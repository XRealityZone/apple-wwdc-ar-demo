/*
See LICENSE folder for this sample’s licensing information.

Abstract:
UprightStatusComponent
*/

import Foundation
import os.log
import RealityKit

enum UprightStatusTickResult {
    case notUpdated
    case updatedButNotChanged
    case updatedAndChanged
}

struct UprightStatusParameters {
    // parameters for "still" detection
    let framesRequiredForStill: Int
    let linearVelocityThreshold: Float
    let angularVelocityThreshold: Float
    
    // parameters for "up" detection
    let framesRequiredForUprightNoChange: Int
    let uprightPositionYThreshold: Float
    let uprightNormalYThreshold: Float
    let belowSurface: Float

    // allow uprightState to be dynamic, not singular like a bowling pin being knocked down
    let continuousState: Bool
}

// This component contains the state of whether the physics object
// is upright based on a few parameters
// We check linear and angular velocity (like the physics engine)
// and impulses over time to determine if we are "still" enough
// to check orientation for upright.
// Still is similar to the PhysicsMotionComponent.isSleeping
// This code operates in 4 sequential states:
//     wait for first still & upright -> uprightState = true
//     wait for not still
//     wait for still
//     determine upright or not -> uprightState
/// - Tag: UprightStatusComponent
struct UprightStatusComponent: Component {

    // output of this component
    var uprightState: Bool = true

    // inner state and timing for component
    private enum State: String, Codable {
        case none
        case setup
        case still
        case moving
        case determine
        case done
    }

    private var state: State = .setup
    private var framesInState: Int = 0
    private var lastUprightState: Bool = false
    private var framesStill: Int = 0
    private var framesUprightStateSame: Int = 0

    mutating func reset() {
        nextState(.setup)
        framesStill = 0
        framesUprightStateSame = 0
        uprightState = true
    }

}

extension UprightStatusComponent {

    // MARK: - External methods/properties

    /// tick() returns UprightStatusTickResult to indicate if uprightState has changed or been determined to be unchanged
    mutating func tick(_ entity: Entity, parameters: UprightStatusParameters) -> UprightStatusTickResult {

        var framesInStateThreshold = 0
        framesInState += 1      // mostly for debugging to see how long in .still state
        switch state {
        case .setup:
            uprightState = false
            // need to get a valid transform from pin before proceeding...
            if isEntityStill(entity, parameters) > 3 {
                _ = updateUprightState(entity, parameters)
                nextState(.still)
                lastUprightState = uprightState
            }
            
        case .still:
            if isEntityStill(entity, parameters) == 0 {
                nextState(.moving)
            }
            framesInStateThreshold = 30

        case .moving:
            framesInState += 1      // mostly for debugging to see how long in .still state
            if isEntityStill(entity, parameters) >= parameters.framesRequiredForStill {
                nextState(.determine)
            }
            framesInStateThreshold = 30

        case .determine:
            framesInState += 1      // mostly for debugging to see how long in .still state
            if isEntityStill(entity, parameters) == 0 {
                nextState(.moving)
            }
            
        default:
            // should be .done state here, don't need to do any more work
            return .notUpdated            // uprightState has NOT been updated
        }

        if framesInState > framesInStateThreshold && updateUprightState(entity, parameters) >= parameters.framesRequiredForUprightNoChange {
            if uprightState != lastUprightState {
                state = parameters.continuousState ? .still : .done
                lastUprightState = uprightState
                return .updatedAndChanged
            }
            return .updatedButNotChanged         // uprightState has been updated - may be the same or different
        }

        return .notUpdated           // uprightState has NOT been updated
    }

    var isDone: Bool {
        return state == .done
    }

    // MARK: - Internal methods

    private mutating func nextState(_ newState: State) {
        framesInState = 0
        state = newState
    }

    private mutating func isEntityStill(_ entity: Entity, _ parameters: UprightStatusParameters) -> Int {
        guard let physicsEntity = entity as? Entity & HasPhysicsMotion, let component = physicsEntity.physicsMotion else {
            return 0
        }

        if simd.length_squared(component.linearVelocity) >= parameters.linearVelocityThreshold
        || simd.length_squared(component.angularVelocity) >= parameters.angularVelocityThreshold {
            framesStill = 0
            return framesStill
        }

        framesStill += 1
        return framesStill
    }

    private mutating func updateUprightState(_ entity: Entity, _ parameters: UprightStatusParameters) -> Int {
        // to determine upright, we look at the Y portion of the
        // normalized up vector for the Entity
        // this is computed using the quaternion -> basis3x3
        // math for only the Y component of the Y vector in the basis
        let qauternion = entity.transform.rotation
        let basisYy = (qauternion.real * qauternion.real)
                    - (qauternion.imag.x * qauternion.imag.x)
                    + (qauternion.imag.y * qauternion.imag.y)
                    - (qauternion.imag.z * qauternion.imag.z)
        let positionY = entity.position(relativeTo: GamePlayManager.physicsOrigin).y
        let oldUprightState = uprightState
        // how close to 1.0 are we?
        uprightState = ((1.0 - basisYy) < parameters.uprightNormalYThreshold) && (positionY >= parameters.belowSurface)
        if oldUprightState == uprightState {
            framesUprightStateSame += 1
        } else {
            framesUprightStateSame = 0
        }
        return framesUprightStateSame
    }

}

/// - Tag: HasUprightStatus
protocol HasUprightStatus: HasPhysics {}

extension HasUprightStatus {

    var uprightStatus: UprightStatusComponent {
        get { return components[UprightStatusComponent.self] ?? UprightStatusComponent() }
        set { components[UprightStatusComponent.self] = newValue }
    }

    var upright: Bool {
        return uprightStatus.uprightState
    }

}
