/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Responsible for tracking the state of the game: which objects are where, who's in the game, etc.
*/

import RealityKit

enum CollisionEvent {
    case began(CollisionEvents.Began)
    case updated(CollisionEvents.Updated)
    case ended(CollisionEvents.Ended)
}
