/*
See LICENSE folder for this sample’s licensing information.

Abstract:
SyncSoundPublisher
*/

import Combine
import Foundation
import os.log
import RealityKit

/// The SyncSoundPublisher class listens for notifications from NotificationCenter to play a sync sound
/// and records the even in the Field entity's SyncSoundComponent
class SyncSoundPublisher {
    private static let playSoundEvent = Notification.Name("SyncSoundPublisher.PlaySoundEvent")

    private let scene: Scene
    private let entityCache: EntityCache
    private var fieldEntity: Entity?

    var token: NSObjectProtocol?
    var lastUpdate: Date = Date.distantPast
    var cancellables = [AnyCancellable]()
    
    init(scene: Scene, entityCache: EntityCache) {
        self.scene = scene
        self.entityCache = entityCache

        findFieldEntity()

        token = NotificationCenter.default.addObserver(
            forName: SyncSoundPublisher.playSoundEvent,
            object: nil,
            queue: .main) { [weak self](notification) in
                if let name = notification.userInfo?["name"] as? String,
                    let identifier = notification.userInfo?["identifier"] as? SynchronizationService.Identifier,
                    let entity = notification.userInfo?["entity"] as? Entity {
                    self?.recordPlayForSound(named: name,
                                             identifier: identifier,
                                             entity: entity)
                }
        }

        scene.publisher(for: SceneEvents.Update.self)
            .sink { [weak self] (_) in
                self?.findFieldEntity()
            }
            .store(in: &cancellables)
    }

    deinit {
        if let token = token {
            NotificationCenter.default.removeObserver(token)
        }
    }

    func findFieldEntity() {
        guard fieldEntity == nil else {
            return
        }

        entityCache.forEachEntity { (entity) in
            if entity.name == "Field" {
                entity.components[SyncSoundComponent.self] = SyncSoundComponent()
                self.fieldEntity = entity
            }
        }
    }

    func recordPlayForSound(named name: String, identifier: SynchronizationService.Identifier, entity: Entity) {
        guard let fieldEntity = fieldEntity else {
            os_log(.default, log: GameLog.audio, "Cannot record play event named '%s' on '%s' because we have not yet discovered the field entity.",
                   name, entity.name)
            return
        }

        var component: SyncSoundComponent =
            fieldEntity.components[SyncSoundComponent.self] ?? SyncSoundComponent()
        component.appendSound(name: name, identifier: identifier, entity: entity)
        fieldEntity.components[SyncSoundComponent.self] = component
    }
}

extension SyncSoundPublisher {
    static func playSound(named name: String, on entity: Entity) {
        os_log(.default, log: GameLog.audio, "SyncSoundPublisher: playSound name: %s on: %s (%llu)",
               name, entity.name, entity.synchronization?.identifier ?? 0)
        if let syncComponent = entity.synchronization {
            NotificationCenter.default.post(name: SyncSoundPublisher.playSoundEvent,
                                            object: nil,
                                            userInfo: [
                                                "name": name,
                                                "identifier": syncComponent.identifier,
                                                "entity": entity
                ])
        }
    }
}
