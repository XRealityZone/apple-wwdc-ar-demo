/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Responsible for tracking the state of the game: which objects are where, who's in the game, etc.
*/

import Foundation
import os.log
import RealityKit

struct UprightMask: Codable, Equatable {
    var rawValue: UInt32

    init() {
        rawValue = 0
    }

    init(_ value: UInt32) {
        rawValue = value
    }

    private func indexInRangeElseError(_ index: Int) -> Bool {
        guard index >= 0 && index < 32 else {
            let errorString = String(format: "UprightMask: bit index out of range, %s > 32", "\(index)")
            assertionFailure(errorString)
            return false
        }
        return true
    }

    var pinsDown: Int {
        return rawValue.nonzeroBitCount
    }

    // Returns true if the pin is DOWN
    subscript(_ index: Int) -> Bool {
        return (rawValue >> index) & 1 == 1
    }

    mutating func setBitBy(index: Int) {
        guard indexInRangeElseError(index) else { return }

        rawValue |= 1 << index
    }

    mutating func clearBitBy(index: Int) {
        guard indexInRangeElseError(index) else { return }

        rawValue &= ~(1 << index)
    }

    // Returns true if the first N pins are set, i.e., down.
    func firstNBitsSet(_ number: Int) -> Bool {
        let bits: UInt32 = (1 << number) - 1
        return (rawValue & bits) == bits
    }
}

extension UprightMask: CustomStringConvertible {
    var description: String {
        let rows = [(0...0),
                    (1...2),
                    (3...5),
                    (6...9)]

        let rowBits = rows.map { $0.map { self[$0] } }
        // . is down, ! is up
        let rowStrings = rowBits.map { $0.map { $0 ? "." : "!" }.joined() }
        let result = rowStrings.joined(separator: " ")
        return result
    }
}

protocol UprightCoordinatorUpdateDelegate: AnyObject {
    func tickUprightStatus() -> UprightStatusTickResult
}

extension Notification.Name {
    static let uprightStatus = Notification.Name("UprightStatus")
}

extension Notification {
    static let teamKey = "TeamIdentifierKey"
    static let uprightIdKey = "UprightIdKey"
    static let uprightStatusKey = "UprightStatusKey"

    static func uprightStatus(team: Team, mask: UprightMask) -> Notification {
        return Notification(name: .uprightStatus, object: nil, userInfo: [teamKey: team.rawValue, uprightStatusKey: mask.rawValue])
    }

    var team: Team {
        if let userInfo = userInfo,
            let teamId = userInfo[Notification.teamKey] as? String,
            let team = Team(rawValue: teamId) {
            return team
        }
        return .none
    }

    var uprightMask: UprightMask {
        if let userInfo = userInfo,
            let rawValue = userInfo[Notification.uprightStatusKey] as? UInt32 {
            return UprightMask(rawValue)
        }
        return UprightMask()
    }
}

class UprightCoordinator {
    var downState = [Team: UprightMask]()
    let uprightsPerTeam: Int

    init(uprightsPerTeam: Int) {
        self.uprightsPerTeam = uprightsPerTeam
    }
    
    func updateUprightEntities(entityCache: EntityCache) {
        entityCache.entityList(componentType: UprightStatusComponent.self).forEach { entity in
            if let uprightEntity = entity as? UprightCoordinatorUpdateDelegate {
                let result = uprightEntity.tickUprightStatus()
                if result == .updatedAndChanged {
                    uprightStateChanged(entity)
                }
            }
        }
    }

    private func uprightStateChanged(_ entity: Entity) {
        guard let uprightEntity = entity as? HasUprightStatus & HasPlacementIdentifier else { return }

        let team = uprightEntity.placementTeam
        let id = uprightEntity.placementID
        guard team != .none, id != 0 else { return }

        let newUpDownState = uprightEntity.upright
        // newUpDownState true means pin is up
        var newMask = downState[team] ?? UprightMask()

        let bitIndex = id - 1           // id cannot be 0
        if !newUpDownState {            // not UP, so down
            newMask.setBitBy(index: bitIndex)
        } else {
            newMask.clearBitBy(index: bitIndex)
        }
        downState[team] = newMask
        os_log(.default, log: GameLog.general, "Uprights change: %s - %s", "\(team)", "\(newMask)")
        NotificationCenter.default.post(.uprightStatus(team: team, mask: newMask))
    }

    func acquireUprightsStatus(entityCache: EntityCache) {
        // assume all uprights are up
        downState[.teamA] = UprightMask()
        downState[.teamB] = UprightMask()
        entityCache.entityList(componentType: UprightStatusComponent.self).forEach { entity in
            if let uprightEntity = entity as? HasUprightStatus & HasPlacementIdentifier {
                if !uprightEntity.upright {
                    let team = uprightEntity.placementTeam
                    let id = uprightEntity.placementID
                    guard team != .none, id != 0 else { return }

                    let bitIndex = id - 1           // id cannot be 0
                    downState[team]!.setBitBy(index: bitIndex)
                }
            }
        }
        os_log(.default, log: GameLog.general, "Uprights reset: teamA - %s", "\(downState[.teamA]!)")
        os_log(.default, log: GameLog.general, "Uprights reset: teamB - %s", "\(downState[.teamB]!)")
        NotificationCenter.default.post(.uprightStatus(team: .teamA, mask: downState[.teamA]!))
        NotificationCenter.default.post(.uprightStatus(team: .teamB, mask: downState[.teamB]!))
    }

    func reset() {
        for team in Team.allCases {
            downState[team] = UprightMask()
        }
    }

    func allDownFor(team: Team) -> Bool {
        if let teamBits = downState[team] {
            return teamBits.firstNBitsSet(uprightsPerTeam)
        } else {
            return false
        }
    }

}

