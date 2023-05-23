/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Convenience extensions for RealityKit Entities
*/

import Combine
import Foundation
import os.log
import RealityKit

// MARK: - Scene Helpers

extension Scene {

    func playerLocationEntities() -> [PlayerLocationEntity] {
        // PlayerLocationEntities are always the only child
        // of an anchor
        return anchors
            .compactMap { anchor in
                anchor.children.first as? PlayerLocationEntity
            }
    }

    func remoteEntities() -> [RemoteEntity] {
        // RemoteEntities are always a child
        // of the physics origin
        return GamePlayManager.physicsOrigin?.children
            .compactMap { entity in
                entity as? RemoteEntity
            } ?? []
    }

    func playerTeamEntities() -> [PlayerTeamEntity] {
        // PlayerTeamEntities are always a child
        // of a PlayerLocationEntity or a RemoteEntity
        return (playerLocationEntities() + remoteEntities())
            .flatMap {
                $0.children.compactMap {
                    $0 as? PlayerTeamEntity
                }
            }
  }

    func playerTeamEntity(for id: UUID) -> PlayerTeamEntity? {
        return playerTeamEntities().first { entity in
            return entity.deviceUUID == id
        }
    }

    func playerLocationEntity(for id: UUID) -> PlayerLocationEntity? {
        return playerLocationEntities().first { entity in
            return entity.deviceUUID == id
        }
    }

}

// MARK: - Entity.ChildCollection Helpers

extension Entity.ChildCollection {

    func entities(with component: Component.Type) -> [Entity] {
        return filter { $0.components.has(component) } +
            flatMap { return $0.children.entities(with: component) }
    }

}

// MARK: - Entity debug path helpers

extension Entity {

    var path: String {
        return ancestors
            .map { $0.name }
            .joined(separator: "/")
            + "/" + name
    }

    var ancestors: [Entity] {
        var ancestors: [Entity] = []
        var parent = self.parent
        while let newParent = parent {
            ancestors.insert(newParent, at: 0)
            parent = newParent.parent
        }
        return ancestors
    }
}

// MARK: - Entity children processing helpers

extension Entity {

    // forEachInHierarchy()
    // This method iterates through the root entity and all of its children,
    // calling the closure with each Entity and its depth in the tree.  By
    // default, the root is depth 0.
    func forEachInHierarchy(depth: Int = 0, closure: (Entity, Int) throws -> Void) rethrows {
        try closure(self, depth)
        for child in children {
            try child.forEachInHierarchy(depth: depth + 1, closure: closure)
        }
    }

    func findFirstChild<EntityType>(ofType: EntityType.Type, _ test: ((EntityType) -> Bool)? = nil) -> EntityType? {
        let child = children.first { entity in
            guard let child = entity as? EntityType else { return false }
            return test?(child) ?? true
        } as? EntityType

        return child
    }

    func findFirstSibling<EntityType>(ofType: EntityType.Type, _ test: ((EntityType) -> Bool)? = nil) -> EntityType? {
        if let sibling = self as? EntityType {
            return sibling
        }
        guard let parent = parent else { return nil }
        return parent.findFirstChild(ofType: ofType, test)
    }

    func findEntities<T>(ofType: T.Type) -> [T] where T: Entity {
        var entities: [T] = []
        forEachInHierarchy { (entity, _) in
            guard let entity = entity as? T else {
                return
            }
            entities.append(entity)
        }
        return entities
    }

}

// MARK: - Entity creation helpers

extension Entity {

    convenience init(named name: String, children: [Entity] = []) {
        self.init()
        self.name = name
        self.children.append(contentsOf: children)
    }

}

// MARK: - Entity insertion helpers

extension Entity {

    struct NameToEntityEntry {
        init(name: String, createEntity: @escaping () -> Entity) {
            self.name = name
            self.createEntity = createEntity
        }
        let name: String
        let createEntity: () -> Entity
    }

    // mapInNewParentEntities()
    // this method will search this Entity and its children for any Entity
    // with a name from the array of NameToEntityEntry, creating a new array
    // of Entity, NameToEntityEntry.  Then it will loop through the new array
    // inserting a new parent Entity for the named Entity of the type found
    // in NameToEntityEntry.
    // In SwiftStrike, this is used to insert Billboard Entities for the Pins,
    // and Ball in cosmic mode.
   func mapInNewParentEntities(map: [NameToEntityEntry], name: String? = nil) {
        var list: [(Entity, NameToEntityEntry)] = []
        forEachInHierarchy { (walker, _) in
            for mapper in map {
                if walker.name.localizedCaseInsensitiveContains(mapper.name) {
                    list.append((walker, mapper))
                }
            }
        }

        list.forEach { (oldEntity, mapper) in
            let newParent = mapper.createEntity()
            let oldParent = oldEntity.parent
            oldEntity.removeFromParent()
            oldParent?.addChild(newParent)
            newParent.addChild(oldEntity)
            if let name = name {
                newParent.name = name
            }
        }
    }

    func insertBillboardsIfNeeded(nameToEntityMap: [NameToEntityEntry], _ entitySwitchName: String) {
        // ORDER IS IMPORTANT
        // new clone must have a parent so that we can insert a new Entity
        // between clone and parent.  If this entity is a billboard of some
        // kind we insert a new parent between old parent and self. The
        // name will only be changed if no billboard parent was inserted
        // in above me
        guard let oldParent = parent else {
            assertionFailure("PinEntity:instertBillboardsIfNeeded() failed because child has no parent")
            return
        }
        mapInNewParentEntities(map: nameToEntityMap, name: entitySwitchName)
        // if my parent is the same, then update my name since I will
        // be used as the entity to be enabled/disabled by name
        if parent == oldParent {
            name = entitySwitchName
        }
    }

}

// MARK: - Entity orientation helpers

extension Entity {

    func forward(relativeTo: Entity?) -> SIMD3<Float> {
        let rotation = orientation(relativeTo: relativeTo)
        return rotation.act([0, 0, -1])
    }

}

//
// Asynchronous Entity load support
//
protocol EntityToLoad {
    associatedtype Key: OptionSet
    var key: Key { get set }
    var filename: String { get }
}

extension Entity {

    // loadEntitiesAsync()
    // This method is used to load any number of Entity models from usdz files asychronously.
    // The design is intended to support out of order loading by providing the results in
    // a dictionary where the input key paired with a filename is used to as the key to
    // the dictionary to return the loaded Entity.  Errors on load are purposefully fatal
    // errors in order to properly identify to the developer missing assets.
    static func loadEntitiesAsync<EntityToLoadType>(_ entitiesToLoad: [EntityToLoadType]
    ) -> AnyPublisher<[EntityToLoadType.Key: Entity], Never> where EntityToLoadType: EntityToLoad {
        let loadRequests = entitiesToLoad.map { entityToLoad in
            Entity.loadAsync(named: entityToLoad.filename)
            .assertNoFailure()
            .map { (entityToLoad, $0) }
        }

        let publisher = Publishers.Sequence(sequence: loadRequests)
        // Flatten the array of arrays
        .flatMap { $0 }
        // Wait for everything to finish
        .collect()
        // Convert array of (EntityToLoad, Entity) into a dictionary
        .map { publisherOfEntitiesToLoad -> [EntityToLoadType.Key: Entity] in
            var dictionary = [EntityToLoadType.Key: Entity]()
            publisherOfEntitiesToLoad.forEach {
                #if DEBUG
                var keyString = "\($0.0.key.rawValue)"
                if let keyInt = Int(keyString) {
                    keyString = String(format: "0x%08x", keyInt)
                }
                os_log(.default, log: GameLog.preloadAssets, "%@-%@", keyString, "\($0.0.filename)")
                #endif
                dictionary[$0.0.key] = $0.1
            }
            return dictionary
        }
        .eraseToAnyPublisher()

        return publisher
    }

}

extension HasPhysics {
    func physicsReset(_ position: SIMD3<Float>? = nil, _ orientation: simd_quatf? = nil) {
        physicsMotion?.angularVelocity = .zero
        physicsMotion?.linearVelocity = .zero
        if let pos = position {
            setPosition(pos, relativeTo: GamePlayManager.physicsOrigin)
        }
        if let ori = orientation {
            setOrientation(ori, relativeTo: GamePlayManager.physicsOrigin)
        }
        os_log(.default, log: GameLog.gameboard, "BallEntity.physicsReset(): restored %s p=%s, r=%s,%s",
               "\(name)",
               "\(self.position(relativeTo: GamePlayManager.physicsOrigin).terseDescription)",
               "\(transform.rotation.real)",
               "\(transform.rotation.imag.terseDescription)")
        resetPhysicsTransform(recursive: true)
        if let entity = self as? HasKinematicVelocity {
            entity.kinematicVelocityReset()
        }
        if let entity = self as? HasRemoteVelocity {
            entity.velocityReset()
        }
    }
}

extension Scene {
    func dump() {
        os_log(.default, log: GameLog.general, "Scene Anchors - %d", anchors.count)
        anchors.forEach { $0.dump(log: GameLog.general, short: true) }
    }
}

extension ShapeResource {
    static func createCapsule(totalHeight: Float, radius: Float) -> ShapeResource {
        guard totalHeight > (2.0 * radius) else {
            fatalError(String(format: "ShapeResource.createCapsule():  totalHeight (%0.4f) must be >= (2 * radius) (%0.4f)",
                              totalHeight, 2.0 * radius))
        }
        return ShapeResource.generateCapsule(height: totalHeight, radius: radius)
    }
}
