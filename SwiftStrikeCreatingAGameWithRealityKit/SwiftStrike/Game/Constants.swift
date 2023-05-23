/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Constants
*/

import RealityKit

enum Constants {
    static let pinWidth: Float = 0.55
    static let pinHeight: Float = 2.1
    static let pinSpacing: Float = 0.8
    static let pinRows = 4
    static let deckOrigin: Float = 3.2
    static let pinMagicYOffset: Float = 0.01 // float the pins 10mm off the ground at startup

    static let bowlingBallRadius: Float = 0.6        // ball radius is 60 cm in Maya

    static let paddleHeight: Float = 2.1
    static let paddleRadius: Float = 0.06875
    static let paddleForceFieldHeight: Float = 2.1
    static let paddleForceFieldRadius: Float = 0.885
    static let paddleWsForceFieldHeight: Float = 1.85   // ~ 6ft. for height of person

    static let beamWidth: Float = 0.55
    static let beamHeight: Float = 4.2

    // this are in local space, so are scaled by the scale below, 1 != meter
    static let remoteLsHeight: Float = 5.8
    static let remoteLsRadius: Float = 0.06875
    static let remoteLsAboveGround: Float = 0.4
    // apply scale to those above to get to local and world space
    static let remoteMsToLsScale: Float = 0.6          // scale applied to RemoteEntity node

    // the forcefield is a child of the remote which is scaled down,
    // these are the values we want in field space, so apply scale to get them into model space
    static let remoteLsForceFieldHeight: Float = 6.2
    static let remoteLsForceFieldRadiusOffset: Float = PhysicsConstants.remoteStrikerRadiusLs - remoteLsRadius
                                                    // 1.05 - 0.06875 = 0.98125
    static let remoteLsForceFieldRadius: Float = paddleForceFieldRadius + remoteLsForceFieldRadiusOffset
                                               // 0.885 + 0.98125 = 1.86625
    // world space z offset from center of court to start
    static let remoteWsStartZ: Float = 5.0
    static let remoteWsForceFieldHeight: Float = 0.6    // in world space, the striker force field is about the radius of the bowling ball

    static let groundWidth: Float = 4.5
    static let groundLength: Float = 14.5

    // ratio to fraction is normally 3:2 as 3/2, however
    // aspect ratio is defined differently such that
    // 4:3 is 3/4:(, so W:H as H/W
    // maintain aspect ratio of groundWidth:groundLength from full court size
    // 4.5/14.5 = 0.310344834
    static let groundAspectRatio: Float = groundLength / groundWidth

    // SwiftStrike Table Top (scaled)
    // 1 m = 3.28 ft
    // target width is about 1' ~=  0.30488 m
    // target default scale is 0.30488' / 4.5' = 0.06775
    static let tableTopMinimumWidth: Float = 0.30488                            // ~1'
    static let tableTopGameScale: Float = tableTopMinimumWidth / groundWidth    // ~0.06775
    static let tableTopMinimumScale: Float = 1 * tableTopGameScale
    static let tableTopMaximumScale: Float = 2 * tableTopGameScale

    static let wallHeight: Float = 2
    static let wallWidth: Float = 0.1
}

extension CollisionGroup {
    // RealityKit defines default = CollisionGroup(rawValue: 1)
    static let ground = CollisionGroup(rawValue: 2)
    static let pin = CollisionGroup(rawValue: 4)
    static let ball = CollisionGroup(rawValue: 8)
    static let paddle = CollisionGroup(rawValue: 16)
    static let forceField = CollisionGroup(rawValue: 32)
    static let wall = CollisionGroup(rawValue: 64)
    static let pinTeamA = CollisionGroup(rawValue: 128)
    // 8 bits ^^
    static let pinTeamB = CollisionGroup(rawValue: 256)
    static let gutter = CollisionGroup(rawValue: 512)
    static let remote = CollisionGroup(rawValue: 1024)
    // up to 32 bits...
}
