/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Physics defaults
*/

import UIKit

enum PhysicsConstants {
    /// Pin weight of 3 lbs, 8 oz. =  3.5 lbs = 1.5876 kg
    /// Pins are 12" from center to center for placement with back pins being 3 1/6" from end of lane
    /// The front pin is therefore about 34 3/16" from the center of the back pins, centered in the lane
    /// Lane is 41 1/2" wide with 7 & 10 pins being centered 2 3/4" from edge
    static let pinMass: Float = 3.0
    static let pinStaticFriction: Float = 0.8
    static let pinKineticFriction: Float = 0.8
    static let pinRestitution: Float = 0.5
    static let pinCenterOfMass: Float = 0.8
    static let pinCenterDistance: Float = 0.3048    // 0.3048 m = 12" pin center to center

    static let ballMass: Float = 10.0
    static let ballStaticFriction: Float = 0.7
    static let ballKineticFriction: Float = 0.7    // 0.32 from p. 34, Bowling, Melissa Abramovitz
    static let ballRestitution: Float = 0.8

    static let paddleMass: Float = 100.0
    static let paddleFriction: Float = 0.9
    static let paddleRestitution: Float = 0.9

    static let remoteMass: Float = 50.0
    static let remoteFriction: Float = 0.5
    static let remoteRestitution: Float = 0.9
    static let remoteStrikerRadiusLs: Float = 1.05
    static let remoteStrikerAboveGroundLs: Float = 0.08
    static let remoteIndicatorAboveGroundLs: Float = 0.0167

    static let wallMass: Float = 1.0
    static let wallFriction: Float = 0.7
    static let wallRestitution: Float = 0.5

    static let groundMass: Float = 1.0
    static let groundFriction: Float = 0.7
    static let groundRestitution: Float = 0.01

    static let ballScale: Float = 1.0
    static let leafBlowerForce: Float = 100
    static let kickSpeedThreshold: Float = 2.0
    static let kickSpeedModifier: Float = 0.5
    // speed required to reset the sound system for another kick, component velocity in the forwards direction of the iPad.
    static let kickSpeedResetThreshold: Float = 0.3
}

