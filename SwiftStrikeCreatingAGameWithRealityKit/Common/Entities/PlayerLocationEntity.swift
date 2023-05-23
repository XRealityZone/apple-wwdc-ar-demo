/*
See LICENSE folder for this sample’s licensing information.

Abstract:
PlayerLocationEntity
*/

import RealityKit

/// PlayerLocationEntity
///  Each device participating in the game adds an entity which represents
/// the device location, adds the device identifier, and maintains ownership.
/// The host then adds the functional content as sub-entities of this entity, and
/// maintains ownership of those.
/// The goal is to allow the player devices to update their location, but the host
/// has control over whether and how the content participates in the scene.
class PlayerLocationEntity: Entity, HasDeviceIdentifier {

    func configure() {
        deviceIdentifier = DeviceIdentifierComponent()
    }

    func playerTeamEntity(scene: Scene) -> PlayerTeamEntity? {
        for child in children where child is PlayerTeamEntity {
            return child as? PlayerTeamEntity
        }

        for playerTeamEntity in scene.playerTeamEntities() where playerTeamEntity.deviceUUID == deviceUUID {
            return playerTeamEntity
        }
        return nil
    }

}
