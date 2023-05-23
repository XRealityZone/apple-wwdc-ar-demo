/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Pipeline
*/

import os.log
import RealityKit
import UIKit

extension Entity {
    var isRedundant: Bool {
        return children.isEmpty
            && components[PhysicsBodyComponent.self] == nil
            && components[ModelComponent.self] == nil
    }
}

struct Pipeline {

    private static let missingTextureName = "missing_texture.png"
    private static var missingTexture: TextureResource!

    enum Error: Swift.Error {
        case incorrectEntityType
    }

    init() {
        // lazy static init...
        if Pipeline.missingTexture == nil {
            let texture = try? TextureResource.load(named: Pipeline.missingTextureName)
            guard texture != nil else {
                os_log(.error, log: GameLog.general,
                       "Fatal: Failed loading missing texture '%s'",
                       "\(Pipeline.missingTextureName)")
                fatalError()
            }
            Pipeline.missingTexture = texture
        }
    }

    var log: ((String) -> Void) = {
        print($0)
    }

    func process(root: Entity) throws {
        try process(root: root) { (entity, shapes) in
            guard let entity = entity as? HasPhysicsBody else { return }
            entity.physicsBody = PhysicsBodyComponent(shapes: shapes, mass: 1, mode: .static)
            entity.collision = CollisionComponent(shapes: shapes)
        }
    }

    func process(root: Entity, callback: (Entity, [ShapeResource]) -> Void) throws {
        var shapes: [Entity: [ShapeResource]] = [:]
        var entitiesToRemove: [Entity] = []

        func processShape(shape: ShapeResource, for entity: Entity) {
            guard let parent = entity.parent else {
                fatalError()
            }
            shapes[parent] = (shapes[parent] ?? []) + [shape]
            entitiesToRemove.append(entity)
        }

        try root.forEachInHierarchy { (entity, depth) in
            guard let kind = entity.kind else {
                return
            }
            let tabs = String(repeating: "\t", count: depth)
            log("\(tabs) \(entity.name)")
            switch kind {
            case .physicsGroup:
                // Nothing to do here
                break
            case .physicsSphere:
                let bounds = entity.visualBounds(relativeTo: root)
                let radius = ((bounds.max - bounds.min).x / 2)
                let offset = bounds.center
                let shape = ShapeResource.generateSphere(radius: radius).offsetBy(translation: offset)
                log("# Creating sphere of radius \(radius) at offset \(offset)")
                processShape(shape: shape, for: entity)
            case .physicsBox:
                let localBounds = entity.visualBounds(relativeTo: entity)
                let globalBounds = entity.visualBounds(relativeTo: root)
                let size = localBounds.max - localBounds.min
                let rotation = entity.transform.rotation
                let offset = globalBounds.center
                log("# Creating box of size \(size), rotation \(rotation) at offset \(offset)")
                let shape = ShapeResource.generateBox(size: size).offsetBy(rotation: rotation, translation: offset)
                processShape(shape: shape, for: entity)
            case .physicsHull:
                guard let model = (entity as? (Entity & HasModel))?.model else {
                    fatalError("Entity \(entity) has no model")
                }
                let mesh = model.mesh
                let shape = ShapeResource.generateConvex(from: mesh)
                log("# Creating convex hull")
                processShape(shape: shape, for: entity)
            case .occlusion, .shadow:
                guard let model = entity as? ModelEntity else {
                    throw Error.incorrectEntityType
                }
                log("# Adding occlusion/shadow material to: \(entity.path)")
                let material: OcclusionMaterial
                if kind == .shadow {
                    material = OcclusionMaterial(receivesDynamicLighting: true)
                } else {
                    material = OcclusionMaterial()
                }
                model.replaceMaterial(with: material)
            case .glow: break
                // do nothing for glow - these may be translated to
                // .billboard
            case .billboard:
                try processBillboardEntity(entity, root: root)
            }
        }

        for entity in entitiesToRemove {
            entity.removeFromParent()
        }

        for (entity, shapes) in shapes {
            callback(entity, shapes)
        }
    }

    private func processBillboardEntity(_ entity: Entity, root: Entity) throws {
        guard UserSettings.debugBillboards,
        let model = entity as? ModelEntity else {
            return
        }

        let textureName = Pipeline.missingTextureName
        let texture = Pipeline.missingTexture
        os_log(.default, log: GameLog.general,
               "%s:%s: Billboard loaded texture '%s'",
               "\(root.children.first!.name)",
               "\(entity.name)",
               "\(textureName)")

        var unlitMaterial = UnlitMaterial()
        let color = MaterialParameters.Texture(texture!)
        unlitMaterial.color = .init(tint: UIColor(displayP3Red: 1, green: 1, blue: 1, alpha: 0.5),
                                    texture: color)
        model.replaceMaterial(with: unlitMaterial)
    }

    func removeUSDZScaling(root: Entity) {
        _ = root.removeUSDZScaling()
    }

    func removeRedundantEntities(root: Entity) {
        var redundantEntities: [Entity] = []
        root.forEachInHierarchy { (entity, _) in
            if entity.isRedundant {
                redundantEntities.append(entity)
            }
        }
        for entity in redundantEntities {
            entity.removeFromParent()
        }
    }
}
