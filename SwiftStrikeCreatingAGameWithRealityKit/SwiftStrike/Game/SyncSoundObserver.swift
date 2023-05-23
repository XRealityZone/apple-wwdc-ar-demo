/*
See LICENSE folder for this sample’s licensing information.

Abstract:
MatchObserver
*/

import Combine
import Foundation
import os.log
import RealityKit

/// The SyncSoundObserver class watches the SyncSoundComponent on the "Field" entity
/// and executes those play commands on the corresponding entities on the local device
class SyncSoundObserver {
    private let scene: Scene
    private let entityCache: EntityCache
    private let sfxCoordinator: SFXCoordinator
    private var fieldEntity: Entity?

    var lastUpdate: Date = Date.distantPast
    var cancellables = [AnyCancellable]()

    init(scene: Scene, entityCache: EntityCache, sfxCoordinator: SFXCoordinator) {
        self.scene = scene
        self.entityCache = entityCache
        self.sfxCoordinator = sfxCoordinator

        scene.publisher(for: SceneEvents.Update.self)
            .sink { [weak self] _ in
                self?.processUpdate()
            }
            .store(in: &cancellables)
    }

    func findFieldEntity() {
        guard fieldEntity == nil else {
            return
        }

        entityCache.forEachEntity { (entity) in
            if entity.name == "Field" {
                self.fieldEntity = entity
            }
        }
    }

    func processUpdate() {
        findFieldEntity()

        guard let fieldEntity = fieldEntity,
            let syncSoundComponent = fieldEntity.components[SyncSoundComponent.self] as? SyncSoundComponent else {
            return
        }

        let newEvents = syncSoundComponent.events.filter { $0.date > lastUpdate }
        if let latestUpdate = newEvents.last?.date {
            lastUpdate = latestUpdate
        }
        for event in newEvents {
            os_log(.default, log: GameLog.audio, "SyncSoundObserver: playSound name: %s on: (%llu)",
                   event.name, event.identifier)

            // play the sound

            // look up entity from the event for solo mode or by identifier
            var entity: Entity?
            if let eventEntity = event.entity {
                entity = eventEntity
            } else if let syncService = scene.synchronizationService {
                entity = syncService.entity(for: event.identifier)
            }

            if let entity = entity {
                let child = entity.localAudioChildEntity()
                if let player = SFXCoordinator.prepareSound(named: event.name, on: child) {
                    os_log(.default, log: GameLog.audio, "SyncSoundObserver: playSound name: %s on: %s (%llu)",
                           event.name, entity.name, event.identifier)
                    player.play()
                } else {
                    os_log(.error, log: GameLog.audio, "SyncSoundObserver: failed to look up sound by name: %s.", event.name)
                }
            } else {
                os_log(.error, log: GameLog.audio, "SyncSoundObserver: failed to look up entity by id %llu.", event.identifier)
            }
        }
    }
}
