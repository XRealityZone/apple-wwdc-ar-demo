/*
See LICENSE folder for this sample’s licensing information.

Abstract:
StandUprightComponent
*/

import RealityKit

/// - Tag: StandUprightComponent
struct StandUprightComponent: Component {}

extension StandUprightComponent: Codable {}

/// - Tag: HasStandUpright
protocol HasStandUpright where Self: Entity {}

extension HasStandUpright {
    
    var standUpright: StandUprightComponent {
        get { return components[StandUprightComponent.self] ?? StandUprightComponent() }
        set { components[StandUprightComponent.self] = newValue }
    }

    func forceStandUpright() {
        let transformToWorld = transformMatrix(relativeTo: GamePlayManager.physicsOrigin)
        let oldTransform = Transform(matrix: transformToWorld)
        let uprightRotation = simd_quatf(angle: transformToWorld.rotationAboutY, axis: [0, 1, 0])
        let result = Transform(scale: oldTransform.scale, rotation: uprightRotation, translation: oldTransform.translation)
        setTransformMatrix(result.matrix, relativeTo: GamePlayManager.physicsOrigin)

        // force this Entity to have no translation offset relative
        // to its parent - used in PaddleEntity and PlayerTeamEntity, children of PlayerLocationEntity (for Full Court),
        // and PlayerTeamEntity, child of RemoteEntity (for Table Top)
        self.transform.translation = .zero
    }
}
