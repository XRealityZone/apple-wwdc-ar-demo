/*
See LICENSE folder for this sample’s licensing information.

Abstract:
PinTransparencyManager updates pins' transparency based on player proximity
*/

import Combine
import RealityKit

enum PinTransparencyTunables {
    static var pinFadeDist = TunableScalar<Float>("Pin Fade Distance", min: 0.05, max: 4.0, def: 2.0)
}

class PinTransparencyManager {
    private let entityCache: EntityCache

    init(entityCache: EntityCache) {
        self.entityCache = entityCache
    }

    func updatePinTransparency() {
        let pinEntities = entityCache.entityList(entityType: PinEntity.self)
        let paddleEntities = entityCache.entityList(entityType: PaddleEntity.self)
        let remoteEntities = entityCache.entityList(entityType: RemoteEntity.self)

        for pinEntity in pinEntities {
            guard pinEntity.isEnabled else { continue }
            
            // Calculate this pin's distance from each paddle
            var teamDistancesSquared: [Float] = []
            for paddleEntity in paddleEntities {
                let distVec = pinEntity.visualBounds(recursive: true, relativeTo: paddleEntity, excludeInactive: false).center * [1, 0, 1]
                teamDistancesSquared.append(length_squared(SIMD2<Float>(distVec.x, distVec.z)))
            }
            for remoteEntity in remoteEntities {
                let distVec = pinEntity.visualBounds(recursive: true, relativeTo: remoteEntity, excludeInactive: false).center * [1, 0, 1]
                teamDistancesSquared.append(length_squared(SIMD2<Float>(distVec.x, distVec.z)))
            }

            // If the closest team is under the threshold, fade the pin
            guard let minDistanceSquared = teamDistancesSquared.min() else { continue }
            let transparent = (minDistanceSquared < (PinTransparencyTunables.pinFadeDist.value * PinTransparencyTunables.pinFadeDist.value))
            pinEntity.setTransparent(transparent)
        }
    }
}
