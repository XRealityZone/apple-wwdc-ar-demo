/*
See LICENSE folder for this sample’s licensing information.

Abstract:
RealityKit+Pipeline
*/

import os.log
import RealityKit

extension Entity {

    // this is used for pins models only for SwiftStrike
    // Pins were created in meters per unit scale along
    // with collision meshes in Maya, so we check if
    // the usdz metersPerUnit was set to 0.01 by accident
    // and correct that here.
    func removeUSDZScaling() -> Bool {
        var modifiedFlag = false
        if scale == [0.01, 0.01, 0.01] {
            os_log(.default, log: GameLog.preloading, "USDZ cm scaling removed for '%s'", "\(name)")
            scale = [1, 1, 1]
            modifiedFlag = true
        }
        return modifiedFlag
    }

}

extension Entity {

    var rootEntity: Entity? {
        var current: Entity? = parent
        while current != nil {
            if current?.parent == nil {
                return current
            }
            current = current?.parent
        }
        return nil
    }

}

extension HasModel {

    func dumpModelEntityMaterials() {
        if let modelComponent = model {
            os_log(.default, log: GameLog.general, "    %s materials:", "\(name)")
            for material in modelComponent.materials {
                os_log(.default, log: GameLog.general, "        %s", "\(material)")
                if let unlit = material as? UnlitMaterial {
                    os_log(.default, log: GameLog.general, "        unlit: %s", "\(unlit)")
                } else if let simple = material as? SimpleMaterial {
                    os_log(.default, log: GameLog.general, "        simple: %s", "\(simple)")
                } else if let occlusion = material as? OcclusionMaterial {
                    os_log(.default, log: GameLog.general, "        occlusion: %s", "\(occlusion)")
                } else {
                    os_log(.default, log: GameLog.general, "        <unknown> parameters:")
                    for param in material.__parameterBlock.parameters {
                        os_log(.default, log: GameLog.general, "            Parm: %s", "\(param)")
                    }
                }
            }
        }
    }

}

extension HasModel {

    func dumpMaterials() {
        os_log(.default, log: GameLog.general, "%s materials:", "\(name)")
        forEachInHierarchy { (entity, _) in
            if let modelEntity = entity as? ModelEntity {
                modelEntity.dumpModelEntityMaterials()
            }
        }
    }

}

extension HasModel {

    func replaceMaterial(with newMaterial: Material?) {
        guard let modelComponent = components[ModelComponent.self] as? ModelComponent else {
            return
        }
        var newComponent = modelComponent
        if let newMaterial = newMaterial {
            newComponent.materials = [newMaterial]
        } else {
            newComponent.materials = []
        }
        components[ModelComponent.self] = newComponent
    }

}

