/*
See LICENSE folder for this sample’s licensing information.

Abstract:
SweeperEntity
*/

import RealityKit

class SweeperEntity: Entity, HasPhysics {
    let team: Team

    init(size: SIMD3<Float>, team: Team) {
        self.team = team
        super.init()
        name = "\(team)"

        let shape = ShapeResource.generateBox(size: size)
        let filter = CollisionFilter(group: team.collisionGroup, mask: team.collisionGroup)
        collision = CollisionComponent(shapes: [shape], mode: .default, filter: filter)

        let material = PhysicsMaterialResource.generate(friction: 0.7, restitution: 0)
        physicsBody = PhysicsBodyComponent(shapes: [shape], mass: 100, material: material, mode: .kinematic)
        physicsMotion = PhysicsMotionComponent()
        synchronization = nil
    }

    required init() { self.team = .none }

}
