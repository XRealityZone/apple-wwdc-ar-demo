/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Billboard components
*/

import RealityKit

// Billboards that only rotate around the Y axis
struct YAxisBillboardComponent: Component {}

// Billboards that are stuck to the floor, only inheriting the X-Z position
struct FloorBillboardComponent: Component {
    // Used to defeat the z-fighting
    // The bias is measured in meters.
    var bias: Float = 0.0
    var floorOffsetThreshold: Float = 0.0
    var scale: Float = 1.0
    var cardOffset: Float = 0.0// How far from the center of the parent is the card?
}

// Billboards that always look at the camera using the axis from the billboard's
// location in world space to the camera as a normal to a plane for the billboard
struct CameraBillboardComponent: Component {
    var rotateToMatchObjectUp: Bool = false
}

extension YAxisBillboardComponent: Codable {}
extension FloorBillboardComponent: Codable {}
extension CameraBillboardComponent: Codable {}

protocol HasYAxisBillboard where Self: Entity {}
protocol HasFloorBillboard where Self: Entity {}
protocol HasCameraBillboard where Self: Entity {}

extension HasYAxisBillboard {
    var yAxisBillboard: YAxisBillboardComponent {
        get { return components[YAxisBillboardComponent.self] ?? YAxisBillboardComponent() }
        set { components[YAxisBillboardComponent.self] = newValue }
    }
    func rotate(lookAt: Transform) {
        guard let parent = self.parent else { return }
        // get camera world space position
        let cameraPosition = lookAt.translation
        var newTransform = transform

        // Y axis rotation towards lookAt in X-Z
        newTransform = newTransform.yAxisLookAtWorldSpacePoint(parentEntity: parent, worldSpaceAt: cameraPosition)

        // since this is a local transorm to this device, we
        // don't want it shipped across the network to other devices.
        // let them figure out their own transform
        self.withUnsynchronized {
            self.transform = newTransform
        }
    }
}

extension HasFloorBillboard {
    var floorBillboard: FloorBillboardComponent {
        get { return components[FloorBillboardComponent.self] ?? FloorBillboardComponent() }
        set { components[FloorBillboardComponent.self] = newValue }
    }
    func rotate(lookAt: Transform) {
        guard let parent = self.parent else { return }
        let parentToWorld = parent.transformMatrix(relativeTo: nil)

        let floorThreshold = floorBillboard.floorOffsetThreshold
        var scaleFactor: Float = floorBillboard.scale

        // get a scale Factor based on how "high" the object
        // is above the surface to shrink the billboard as
        // it gets further from the surface
        if parentToWorld.translation.y < floorThreshold {
            // Entity is below the floor
            scaleFactor = 0
        } else {
            let ballHeight = parentToWorld.translation.y
            let floorCardHeight = ballHeight - floorBillboard.cardOffset
            scaleFactor = max(1 - floorCardHeight, 0)
        }

        // get the bias offset based on the height above the
        // surface, must take into account if there is a
        // scale factor in the hierarchy above us
        let trans = Transform(matrix: parentToWorld)
        var biasOffset = SIMD3<Float>(repeating: 0.0)
        let rot = trans.rotation.inverse
        biasOffset.y -= parentToWorld.translation.y / trans.scale.y * scaleFactor

        biasOffset.y += floorBillboard.bias / trans.scale.y

        // Only allow scale to grow up to 1
        scaleFactor = min(scaleFactor, 1.0)
        floorBillboard.scale = scaleFactor // Put the scale factor back

        let scale = SIMD3<Float>(repeating: floorBillboard.scale)
        let newTransform = Transform(scale: scale, rotation: rot, translation: rot.act(biasOffset))

        // since this is a local transorm to this device, we
        // don't want it shipped across the network to other devices.
        // let them figure out their own transform
        self.withUnsynchronized {
            self.transform = newTransform
        }
    }
}

extension HasCameraBillboard {
    var cameraBillboard: CameraBillboardComponent {
        get { return components[CameraBillboardComponent.self] ?? CameraBillboardComponent() }
        set { components[CameraBillboardComponent.self] = newValue }
    }
    func rotate(lookAt: Transform) {
        guard let parent = self.parent else { return }
        // get camera world space position
        let cameraPosition = lookAt.translation
        var newTransform: Transform = self.transform

        var withRotation = cameraBillboard.rotateToMatchObjectUp
        if withRotation != UserSettings.glowRotateWithBall {
            withRotation = UserSettings.glowRotateWithBall
        }
        if !withRotation {
            let cameraUp = lookAt.matrix.columns.1.xyz
            newTransform = newTransform.lookAtWorldSpacePoint(parentEntity: parent, worldSpaceAt: cameraPosition, worldSpaceUp: cameraUp)
        } else {
            // get entity up in local space
            let localSpaceUp = SIMD3<Float>(0.0, 1.0, 0.0)
            newTransform = newTransform.lookAtWorldSpacePointWithRotation(parentEntity: parent,
                                                                          worldSpaceAt: cameraPosition, localSpaceUp: localSpaceUp)
        }

        // since this is a local transorm to this device, we
        // don't want it shipped across the network to other devices.
        // let them figure out their own transform
        self.withUnsynchronized {
            self.transform = newTransform
        }
    }
}

final class FloorBillboardEntity: Entity, HasFloorBillboard {}
final class YAxisBillboardEntity: Entity, HasYAxisBillboard {}
final class CameraBillboardEntity: Entity, HasCameraBillboard {}
