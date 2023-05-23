/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A RealityKit System that manages animating chess pieces.
*/

import RealityKit

class AnimationSystem: System {
    
    required init(scene: Scene) {
        
    }
    
    func update(context: SceneUpdateContext) {
        let chessPieces = context.scene.performQuery(ChessPieceComponent.query)
        
        for chessPiece in chessPieces {
            guard let chessPiece = chessPiece as? ChessPiece else { return }
            if chessPiece.isShadowAnimating,
               let bindableValue = chessPiece.bindableValues[.parameter(ChessPiece.shadowOpacityName), Float.self] {
                chessPiece.shadowOpacity = bindableValue.value
            }
            if chessPiece.isBeingCaptured,
               let bindableValue = chessPiece.bindableValues[.parameter(ChessPiece.capturedProgressName), Float.self] {
                chessPiece.capturedProgress = bindableValue.value
            }
        }
        
        let checkers = context.scene.performQuery(CheckerComponent.query)
        
        for checker in checkers {
            guard let checker = checker as? ModelEntity,
                  let checkerComponent = checker.components[CheckerComponent.self] as? CheckerComponent,
                  var customMaterial = checker.model?.materials.first as? CustomMaterial else { return }
            let newValue = SIMD4<Float>(checkerComponent.isPossibleMove ? 1 : 0, 0, 0, 0)
            if customMaterial.custom.value != newValue {
                customMaterial.custom.value = newValue
                checker.model?.materials = [customMaterial]
            }
        }
    }
    
}
