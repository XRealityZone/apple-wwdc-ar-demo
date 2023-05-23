/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Swift extension on Entity.
*/

import Foundation
import RealityKit

extension Entity {
    
    @available(iOS 15.0, *)
    func setCustomScalar(value: Float, index: Int) {
        let vectorRange = 0...3
        if !vectorRange.contains(index) {
            print("Attempting to set out of range uniform scalar: \(index)")
        }
    }
    
    /// This method sets the custom vector on an entity's material and its children's materials. This updates
    /// all level of detail (LOD) models with the value, so the shader functions work correctly regardless of the entity's
    /// distance from the camera.
    @available(iOS 15.0, *)
    func setCustomVector(vector: SIMD4<Float>) {
        children.forEach { $0.setCustomVector(vector: vector) }
        
        guard var comp = components[ModelComponent.self] as? ModelComponent else { return }
        comp.materials = comp.materials.map { (material) -> Material in
            if var customMaterial = material as? CustomMaterial {
                customMaterial.custom.value = vector
                return customMaterial
            }
            return material
        }
        components[ModelComponent.self] = comp
    }
    
    /// Used to modify a material for an entity. It walks the `children` tree looking for model components
    /// and applies the closure to all of the model entities from this entity down.
    func modifyMaterials(_ closure: (Material) throws -> Material) rethrows {
        try children.forEach { try $0.modifyMaterials(closure) }
        
        guard var comp = components[ModelComponent.self] as? ModelComponent else { return }
        comp.materials = try comp.materials.map { try closure($0) }
        components[ModelComponent.self] = comp
    }
    
    /// Sets the geometry modifier for this entity and any child entities that have custom materials.
    @available(iOS 15.0, *)
    func set(_ modifier: CustomMaterial.GeometryModifier) throws {
        try modifyMaterials { try CustomMaterial(from: $0, geometryModifier: modifier) }
    }
    
    /// Sets the surface shader for this entity and any child entities that have custom materials.
    @available(iOS 15.0, *)
    func set(_ shader: CustomMaterial.SurfaceShader) throws {
        try modifyMaterials { try CustomMaterial(from: $0, surfaceShader: shader) }
    }
    
    /// In scenes loaded from RealityComposer, the actual ModelEntity is a descendent of the named
    /// entity. This method returns the actual model entity if it exists.
    func getActualModelEntity() -> ModelEntity? {
        
        // If self is a model entity, return self.
        if let modelEntity = self as? ModelEntity {
            return modelEntity
        }
        
        for child in children {
            if let modelEntity = child.getActualModelEntity() {
                return modelEntity
            }
        }
        
        return nil
    }
    
    /// Traverses the entity's ancestors, looking for an entity with a specific name. When looking
    /// for an entity by name, an entity may be a part of another entity. This method lets calling
    /// code check for a specific name among the entity's ancestors, in addition to its own name.
    func ancestorWithName(name: String) -> Entity? {
        if self.name == name {
            return self
        }
        
        var entity = parent
        while true {
            guard let parent = entity else {
                break
            }
            if parent.name.contains("Robot") {
                return entity
            }
            entity = parent.parent
        }
        return nil
    }
    
}
