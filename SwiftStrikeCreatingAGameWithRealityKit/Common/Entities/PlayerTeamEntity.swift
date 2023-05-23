/*
See LICENSE folder for this sample’s licensing information.

Abstract:
PlayerTeamEntity
*/

import Foundation
import os.log
import RealityKit

class PlayerTeamEntity: Entity, HasCollision, HasStandUpright, HasDeviceIdentifier, HasPlayerTeam, HasCollisionSize {

    func configure(named name: String, id: UUID, capsuleHeight: Float, capsuleRadius: Float) {
        self.name = "Player Team \(name)"
        standUpright = StandUprightComponent()
        deviceIdentifier = DeviceIdentifierComponent(id)
        playerTeam = PlayerTeamComponent()
        collisionSize = CollisionSizeComponent(shape: .capsule(totalHeight: capsuleHeight, radius: capsuleRadius, mass: 0.0))
        let shape = ShapeResource.createCapsule(totalHeight: collisionSize.shape.totalHeight, radius: capsuleRadius)
        collision = CollisionComponent(shapes: [shape], mode: .trigger, filter: .sensor)
    }

    /// Return true if the given instance of `PlayerTeamEntity` represents the player local to the running device.
    var isLocalPlayer: Bool {
        if let playerLocationEntity = playerLocationEntity(), playerLocationEntity.isOwner {
            return true
        }
        if let remoteEntity = remoteEntity, remoteEntity.isOwner {
            return true
        }
        return false
    }

    ///
    /// remoteEntity()
    /// this method will only return the RemoteEntity if it is the parent
    /// of the PlayerTeamEntity - this indicates Table Top gameplay
    var remoteEntity: RemoteEntity? {
        // for Table Top, the parent of the PlayerTeamEntity is the RemoteEntity
        return self.parent as? RemoteEntity
    }

    ///
    /// playerLocationEntity(scene)
    /// if scene is nil, this method will only return the PlayerLocationEntity if it is the parent
    /// of the PlayerTeamEnitty - this indicates Full Court gameplay
    /// if scene is valid, this method will return PlayerLocationEntity whether we are in Full Court or Table Top
    /// the method uses the parent, either a PlayerLocationEntity or a RemoteEntity to determine
    /// how to find the PlayerLocationEntity
    func playerLocationEntity(scene: Scene? = nil) -> PlayerLocationEntity? {
        guard let parent = parent else { return nil }
        // for Full Court, the parent of the PlayerTeamEntity is the PlayerLocationEntity
        if let playerLocationEntity = parent as? PlayerLocationEntity {
            return playerLocationEntity
        }

        // for TableTop, the parent of the PlayerTeamEntity is the RemoteEntity,
        // not PlayerLocationEntity, so we have to find the matching PlayerLocationEntity
        if let remoteEntity = parent as? RemoteEntity, let scene = scene {
            let entities = scene.playerLocationEntities()
            guard !entities.isEmpty else { return nil }

            return entities.first { playerLocationEntity in
                return remoteEntity.deviceUUID == playerLocationEntity.deviceUUID
            }
        }
        return nil
    }

    private func assignPlayerTeam(status gameTeamStatus: inout GameTeamStatus, team newTeam: Team) {
        guard onTeam != newTeam else { return }
        // only operate if team is different than current team

        if gameTeamStatus.newPlayerTeam(for: deviceUUID, newTeam) {
            onTeam = newTeam
            os_log(.default, log: GameLog.teamStatus, "UUID %s set to %s", "\(deviceUUID)", "\(newTeam)")
        } else {
            os_log(.default, log: GameLog.teamStatus, "UUID %s set to %s - FAILED", "\(deviceUUID)", "\(newTeam)")
        }
    }

    private func findOtherPlayerTeamEntity(scene: Scene, notId: UUID) -> PlayerTeamEntity? {
        let otherTeamEntity = scene.playerTeamEntities().first { playerTeamEntity in
            if let playerLocationEntity = playerTeamEntity.playerLocationEntity() {
                if playerLocationEntity.deviceUUID != notId {
                    return true
                }
            } else if let remoteEntity = playerTeamEntity.remoteEntity {
                if remoteEntity.deviceUUID != notId {
                    return true
                }
            }
            return false
        }
        return otherTeamEntity
    }

    func updatePlayerReady(scene: Scene, status gameTeamStatus: inout GameTeamStatus, team: Team, ready: Bool) {
        let playerLocationEntity = self.playerLocationEntity()
        let remoteEntity = self.remoteEntity
        var playerId: UUID
        if let playerLocationEntity = playerLocationEntity {
            playerId = playerLocationEntity.deviceUUID
        } else if let remoteEntity = remoteEntity {
            playerId = remoteEntity.deviceUUID
        } else {
            return
        }

        let wasReady = gameTeamStatus.playerReady(playerId) == team
        guard ready != wasReady else { return }
        // only want to do any work on edges into/out of game ready state

        let otherPlayerTeamEntity = findOtherPlayerTeamEntity(scene: scene, notId: playerId)
        let otherPlayerId = otherPlayerTeamEntity?.deviceUUID

        gameTeamStatus.newPlayerReady(for: playerId, ready ? team : .none)

        // if we started game already, and are re-entering beams
        // after ball falls in gutter, then we have no more team
        // selection - this is handled internally by assignPlayerTeam()
        if ready {
            // moved into a beam, so we want to acquire that team
            // as long as the other player is not ready in the same
            // team beam, if other player is already for this team,
            // but no longer in the beam, take over team:)
            if otherPlayerId == nil || gameTeamStatus.playerReady(otherPlayerId!) != team {
                if let otherPlayerId = otherPlayerId {
                    if gameTeamStatus.playerTeam(otherPlayerId) == team {
                        otherPlayerTeamEntity!.assignPlayerTeam(status: &gameTeamStatus, team: team.opponent)
                    }
                }
                assignPlayerTeam(status: &gameTeamStatus, team: team)
            }
        } else {
            // made not ready, so we want to retain team unless
            // other player is ready and not already on the team,
            // in which case we want to switch teams and assign the,
            // other player to this team
            if let otherPlayerId = otherPlayerId {
                if gameTeamStatus.playerReady(otherPlayerId) == team
                && gameTeamStatus.playerTeam(otherPlayerId) != team {
                    assignPlayerTeam(status: &gameTeamStatus, team: team.opponent)
                    otherPlayerTeamEntity!.assignPlayerTeam(status: &gameTeamStatus, team: team)
                }
            }
        }
    }

    static func setTeamsIfNotSet(scene: Scene, status gameTeamStatus: inout GameTeamStatus) {
        // if spectator host force starts a game (or we use a cheat),
        // and any player(s) never entered a beam of light, then the
        // game and pin status view do not know which team the player
        // is on.  If the any PlayerLocationEntity with an identifier
        // does not have a team set, pin status view does not have a team set,
        // try to guess based on which end of the field the camera is
        // on
        let playerTeamEntities = scene.playerTeamEntities()
        guard !playerTeamEntities.isEmpty else { return }
        let playerTeamEntity = playerTeamEntities[0]
        var playerTeam = playerTeamEntity.onTeam

        var otherPlayerTeamEntity: PlayerTeamEntity?
        var otherTeam: Team?
        if playerTeamEntities.count > 1 {
            otherPlayerTeamEntity = playerTeamEntities[1]
            otherTeam = otherPlayerTeamEntity!.onTeam
        }

        if playerTeam == .none {
            if let otherTeam = otherTeam, otherTeam != .none {
                playerTeam = otherTeam.opponent
            } else {
                playerTeam = Team.defaultTeam(
                    for: playerTeamEntity.transformMatrix(
                        relativeTo: GamePlayManager.physicsOrigin).translation.z)
            }
            playerTeamEntity.assignPlayerTeam(status: &gameTeamStatus, team: playerTeam)
        }
        if let otherPlayerTeamEntity = otherPlayerTeamEntity, let otherTeam = otherTeam, otherTeam == .none {
            otherPlayerTeamEntity.assignPlayerTeam(status: &gameTeamStatus, team: playerTeam.opponent)
        }
    }

}
