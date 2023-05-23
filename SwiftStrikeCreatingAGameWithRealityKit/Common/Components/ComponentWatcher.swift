/*
See LICENSE folder for this sample’s licensing information.

Abstract:
ComponentWatcher
*/

import Foundation
import os.log
import RealityKit

extension GameLog {
    static let componentWatcher = OSLog(subsystem: subsystem, category: "componentwatcher")
}

typealias DidChangeClosure = (Entity) -> Void

///
/// WatchedEntity
/// useful wrapper for Entity
/// to be stored as a weak reference
/// with its component type, and
/// closure to be called when timestamp
/// is updated in component
private class WatchedEntity {
    private(set) weak var entity: Entity?
    let componentType: Component.Type
    let didChange: DidChangeClosure
    init(entity: Entity?, componentType: Component.Type, _ dataChanged: @escaping DidChangeClosure) {
        self.entity = entity
        self.componentType = componentType
        self.didChange = dataChanged
    }
}

protocol WatchedComponent where Self: Component {
    var timestamp: Date { get }
}

///
/// ComponentWatcher
/// This service allows client (or host)  to act on data changes received from network transport. This is
/// particularly important for the SwiftStrike team selection process that is owned by the host and yet the
/// client owns the motion of the Entity that determines the team.  When the client gets a
/// `PlayerTeamComponent` data update it needs to update other systems like UI to know which team
/// the client is on.
///
class ComponentWatcher {

    private var lastTimestamp: Date = Date.distantPast
    private var list = [WatchedEntity]()

    init() {}

    func watch(entity: Entity, with componentType: Component.Type, _ dataChanged: @escaping DidChangeClosure) {
        guard entity.components[componentType] as? WatchedComponent != nil else {
            fatalError(String(format: "failed to add entity %s because it does not have component type %s with protocol WatchedComponent",
                                    "\(entity.name)", "\(componentType)"))
        }
        list.append(WatchedEntity(entity: entity, componentType: componentType, dataChanged))
    }

    func tick() {
        list.removeAll(where: { watchedEntity in
            guard let entity = watchedEntity.entity,
            entity.components[watchedEntity.componentType] as? WatchedComponent != nil else {
                return true
            }
            return false
        })

        var newLast = Date.distantPast
        var updated: Int = 0
        list.forEach { watchedEntity in
            guard let entity = watchedEntity.entity,
            let component = entity.components[watchedEntity.componentType] as? WatchedComponent else {
                fatalError("somehow the filtered list still has invalid entries")
            }
            if component.timestamp > lastTimestamp {
                updated += 1
                watchedEntity.didChange(entity)
                if component.timestamp > newLast {
                    newLast = component.timestamp
                }
            }
        }
        guard updated > 0 else { return }
        os_log(.default, log: GameLog.componentWatcher, "ComponentWatcher: %s updated since %s",
               "\(updated)", "\(lastTimestamp)")

        lastTimestamp = newLast
    }

}
