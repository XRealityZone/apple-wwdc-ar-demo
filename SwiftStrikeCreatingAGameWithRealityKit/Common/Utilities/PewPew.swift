/*
See LICENSE folder for this sample’s licensing information.

Abstract:
ARConfiguration helpers
*/

import ARKit
import os.log
import RealityKit

extension Entity {

    func generateCube(size: Float = 0.1, mass: Float = 1.0, staticFriction: Float = 0.5, kineticFriction: Float? = nil, restitution: Float = 0.5,
                      group: CollisionGroup = .all, mask: CollisionGroup = .all) -> ModelEntity {
        let cube = ModelEntity(mesh: MeshResource.generateBox(size: size),
                               materials: [SimpleMaterial(color: .white, isMetallic: false)])
        cube.name = "PewPew!"
        
        let cubeShape = ShapeResource.generateBox(size: [size, size, size])
        
        cube.components[PhysicsBodyComponent.self] = PhysicsBodyComponent.generate(
            shapes: [cubeShape],
            mass: mass,
            staticFriction: staticFriction,
            kineticFriction: kineticFriction ?? staticFriction,
            restitution: restitution,
            mode: .dynamic
        )
        cube.components[CollisionComponent.self] = CollisionComponent.generate(
            shapes: [cubeShape],
            mode: .default,
            group: group,
            mask: mask
        )
        cube.physicsMotion = .init()
        return cube
    }

    func pewpew(camera: ARCamera, size: Float = 1.0, force: Float = 1.0, forwardOffset: Float = 1.0,
                group: CollisionGroup = .all, mask: CollisionGroup = .all) {
        let cube = generateCube(size: size, group: group, mask: mask)
        let cameraPosition = SIMD4<Float>(camera.transform.translation, 1.0)       // camera position in world
        let cameraDirection = -camera.transform.columns.2.xyz // camera direction is inverted relative to world

        // transform matrix from World space to this Entity Local space
        let matrixWS2LS = transformMatrix(relativeTo: nil).inverse
        let cameraPositionLS = matrixWS2LS * cameraPosition
        let position = SIMD3<Float>(cameraPositionLS.x, cameraPositionLS.y, cameraPositionLS.z)

        let transformWS2LS = Transform(matrix: matrixWS2LS)
        let rotationWS2LS = transformWS2LS.rotation
        let basisWS2LS = float3x3.init(rotationWS2LS.normalized)
        let direction = basisWS2LS * cameraDirection

        cube.transform.translation = position + (direction * forwardOffset)   // start projectile "forward" of camera
        addChild(cube)
        cube.addForce(direction * force, relativeTo: GamePlayManager.physicsOrigin)
        os_log(.default, log: GameLog.general, "pew pew at %s->%s", "\(position)", "\(direction)")
    }

}
