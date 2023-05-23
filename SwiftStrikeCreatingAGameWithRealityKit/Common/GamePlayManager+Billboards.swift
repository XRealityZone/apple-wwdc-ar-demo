/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Enable billboards to always look at the camera
*/

import RealityKit

extension GamePlayManager {
    func processBillboardEntities() {
        entityCache.forEachEntity { entity in
            guard let billboard = entity as? HasYAxisBillboard else {
                return
            }
            billboard.rotate(lookAt: cameraTransform)
        }

        entityCache.forEachEntity { entity in
            guard let billboard = entity as? HasFloorBillboard else {
                return
            }
            billboard.rotate(lookAt: cameraTransform)
        }

        entityCache.forEachEntity { entity in
            guard let billboard = entity as? HasCameraBillboard else {
                return
            }
            billboard.rotate(lookAt: cameraTransform)
        }
    }
}
