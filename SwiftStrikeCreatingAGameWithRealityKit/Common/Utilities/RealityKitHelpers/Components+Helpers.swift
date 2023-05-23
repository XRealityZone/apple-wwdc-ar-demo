/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Components+Helpers
*/

import RealityKit

extension PhysicsBodyComponent {
    static func generate(shapes: [ShapeResource],
                         mass: Float,
                         staticFriction: Float,
                         kineticFriction: Float? = nil,
                         restitution: Float,
                         mode: PhysicsBodyMode) -> PhysicsBodyComponent {
        // ideally we would keep a library/cache of PhysicsMaterialResource, and
        // resuse them as that would be much more efficient for RealityKit
        // physics
        let physicsMaterial = PhysicsMaterialResource.generate(staticFriction: staticFriction,
                                                               dynamicFriction: kineticFriction ?? staticFriction,
                                                               restitution: restitution)
        return PhysicsBodyComponent(
            shapes: shapes,
            mass: mass,
            material: physicsMaterial,
            mode: mode)
    }
}

extension CollisionComponent {
    static func generate(shapes: [ShapeResource],
                         mode: CollisionComponent.Mode,
                         group: CollisionGroup,
                         mask: CollisionGroup) -> CollisionComponent {
        let collisionFilter = CollisionFilter(group: group, mask: mask)
        return CollisionComponent(shapes: shapes, mode: mode, filter: collisionFilter)
    }
}
