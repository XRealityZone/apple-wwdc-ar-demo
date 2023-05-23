/*
See LICENSE folder for this sample’s licensing information.

Abstract:
An entity that represents a single chess piece.
*/

import Combine
import RealityKit
import UIKit

// MARK: - Fileprivate constants
private let liftedY: Float = 0.3

private let fadeInAnimationDuration = 2.0
private let fadeOutAnimationDuration = BoardGame.liftDropAnimationDuration

private let shadowSurfaceShader = CustomMaterial.SurfaceShader(named: "shadowSurface", in: MetalLibLoader.library)
private var shadowCustomMaterial = try! CustomMaterial(surfaceShader: shadowSurfaceShader, lightingModel: .unlit)

// MARK: - ChessPiece
class ChessPiece: Entity, HasChessPiece {
    
    static let shadowOpacityName = "shadowOpacity"
    static let capturedProgressName = "capturedProgress"
    
    static let geometryModifier = CustomMaterial.GeometryModifier(named: "capturedGeometry", in: MetalLibLoader.library)
    
    var isBeingCaptured = false
    var isShadowAnimating = false
    
    var player: ChessGame.Player {
        chessPiece!.isPlayer1 ? .player1 : .player2
    }
    
    var coordinate: ChessGame.Coordinate {
        chessPiece!.coordinate
    }
    
    var type: ChessGame.Piece.PieceType {
        chessPiece!.type
    }
    
    private var pieceEntity: ModelEntity?
    private var selectionCube: SelectionCube?
    private var shadowEntity: ModelEntity?
    
    private var cancellable: AnyCancellable?
    
    var shadowOpacity: Float {
        get {
            (shadowEntity?.model?.materials.first as? CustomMaterial)?.custom.value[0] ?? 0
        }
        set {
            guard var material = shadowEntity?.model?.materials.first as? CustomMaterial else { return }
            material.custom.value = SIMD4<Float>(newValue, 0, 0, 0)
            shadowEntity?.model?.materials = [material]
        }
    }
    
    var capturedProgress: Float {
        get {
            (pieceEntity?.model?.materials.first as? CustomMaterial)?.custom.value[0] ?? 0
        }
        set {
            pieceEntity?.modifyMaterials { material in
                guard var customMaterial = material as? CustomMaterial else { return material }
                customMaterial.custom.value = SIMD4<Float>(newValue, 0, 0, 0)
                return customMaterial
            }
        }
    }
    
    convenience init(_ chessPieceData: ChessPieceData) {
        self.init()
        
        name = chessPieceData.name
        
        setup(with: chessPieceData)
        
        parameters[Self.shadowOpacityName] = BindableValue<Float>(0)
        parameters[Self.capturedProgressName] = BindableValue<Float>(0)
    }
    
    required init() {
        super.init()
    }
    
    func setup(with chessPieceData: ChessPieceData) {
        children.removeAll()
        
        let chessPieceComponent = ChessPieceComponent(
            isPlayer1: chessPieceData.isPlayer1,
            coordinate: chessPieceData.coordinate,
            type: chessPieceData.type
        )
        
        chessPiece = chessPieceComponent
        
        // Add shadow
        shadowCustomMaterial.blending = .transparent(opacity: 1.0)
        shadowCustomMaterial.custom.value = .zero
        let shadowEntity = ModelEntity(mesh: .generateBox(size: 1), materials: [shadowCustomMaterial])
        shadowEntity.scale = SIMD3<Float>(0.2, 0.01, 0.2)
        addChild(shadowEntity)
        self.shadowEntity = shadowEntity
        
        // Load chess piece USDZ file.
        cancellable = ModelEntity.loadModelAsync(named: chessPieceData.assetName)
            .receive(on: RunLoop.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] modelEntity in
                    guard let self = self else { return }
                    self.pieceEntity = modelEntity
                    modelEntity.orientation = chessPieceData.orientation
                    self.addChild(modelEntity)
                    modelEntity.generateCollisionShapes(recursive: true)
                    modelEntity.collision?.filter = CollisionFilter(group: .piece, mask: .all)
                    
                    modelEntity.modifyMaterials { material in
                        var customMaterial: CustomMaterial = try! CustomMaterial(
                            from: material,
                            geometryModifier: Self.geometryModifier
                        )
                        customMaterial.custom.value = SIMD4<Float>(0, 0, 0, 0)
                        return customMaterial
                    }
                    
                    // Set the position of the selection as the center of the entity.
                    let selectionCube = SelectionCube(player: self.player, type: self.type)
                    
                    // Add the selection cube to the selected entity.
                    modelEntity.addChild(selectionCube)
                    self.selectionCube = selectionCube
                    let boundingBox = modelEntity.visualBounds(relativeTo: modelEntity)
                    selectionCube.position.y = boundingBox.center.y
                    GameManager.shared.incrementPiecesLoaded()
                }
            )
    }
    
    func select() {
        guard let selectionCube = selectionCube else {
            return
        }
        
        lift(animationDuration: BoardGame.liftDropAnimationDuration)
        selectionCube.isEnabled = true
        selectionCube.playAnimation()
        
        // Remove shadows.
        shadowAnimation(animationDuration: BoardGame.liftDropAnimationDuration, reverse: true)
    }
    
    func unselect() {
        guard let selectionCube = selectionCube else {
            return
        }
        
        drop(animationDuration: BoardGame.liftDropAnimationDuration)
        selectionCube.isEnabled = false
        shadowAnimation(animationDuration: BoardGame.liftDropAnimationDuration)
    }
    
    // MARK: - Animations
    private func lift(animationDuration: Double) {
        guard let piece = pieceEntity else { return }
        let liftTransform = Transform(
            scale: .one,
            rotation: piece.orientation,
            translation: SIMD3<Float>(x: 0, y: liftedY, z: 0)
        )
        piece.move(to: liftTransform, relativeTo: self, duration: animationDuration)
    }
    
    private func drop(animationDuration: Double) {
        guard let piece = pieceEntity else { return }
        let newTransform = Transform(
            scale: .one,
            rotation: piece.orientation,
            translation: SIMD3<Float>(0, 0.01, 0)
        )
        piece.move(to: newTransform, relativeTo: self, duration: animationDuration)
    }
    
    func capturedAnimation() {
        let capturingAnimationDuration = 1.5 * BoardGame.liftDropAnimationDuration
        
        let animationDefinition = FromToByAnimation(
            name: "Captured",
            from: Float(0),
            to: Float(1),
            duration: capturingAnimationDuration,
            bindTarget: .parameter(Self.capturedProgressName)
        )
        
        if let animation = try? AnimationResource.generate(with: animationDefinition) {
            isBeingCaptured = true
            playAnimation(animation)
        }
        
        shadowAnimation(animationDuration: capturingAnimationDuration, reverse: true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + capturingAnimationDuration) {
            self.isBeingCaptured = false
            self.removeFromParent()
        }
    }
    
    func startupAnimation() {
        lift(animationDuration: 0)
        pieceEntity?.scale = SIMD3<Float>(repeating: 0.3)
        drop(animationDuration: BoardGame.startupAnimationDuration)
        shadowAnimation(animationDuration: BoardGame.startupAnimationDuration)
    }
    
    /// Displays shadow with animation.
    /// - Parameters:
    ///   - delay: delay applied to animation
    ///   - reverse: whether to display or remove the shadow
    func shadowAnimation(animationDuration: Double, reverse: Bool = false) {
        let animationDefinition = FromToByAnimation(
            name: "Shadow",
            from: shadowOpacity,
            to: reverse ? Float(0) : Float(1),
            duration: animationDuration,
            bindTarget: .parameter(Self.shadowOpacityName)
        )
        
        if let animation = try? AnimationResource.generate(with: animationDefinition) {
            isShadowAnimating = true
            playAnimation(animation)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            self.isShadowAnimating = false
        }
    }
}
