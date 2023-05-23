/*
See LICENSE folder for this sample’s licensing information.

Abstract:
ReckoningLevel
*/

import ARKit
import Combine
import os.log
import RealityKit

extension GameSessionManager {
    func dispatchToMain(_ input: MatchOutput) {
        os_log(.default, log: GameLog.gameState, "GameSessionManager receive: (%s)", String(describing: input))
        switch input {
        case .positioningStarted:
            updateAllPinsStatus()
            enableLightBeams()
            disableCollisionForForceFields()
        case .positioningFinished:
            disableLightBeams()
            enableCollisionForForceFields()
        case .showField:
            let note = Notification(name: FieldEntity.showFieldNotificationName)
            NotificationCenter.default.post(note)
        case .readyForBallDrop:
            let note = Notification(name: FieldEntity.startBallDropNotificationName)
            NotificationCenter.default.post(note)
        case .ballOutOfPlay:
            let note = Notification(name: FieldEntity.startPinResetNotificationName)
            NotificationCenter.default.post(note)
        case let .matchWonBy(team):
            // add a little delay to turn around
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                var note = Notification(name: FieldEntity.winnerNotificationName)
                note.object = team
                NotificationCenter.default.post(note)
            }
        default:
            break
        }
    }

    var realityView: GameView {
        return view as! GameView
    }

    func enableCollisionForForceFields() {
        os_log(.default, log: GameLog.collision, "Force Fields Enabled...")

        // enable Force Fields...
        entityCache.entityList(componentType: RadiatingForceFieldComponent.self, forceRefresh: true).forEach {
            #if DEBUG
            var id: UUID?
            if let parentEntity = $0.parent as? Entity & HasDeviceIdentifier {
                id = parentEntity.deviceUUID
            }
            os_log(.default, log: GameLog.collision, "Force Field UUID %s enabled...", "\(String(describing: id))")
            #endif
            $0.isEnabled = true
        }
    }

    func disableCollisionForForceFields() {
        os_log(.default, log: GameLog.collision, "Force Fields Disabled...")

        // disable Force Fields...
        entityCache.entityList(componentType: RadiatingForceFieldComponent.self, forceRefresh: true).forEach {
            #if DEBUG
            var id: UUID?
            if let parentEntity = $0.parent as? Entity & HasDeviceIdentifier {
                id = parentEntity.deviceUUID
            }
            os_log(.default, log: GameLog.collision, "Force Field UUID %s disabled...", "\(String(describing: id))")
            #endif
            $0.isEnabled = false
        }
    }

    func enableLightBeams() {
        os_log(.default, log: GameLog.collision, "Beams Enabled...")
        entityCache.entityList(componentType: TriggerComponent.self).forEach {
            guard let beam = $0 as? BeamOfLightEntity else { return }
            beam.isEnabled = true
            beam.triggered = false
            beam.state = .waiting
        }
    }

    func disableLightBeams() {
        os_log(.default, log: GameLog.collision, "Beams Disabled...")
        entityCache.entityList(componentType: TriggerComponent.self).forEach {
            guard let beam = $0 as? BeamOfLightEntity else { return }
            beam.isEnabled = false
            beam.triggered = false
        }
    }
}
