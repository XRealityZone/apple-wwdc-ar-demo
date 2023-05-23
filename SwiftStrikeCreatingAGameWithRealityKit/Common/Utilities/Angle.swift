/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Angle
*/

import Foundation

typealias Angle = Float

extension Angle {

    static let twoPi = 2.0 * Float.pi

    // legalAngle()
    // keep angle such that: -pi < angle <= pi (-180 < angle <= 180)
    static func legalAngle(_ angle: Angle) -> Angle {
        var newAngle = angle
        while newAngle > Float.pi {
            newAngle -= Angle.twoPi
        }
        while newAngle <= -Float.pi {
            newAngle += Angle.twoPi
        }
        return newAngle
    }

    static func subtractAngle(from: Angle, subtract: Angle) -> Angle {
        let from = legalAngle(from)
        let subtract = legalAngle(subtract)

        let shiftedDiff = (from - subtract) + Float.pi
        let mod = shiftedDiff.truncatingRemainder(dividingBy: Angle.twoPi)
        let diff = mod - Float.pi

        return legalAngle(diff)
    }

    // normalizedAngle()
    // This method properly gets input angle into
    // range of [-increment, increment]
    func normalizedAngle(forMinimalRotationTo angle: Self, increment: Self) -> Self {
        var normalized = self
        while abs(normalized - angle) > increment / 2 {
            if self > angle {
                normalized -= increment
            } else {
                normalized += increment
            }
        }
        return normalized
    }

    // sanitizeAngle{}
    // Sanitizes the angle value to be between 0 and 2pi
    static func sanitizeAngle(angle: Self) -> Self {
        let sanitizedAngle = angle.truncatingRemainder(dividingBy: 2 * Float.pi)
        return (sanitizedAngle > 0) ? sanitizedAngle : (sanitizedAngle + 2 * Float.pi)
    }

    static func xzQuaternionAngle(from forward: SIMD3<Float>) -> Angle {
        return legalAngle(atan2(-forward.z, forward.x) - (Float.pi * 0.5))  // quaternion forward is 0 degrees, not 90
    }

}
