/*
See LICENSE folder for this sample’s licensing information.

Abstract:
An entity used to highlight the selected chess piece.
*/

import RealityKit

private let player1SurfaceShader = CustomMaterial.SurfaceShader(named: "selectionSurfaceYellow", in: MetalLibLoader.library)
private let player2SurfaceShader = CustomMaterial.SurfaceShader(named: "selectionSurfaceBlue", in: MetalLibLoader.library)
private var player1CustomMaterial = try! CustomMaterial(surfaceShader: player1SurfaceShader, lightingModel: .unlit)
private var player2CustomMaterial = try! CustomMaterial(surfaceShader: player2SurfaceShader, lightingModel: .unlit)

// MARK: - SelectionCube
class SelectionCube: Entity {
    
    private var player: ChessGame.Player?
    private var type: ChessGame.Piece.PieceType?
    
    private var selectionEntity: Entity?
    
    convenience init(player: ChessGame.Player, type: ChessGame.Piece.PieceType) {
        self.init()
        
        self.player = player
        self.type = type
        self.isEnabled = false
        
        if let selection = try? Entity.load(named: "SelectionCenter") {
            addChild(selection)
            let yScale: Float = type.isTall ? 1.2 : 1
            selection.setScale(SIMD3<Float>(x: 1, y: yScale, z: 1), relativeTo: selection)
            selectionEntity = selection
            
            selection.modifyMaterials { _ in
                var material = player == .player1 ? player1CustomMaterial : player2CustomMaterial
                material.faceCulling = .none
                material.blending = .transparent(opacity: 1.0)
                
                if let resource = try? TextureResource.load(named: "noise.png") {
                    let texture = CustomMaterial.Texture(resource)
                    material.baseColor.texture = .init(texture)
                }
                
                return material
            }
        }
    }
    
    required init() {
        super.init()
    }
    
    func playAnimation(reversed: Bool = false) {
        if let selectionEntity = selectionEntity {
            ([selectionEntity] + selectionEntity.descendants)
                .forEach { entity in
                    entity.availableAnimations.forEach {
                        entity.playAnimation($0)
                    }
                }
        }
    }
}
