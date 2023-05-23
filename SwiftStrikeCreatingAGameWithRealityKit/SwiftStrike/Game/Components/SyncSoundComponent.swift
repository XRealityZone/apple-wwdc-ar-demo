/*
See LICENSE folder for this sample’s licensing information.

Abstract:
SyncSoundComponent
*/

import Foundation
import RealityKit

struct SyncSoundComponent: Component, Codable {
    struct Event: Codable {
        let date: Date
        // identifier is set from the SynchronizationComponent identifier that
        // creates this event
        let identifier: SynchronizationService.Identifier
        let name: String
        let entity: Entity? // for local mode where we do not have a synchronization service

        enum CodingKeys: CodingKey {
            case date
            case identifier
            case name
        }

        init(date: Date,
             identifier: SynchronizationService.Identifier,
             name: String,
             entity: Entity) {
            self.date = date
            self.identifier = identifier
            self.name = name
            self.entity = entity
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            date = try container.decode(Date.self, forKey: CodingKeys.date)
            identifier = try container.decode(UInt64.self, forKey: CodingKeys.identifier)
            name = try container.decode(String.self, forKey: CodingKeys.name)
            entity = nil
            // we do not encode the entity, because it is for local use only.
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(date, forKey: CodingKeys.date)
            try container.encode(identifier, forKey: CodingKeys.identifier)
            try container.encode(name, forKey: CodingKeys.name)
            // we do not encode the entity, because it is for local use only.
        }
    }

    var events = [Event]()

    mutating func appendSound(name: String, identifier: SynchronizationService.Identifier, entity: Entity) {
        events.append(Event(date: Date(),
                            identifier: identifier,
                            name: name,
                            entity: entity))
    }

    mutating func reset() {
        events.removeAll()
    }
}
