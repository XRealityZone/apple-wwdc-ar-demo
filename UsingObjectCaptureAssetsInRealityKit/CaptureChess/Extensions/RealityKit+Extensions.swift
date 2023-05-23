/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Game-specific extensions on RealityKit classes.
*/

import RealityKit

extension CollisionGroup {
    static let board = CollisionGroup(rawValue: 1 << 1)
    static let piece = CollisionGroup(rawValue: 1 << 2)
}

extension EntityQuery {
    static let chessPieceQuery = EntityQuery(where: .has(ChessPieceComponent.self))
}

extension Entity {
    var descendants: [Entity] {
        children + children.flatMap { $0.descendants }
    }
}

extension Entity {
    var parentChessPiece: ChessPiece? {
        var parent: Entity? = self
        while parent != nil {
            if parent is ChessPiece {
                return parent as? ChessPiece
            }
            parent = parent?.parent
        }
        return nil
    }
}

extension Entity {
    func modifyMaterials(_ closure: (Material) throws -> Material) rethrows {
        try children.forEach { try $0.modifyMaterials(closure) }
        
        guard var comp = components[ModelComponent.self] as? ModelComponent else { return }
        comp.materials = try comp.materials.map { try closure($0) }
        components[ModelComponent.self] = comp
    }
}
