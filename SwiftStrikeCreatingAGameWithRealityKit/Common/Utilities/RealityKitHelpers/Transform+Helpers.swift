/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Convenience extensions for RealityKit Entities
*/

import os.log
import RealityKit

// Plane is a 3D math primitive missing from the RealityKit swift api for now.
// Plane is needed for the Transform extensions below (also missing from the RealityKit swift api)
struct Plane {
    // Point-Normal form of a Plane equation:
    //   where n is a normal to a plane, n = (a, b, c)
    //   and p is a point on a plane, p = (x, y, z)
    //   and (x, y, z) is any point on the plane
    //   point-normal form of a plane is:
    //     (n.a, n.b, n.c)⋅(x−p.x, y−p.y, z−p.z) = 0
    // Intercept or Normal-Constant form of a Plane equation:
    //   where n is a normal to a plane, n = (a, b, c)
    //   and (x, y, z) is any point on the plane
    //   intercept/normal-constant form of a plane is:
    //     (n.a * x) + (n.b * y) + (n.c * z) + d = 0
    private var normal: SIMD3<Float>
    private var pointOnPlane: SIMD3<Float>

    private var parallelToPlaneThreshold: Float = Float.ulpOfOne

    /// Intercept or Normal-Constant form of a Plane
    init(normal: SIMD3<Float>, d constant: Float) {
        self.normal = normalize(normal)
        self.pointOnPlane = Plane.calcPointOnPlane(normal, constant)
    }

    /// Point-Normal form of a Plane
    init(point: SIMD3<Float>, normal: SIMD3<Float>) {
        self.normal = normalize(normal)
        self.pointOnPlane = point
    }

    /// Three points determine a plane
    init(point0: SIMD3<Float>, point1: SIMD3<Float>, point2: SIMD3<Float>) {
        let point1ToPoint0 = point0 - point1
        let point0ToPoint2 = point2 - point0
        normal = normalize(cross(point1ToPoint0, point0ToPoint2))
        pointOnPlane = point0
    }

    static private func calcPointOnPlane(_ normal: SIMD3<Float>, _ dConstant: Float) -> SIMD3<Float> {
        var pointOnPlane = SIMD3<Float>(repeating: 0.0)
        let absX = abs(normal.x)
        let absY = abs(normal.y)
        let absZ = abs(normal.z)
        if absX > absY && absX > absZ {
           pointOnPlane.x = -dConstant / normal.x
        } else if absY > absX && absY > absZ {
           pointOnPlane.y = -dConstant / normal.y
        } else /*if absZ > absX && absZ > absY*/ {
           pointOnPlane.z = -dConstant / normal.z
        }
        return pointOnPlane
    }

    var parallelToPlaneTolerance: Float {
        get { return parallelToPlaneThreshold }
        set { parallelToPlaneThreshold = newValue }
    }
}

extension Plane {

    // projectNormalOnToPlane()
    // returns SIMD3<Float> - the normal that represents the projection of the input normal onto the plane.
    func projectNormalOnToPlane(normal normalToProject: SIMD3<Float>) -> SIMD3<Float> {
        // incoming normalToProject is the direction from plane origin we want to project onto plane
        
        // length of normalToProject projected onto plane normal
        var length = dot(normalToProject, normal)
        if abs(length) <= Float.ulpOfOne {
            os_log(.error, log: GameLog.general, "Error: projectNormalOnToPlane() abs dot product %s near zero - can't project")
            if length < 0.0 {
               length = -Float.ulpOfOne
            } else {
                length = Float.ulpOfOne
            }
            // continue with projection
        }

        // use length of normalToProject projected onto plane normal to get point on parallel plane offset by normalToProject
        let pointOnNormal = normal * length

        // need a point based on the normalToProject to drop onto plane
        let point = pointOnPlane + normalToProject

        // subtract point projected onto normal from point to get point on plane
        let result = point - pointOnNormal

        return normalize(result)
    }

    // rayIntersect()
    // rreturns SIMD3<Float> - the intersection point of the ray from rayStart, in the direction
    //                         of rayDirection, with the plane
    func rayIntersect(rayStart: SIMD3<Float>, rayDirection: SIMD3<Float>) -> SIMD3<Float>? {
        let denom = dot(rayDirection, normal)
        if abs(denom) > parallelToPlaneThreshold {
            let rayStartToPlane = pointOnPlane - rayStart
            let tIntersect = dot(rayStartToPlane, normal) / denom
            return rayStart + (tIntersect * rayDirection)
        }
        return nil
    }
}

extension Transform {

    // these methods are needed because the RealityKit provided method, Entity.look(at:from:upVector:relativeTo:) inverts
    // the Z axis.  While this is useful for cameras and lights, it is the opposite of what is needed for billboards

    // lookAtWorldSpacePoint()
    // support for fully camera facing billboard.  i.e. a glow texture around a spherical object like a bowling ball
    // which is made to always face the camera
    func lookAtWorldSpacePoint(parentEntity: Entity,
                               worldSpaceAt: SIMD3<Float>,
                               worldSpaceUp: SIMD3<Float> = SIMD3<Float>(0, 1, 0)
    ) -> Transform {

        // worldSpaceToParentSpace is the to-parent-space-from-world-space transfrorm (for us)
        let worldSpaceToParentSpace = parentEntity.transformMatrix(relativeTo: nil).inverse

        let lsTarget = worldSpaceToParentSpace * SIMD4<Float>(worldSpaceAt.x, worldSpaceAt.y, worldSpaceAt.z, 1.0)
        // local space position is transform.translation
        let position = translation
        let lsPosition = SIMD4<Float>(position.x, position.y, position.z, 1.0)
        let lsUpVector = normalize(worldSpaceToParentSpace * SIMD4<Float>(worldSpaceUp.x, worldSpaceUp.y, worldSpaceUp.z, 0.0))

        let positionToTarget = lsTarget.xyz - lsPosition.xyz
        let zAxis = normalize(positionToTarget)

        // check if up vector and zAxis are same and so
        // cross product will not give good result
        let cosAngle = abs(dot(lsUpVector.xyz, zAxis))
        let xAxis = normalize(cross(lsUpVector.xyz, zAxis))
        if cosAngle >= (Float(1.0) - .ulpOfOne) {
            os_log(.error, log: GameLog.general, "Error: up=(%s), z=(%s), cross is x=(%s)", "\(lsUpVector)", "\(zAxis)", "\(xAxis)")
        }
        let yAxis = cross(zAxis, xAxis)

        let matrix = float4x4(SIMD4<Float>(xAxis.x, xAxis.y, xAxis.z, 0),
                              SIMD4<Float>(yAxis.x, yAxis.y, yAxis.z, 0),
                              SIMD4<Float>(zAxis.x, zAxis.y, zAxis.z, 0),
                              SIMD4<Float>(lsPosition.x, lsPosition.y, lsPosition.z, 1))
        let transform = Transform(matrix: matrix)
        return transform
    }

    // this method provides an additional feature beyond what lookAtWorldSpacePoint() does above; it adds
    // the capability to rotate the billboard such that the "up" matches the Entity "up".
    func lookAtWorldSpacePointWithRotation(parentEntity: Entity,
                                           worldSpaceAt: SIMD3<Float>,
                                           localSpaceUp: SIMD3<Float> = SIMD3<Float>(0, 1, 0)
    ) -> Transform {

        // worldSpaceToParentSpace is the to-parent-space-from-world-space transfrorm (for us)
        let worldSpaceToParentSpace = parentEntity.transformMatrix(relativeTo: nil).inverse

        let lsTarget = worldSpaceToParentSpace * SIMD4<Float>(worldSpaceAt.x, worldSpaceAt.y, worldSpaceAt.z, 1.0)
        // local space position is transform.translation
        let position = translation
        let lsPosition = SIMD4<Float>(position.x, position.y, position.z, 1.0)

        let positionToTarget = lsTarget.xyz - lsPosition.xyz
        let zAxis = normalize(positionToTarget)
        let plane = Plane(point: lsPosition.xyz, normal: zAxis)
        let localUp = normalize(localSpaceUp)
        let newUp = plane.projectNormalOnToPlane(normal: localUp)

        // check if up vector and zAxis are same and so
        // cross product will not give good result
        let cosAngle = abs(dot(newUp, zAxis))
        let xAxis = normalize(cross(newUp, zAxis))
        if cosAngle >= (Float(1.0) - .ulpOfOne) {
            os_log(.error, log: GameLog.general, "Error: up=(%s), z=(%s), cross is x=(%s)", "\(newUp)", "\(zAxis)", "\(xAxis)")
            let xAxis = normalize(cross(SIMD3<Float>(0, 1, 0), zAxis))
            os_log(.error, log: GameLog.general, "       new x=%s", "\(xAxis)")
        }
        let yAxis = cross(zAxis, xAxis)

        let matrix = float4x4(SIMD4<Float>(xAxis.x, xAxis.y, xAxis.z, 0),
                              SIMD4<Float>(yAxis.x, yAxis.y, yAxis.z, 0),
                              SIMD4<Float>(zAxis.x, zAxis.y, zAxis.z, 0),
                              SIMD4<Float>(lsPosition.x, lsPosition.y, lsPosition.z, 1))
        let transform = Transform(matrix: matrix)
        return transform
    }

    // yAxisLookAtWorldSpacePoint()
    // support for camera facing billboard which only rotates around the Y axis.  i.e. a glow texture around a vertical
    // object such as a bowling pin which is made to always face the camera
    func yAxisLookAtWorldSpacePoint(parentEntity: Entity, worldSpaceAt: SIMD3<Float>) -> Transform {

        // worldSpaceToParentSpace is the to-parent-space-from-world-space transfrorm (for us)
        let worldSpaceToParentSpace = parentEntity.transformMatrix(relativeTo: nil).inverse

        let lsTarget = worldSpaceToParentSpace * SIMD4<Float>(worldSpaceAt.x, worldSpaceAt.y, worldSpaceAt.z, 1.0)
        // local space position is transform.translation
        let position = translation
        let lsPosition = SIMD4<Float>(position.x, position.y, position.z, 1.0)
        let lsUpVector = SIMD4<Float>(0.0, 1.0, 0.0, 0.0)

        var positionToTarget = lsTarget.xyz - lsPosition.xyz
        positionToTarget.y = 0
        let zAxis = normalize(positionToTarget)

        // check if up vector and zAxis are same and so
        // cross product will not give good result
        let cosAngle = abs(dot(lsUpVector.xyz, zAxis))
        let xAxis = normalize(cross(lsUpVector.xyz, zAxis))
        if cosAngle >= (Float(1.0) - .ulpOfOne) {
            os_log(.error, log: GameLog.general, "Error: up=(%s), z=(%s), cross is x=(%s)", "\(lsUpVector)", "\(zAxis)", "\(xAxis)")
        }
        let yAxis = cross(zAxis, xAxis)

        let matrix = float4x4(SIMD4<Float>(xAxis.x, xAxis.y, xAxis.z, 0),
                              SIMD4<Float>(yAxis.x, yAxis.y, yAxis.z, 0),
                              SIMD4<Float>(zAxis.x, zAxis.y, zAxis.z, 0),
                              SIMD4<Float>(lsPosition.x, lsPosition.y, lsPosition.z, 1))
        var transform = Transform(matrix: matrix)

        let scale = UserSettings.glowScale
        if scale != 1.0 {
            transform.scale = SIMD3<Float>(repeating: scale)
        }
        return transform
    }

}
