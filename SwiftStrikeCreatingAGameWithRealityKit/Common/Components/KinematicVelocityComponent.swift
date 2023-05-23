/*
See LICENSE folder for this sample’s licensing information.

Abstract:
KinematicVelocityComponent
*/

import Foundation
import os.log
import RealityKit

extension GameLog {
    static let kinematic = OSLog(subsystem: subsystem, category: "kinematic")
}

/// Stores the last known position and computes velocity from position changes.
struct KinematicVelocityComponent: Component {
    private var previousPosition: SIMD3<Float>?
    fileprivate var calculatedVelocity = SIMD3<Float>.zero

    init(_ ownerEntity: Entity) {
        KinematicVelocityManager.register(ownerEntity)
    }

    mutating func reset() {
        previousPosition = nil  // no previous position
        calculatedVelocity = .zero
    }
}

extension KinematicVelocityComponent {
    mutating func update(position: SIMD3<Float>, timeDelta: TimeInterval) {
        if let prev = previousPosition, timeDelta != 0 {
            calculatedVelocity = (position - prev) / Float(timeDelta)
        }
        previousPosition = position
    }
}

extension KinematicVelocityComponent: Codable {}

protocol HasKinematicVelocity where Self: Entity {}

extension HasKinematicVelocity {

    var kinematicVelocityComponent: KinematicVelocityComponent {
        get { return components[KinematicVelocityComponent.self] ?? KinematicVelocityComponent(self) }
        set { components[KinematicVelocityComponent.self] = newValue }
    }

    var kinematicVelocity: SIMD3<Float> {
        return kinematicVelocityComponent.calculatedVelocity
    }

    func kinematicVelocityReset() {
        return kinematicVelocityComponent.reset()
    }

    func tick(timeDelta: TimeInterval) {
        kinematicVelocityComponent.update(position: position(relativeTo: GamePlayManager.physicsOrigin), timeDelta: timeDelta)
    }
}

// global interface for managing entities created
// with KinematicVelocityComponent
enum KinematicVelocityManager {

    private static var entities = [WeakReference<Entity>]()

    static func reset() {
        entities = [WeakReference<Entity>]()
    }

    static func register(_ entity: Entity) {
        let alreadyRegistered = entities.contains {
            $0.value == entity
        }
        guard !alreadyRegistered else {
            os_log(.default, log: GameLog.kinematic, "entity %s already registered with KinematicVelocityManager", "\(entity.name)")
            return
        }
        entities.append(WeakReference(entity))
    }

    private static func compactList() {
        let oldCount = entities.count
        entities = entities.compactMap { weakReference in
            return weakReference.value != nil ? weakReference : nil
        }
        if entities.count != oldCount {
            os_log(.default, log: GameLog.kinematic, "KinematicVelocityManager - Compacted")
        }
    }

    static func update(timeDelta: TimeInterval) {
        compactList()
        entities.forEach { weakReference in
            guard let kinematic = weakReference.value as? HasKinematicVelocity else {
                return
            }
            kinematic.tick(timeDelta: timeDelta)
        }
    }

}
