/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Swept Circle
*/

import os.log
import simd

extension GameLog {
    static let sweptCircle = OSLog(subsystem: subsystem, category: "sweptCircle")
}

struct SweptCircle {

    static let denominatorTooCloseToZero: Float = 1E-5
    static let distanceTooCloseToZero: Float = 1E-5

    var position: SIMD2<Float>       // m
    var velocity: SIMD2<Float>       // m/s
    private var radius: Float               // m
    private var mass: Float                 // kg

    var newPosition = SIMD2<Float>() // m
    var newVelocity = SIMD2<Float>() // m/s

    init(origin: SIMD2<Float>, velocity: SIMD2<Float>, radius: Float, mass: Float) {
        self.position = origin
        self.velocity = velocity
        self.radius = radius
        self.mass = mass
    }

    func impulse(_ oldVelocity: SIMD2<Float>) -> SIMD2<Float> {
        let delta = newVelocity - oldVelocity
        return delta * mass
    }
}

extension SweptCircle {

    static func timeOfCollision(sc0: SweptCircle, sc1: SweptCircle, deltaTime: Float) -> Float? {
        let p0Top1 = sc1.position - sc0.position
        let moving0AwayFrom1 = dot(sc0.velocity, p0Top1) < 0.0
        let moving1AwayFrom0 = dot(sc1.velocity, p0Top1) > 0.0
        if moving0AwayFrom1, moving1AwayFrom0 {
            // ignore collision, let cirlces continue
            // to move in correct directions, away
            // from collision
            return nil
        }

        // Based on parametric equation for line, p' = p + nt, where p is orgin,
        // n is normal direction, and t is time, we replace n with v for velocity
        // p' = p + vt such that p' represents the end point after applying velocity
        // v for time t so, for two cirlces in motion...
        //     p0' = p0 + v0t
        //     p1' = p1 + v1t
        // squared distance between the two points at any time t on lines
        // is:
        //     distSquared = (p1'-p0').(p1'-p0')
        //     f(t) = |(p1 + v1t) - (p0 + v0t)|^2
        let radiiSum = sc0.radius + sc1.radius
        let radiiSumSquared = radiiSum * radiiSum

        // With radius added:
        //      |(p1 + v1t) - (p0 + v0t)| = r0 + r1
        //      |(p1 + v1t) - (p0 + v0t)|^2 = (r0 + r1)^2
        //      ((p1 + v1t) - (p0 + v0t)).((p1 + v1t) - (p0 + v0t)) = (r0 + r1)^2
        //      (p1 + v1t - p0 - v0t).(p1 + v1t - p0 - v0t) = (r0 + r1)^2
        //      ((p1 - p0) + t(v1 - v0)).((p1 - p0) + t(v1 - v0)) = (r0 + r1)^2
        //      t^2(v1 - v0).(v1 - v0) + 2t(v1 - v0).(p1 - p0) + (p1 - p0).(p1 - p0) - (r0 + r1)^2 = 0
        // where roots of t are the time when collision starts/ends
        let frameVelocity0 = sc0.velocity * deltaTime
        let frameVelocity1 = sc1.velocity * deltaTime
        let v0Tov1 = frameVelocity1 - frameVelocity0

        // Quadratic where:
        // c = (p1 - p0).(p1 - p0) - (r0 + r1)^2
        // c represents initial collision state
        // c <= 0 means in collision
        // c > 0 means no initial collision
        let dSqaured = dot(p0Top1, p0Top1)
        let cValue = dSqaured - radiiSumSquared

        // a = (v1 - v0).(v1 - v0)
        let aValue = dot(v0Tov1, v0Tov1)
        if abs(aValue) < denominatorTooCloseToZero {
            // denominator (2a) too close to 0,
            // velocities cannot cause intersect,
            // however, check if in intersection
            // to begin with
            // -radiiSumSquared < c < 0 means intersaction/overlap
            // c == -radiiSumSquared means @ same position
            // c == 0 means touching
            if cValue <= -radiiSumSquared {
                // can't resolve same position, no velocity
                return nil
            } else if cValue < -distanceTooCloseToZero {
                // we have an initial intersection state with little or no velocity
                return 0.0
            }
            return nil
        }

        // b = 2 * (v1 - v0).(p1 - p0)
        let bValue = 2 * dot(v0Tov1, p0Top1)

        // (-b +- sqrt(b^2 - 4ac)) / 2a
        let inv2a = 1.0 / (2.0 * aValue)
        let minusB = -bValue * inv2a
        let b2Minus4ac = (bValue * bValue) - (4 * aValue * cValue)
        if b2Minus4ac < 0 {
            // negative value for sqrt with means no roots
            return nil
        }
        let srt = sqrt(b2Minus4ac) * inv2a

        // we care about the smallest root
        // since that indicates the collision
        // closest to the start position
        var root1 = minusB - srt
        let root2 = minusB + srt
        if root2 < root1 {
            root1 = root2
        }
        // root1 is earliest time of collision
        // root2 is latest time of collision
        // so circles are in collision from time root1 to root2
        // 0.0 is the begining of the detla time
        // 1.0 is the end of the delta time

        if root1 > 1.0 {
            return nil
        }

        if root2 < -1.0 {
            return nil
        }

        os_log(.default, log: GameLog.sweptCircle, "root1 = %.04f, root2 == %.04f", root1, root2)

        if root1 < 0.0, root1 > -1.0, cValue < 0.0 {
            // We're in an overlapping collision already where
            // motion collision happened in timestep in the past
            // back circles up to time of collision,
            // and then do reaction
            if root2 >= 0.0, root2 <= 1.0, abs(root2) <= abs(root1) {
                return root2
            }
            return root1
        }

        if root1 >= 0.0/*, root1 <= 1.0*/ {
            return root1
        }

        if root2 > 0.0 {
            return root2
        }

        return nil
    }

    static func moveOutOfCollision(sc0: inout SweptCircle, sc1: inout SweptCircle) -> Bool {
        let p0Top1 = sc1.position - sc0.position
        let p0Top1Normal = normalize(p0Top1)
        let distanceP0ToP1 = length(p0Top1)
        let radiiSum = sc0.radius + sc1.radius
        let midDistance = (radiiSum - distanceP0ToP1) * 0.5
        guard midDistance > 0 else { return false }
        sc0.newPosition = sc0.position + p0Top1Normal * -midDistance
        sc1.newPosition = sc1.position + p0Top1Normal * midDistance
        return true
    }

    static func moveToCollision(sc0: inout SweptCircle, sc1: inout SweptCircle,
                                deltaTime: Float, tIntersect: Float?) {
        let time = (tIntersect ?? 1.0) * deltaTime
        sc0.newPosition = sc0.position + (sc0.velocity * time)
        sc1.newPosition = sc1.position + (sc1.velocity * time)
    }

    static func reactToCollision(sc0: inout SweptCircle, sc1: inout SweptCircle) {
        let p0Top1 = sc1.newPosition - sc0.newPosition
        let moving0AwayFrom1 = dot(sc0.velocity, p0Top1) < 0.0
        let moving1AwayFrom0 = dot(sc1.velocity, p0Top1) > 0.0
        if moving0AwayFrom1, moving1AwayFrom0 {
            // ignore collision, let cirlces continue
            // to move in correct directions, away
            // from collision
            return
        }

        /// conservation of momentum
        /// m1v1 + m2v2 =  m1v1′ + m2v2′
        /// w1 = (m1 - m2)v1/M + 2m2v2/M
        /// w2 = (m2 - m1)v2/M + 2m1v1/M
        /// for second body velocity
        /// v1' = v1 - (2m2/(m1+m2))*(<(V1-V2),(X1-X2)>/(||X1-X2||^2)) * (X1-X2)
        /// v2' = v2 - (2m1/(m1+m2))*(<(V2-V1),(X2-X1)>/(||X2-X1||^2)) * (X2-X1)
        let massSum = sc0.mass + sc1.mass
        guard massSum > SweptCircle.denominatorTooCloseToZero else { return }
        let invM = 1.0 / massSum

        // v0'
        /// v0' = v0 - (2m1/(m0+m1))*(<(V0-V1),(X0-X1)>/(||X0-X1||^2)) * (X0-X1)
        var massRatio = (2 * sc1.mass) * invM
        let delta10 = sc0.newPosition - sc1.newPosition
        let lengthPosition10Squared = dot(delta10, delta10)
        let velocity10 = sc0.velocity - sc1.velocity
        if lengthPosition10Squared > denominatorTooCloseToZero {
            let v10DotX10 = dot(velocity10, delta10)
            sc0.newVelocity -= ((massRatio * (v10DotX10 / lengthPosition10Squared)) * delta10)
        }

        // v1'
        /// v1' = v1 - (2m0/(m0+m1))*(<(V1-V0),(X1-X0)>/(||X1-X0||^2)) * (X1-X0)
        massRatio = (2 * sc0.mass) * invM
        let delta01 = -delta10
        let lengthPosition01Squared = dot(delta01, delta01)
        if lengthPosition01Squared > denominatorTooCloseToZero {
            let velocity01 = -velocity10
            let v01DotX01 = dot(velocity01, delta01)
            sc1.newVelocity -= ((massRatio * (v01DotX01 / lengthPosition01Squared)) * delta01)
        }
    }

    static func singleIteration(_ sc0: inout SweptCircle, _ sc1: inout SweptCircle,
                                _ deltaTime: Float) -> Float? {
        let collideT = timeOfCollision(sc0: sc0, sc1: sc1, deltaTime: deltaTime)
        if collideT == 0.0 {
            // push colliders away from each other to not be in collision
            // then try again...
            if moveOutOfCollision(sc0: &sc0, sc1: &sc1) {
                // if there was any velocity, we shouldn't be
                // here because we'll miss the swap of velocities
                // (conservation of momentum) in reactToCollision
                // below
                return 0.0
            }
        }
        moveToCollision(sc0: &sc0, sc1: &sc1, deltaTime: deltaTime, tIntersect: collideT)
        sc0.newVelocity = sc0.velocity
        sc1.newVelocity = sc1.velocity
        // if collision, then we need a reaction
        if collideT != nil {
            reactToCollision(sc0: &sc0, sc1: &sc1)
        }
        return collideT
    }

    static func iterateUntilDone(_ sc0: inout SweptCircle, _ sc1: inout SweptCircle,
                                 _ deltaTime: Float) -> (Float?, Int) {
        var firstCollideT: Float?
        var dtLeft = deltaTime
        let iterationMax = 3    // to prevent inner method call logic errors from causing infinite loop
        var iteration = 0
        while dtLeft > 0.0, iteration < iterationMax {
            if let collideT = singleIteration(&sc0, &sc1, dtLeft) {
                if iteration == 0 {
                    firstCollideT = collideT
                }
                iteration += 1
                // since we allow t to be in the past in the
                // the case of previously existing overlapping
                // collision, we need abs(t)
                dtLeft -= abs(collideT) * dtLeft
                sc0.position = sc0.newPosition
                sc1.position = sc1.newPosition
                sc0.velocity = sc0.newVelocity
                sc1.velocity = sc1.newVelocity
            } else {
                dtLeft = 0.0
            }
        }
        return (firstCollideT, iteration)
    }

}
