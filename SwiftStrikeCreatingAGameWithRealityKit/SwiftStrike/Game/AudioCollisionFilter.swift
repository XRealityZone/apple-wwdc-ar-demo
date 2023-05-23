/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Constants
*/

import Foundation
import os.log
import RealityKit

class AudioCollisionFilter {

    var gameStartTime: Date = Date.distantPast

    init() {
    }

    func startMatch() {
        gameStartTime = Date()
    }

    func collisionFilter(_ entityA: Entity, _ entityB: Entity) -> Bool {

        // The physics system can generate a bunch of collisions when the pins
        // are initially placed on the board. At the start of the game, we do not
        // need to hear these sounds.
        let now = Date()
        if entityA is PinEntity && now.timeIntervalSince(gameStartTime) < 1.5 {
            return false
        }

        // don't play any collision sounds below the ground.
        if entityA.position.y < 0 {
            return false
        }
        return true
    }
}
