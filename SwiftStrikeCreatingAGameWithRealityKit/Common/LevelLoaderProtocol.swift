/*
See LICENSE folder for this sample’s licensing information.

Abstract:
LevelLoader
*/

import ARKit
import Combine
import RealityKit

protocol LevelLoaderProtocol {

    var placementUILoader: AnyPublisher<Entity, Error> { get }
    var activeLevel: ActiveLevel? { get }

    ///
    /// addDevicePlayerRepresentation()
    /// called for each device, client or host, that joins the game,
    /// to add any required device owned entities for the player,
    /// such as the PlayerLocationEntity, RemoteEntity (TableTop only), TargetEntity (TableTop only), etc.
    func addDevicePlayerRepresentation(scene: Scene, camera: ARCamera, named name: String, cameraTeam: Team)
        -> (AnchorEntity?, PlayerLocationEntity?, RemoteEntity?, TargetEntity?)

    ///
    /// addHostPlayerRepresentation()
    /// host only call to add several entities required to play the game such as
    /// the PaddleEntity, ForceFieldEntity, PlayerEntity,  TeameEntity, etc.
    func addHostPlayerRepresentation(playerLocationEntity: PlayerLocationEntity, remoteEntity: RemoteEntity?)

    func load(_ level: GameLevel, completion: @escaping (Result<ActiveLevel, Error>) -> Void) -> AnyCancellable?
    func level(for key: String) -> GameLevel?
    func preLoad(_ level: GameLevel)
    func reset()

}

