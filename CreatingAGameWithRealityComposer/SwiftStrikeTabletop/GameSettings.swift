/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The sample app's game settings.
*/

import Foundation
import CoreGraphics

extension Experience {
    struct GameSettings {
        /// An integer that represents the current level.
        let numberOfLevels = 4
        
        /// A duration for user interface animations such as pop-ups.
        let uiAnimationDuration: TimeInterval = 0.33
        
        /// The time to wait for struck pins to settle after the ball comes to a stop.
        let frameSettleDelay: TimeInterval = 1.5
        
        /// The time to wait for the frame to end before assuming that the ball has fallen out of the play area.
        let stuckFrameDelay: TimeInterval = 5.0

        /// A horizontal factor that represents the amount of leeway to determine whether a pin has fallen over.
        let pinTipThreshold: Float = 0.1
        
        /// The number of pins at which a frame will be considered "good" to allow advancing to the next level (10 is a strike).
        let goodFrameThreshold = 8
        
        /// A threshhold applied the user's swipe gesture that determines whether to shoot the ball.
        let ballPlayDistanceThreshold: Float = 0.5
        
        /// The minimum ball velocity in the x-direction.
        let ballVelocityMinX: Float = -0.8
        
        /// The maximum ball velocity in the x-direction.
        let ballVelocityMaxX: Float = 0.8
        
        /// The minimum ball velocity in the z-direction.
        let ballVelocityMinZ: Float = -4.0
        
        /// The maximum ball velocity in the z-direction.
        let ballVelocityMaxZ: Float = 0.1
    }
}
