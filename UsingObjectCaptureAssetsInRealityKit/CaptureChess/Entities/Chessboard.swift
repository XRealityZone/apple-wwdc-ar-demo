/*
See LICENSE folder for this sample’s licensing information.

Abstract:
An entity that represents the chess board.
*/

import Foundation
import Combine
import RealityKit

// MARK: - Chessboard
class Chessboard: Entity {
    
    static let numOfColumns = 8
    static let height: Float = 0.01
    static let size: Float = 1.6
    static let checkerSize: Float = Chessboard.size / Float(Chessboard.numOfColumns)
    
    private var borderCancellable: AnyCancellable?
    
    private var border: Entity?
    
    private var checkers: [ModelEntity] {
        scene?
            .performQuery(CheckerComponent.query)
            .compactMap { $0 as? ModelEntity } ?? []
    }
    
    required init() {
        super.init()
        
        let whiteSurfaceShader = CustomMaterial.SurfaceShader(named: "whiteCheckerSurface", in: MetalLibLoader.library)
        let blackSurfaceShader = CustomMaterial.SurfaceShader(named: "blackCheckerSurface", in: MetalLibLoader.library)
        
        let whiteCustomMaterial = try! CustomMaterial(surfaceShader: whiteSurfaceShader, lightingModel: .lit)
        let blackCustomMaterial = try! CustomMaterial(surfaceShader: blackSurfaceShader, lightingModel: .lit)
        
        (0..<Self.numOfColumns).forEach { x in
            (0..<Self.numOfColumns).forEach { y in
                let coordinate = ChessGame.Coordinate(x: x, y: y)
                
                let material = x % 2 == 0 ?
                    (y % 2 == 0 ? blackCustomMaterial : whiteCustomMaterial) :
                    (y % 2 == 0 ? whiteCustomMaterial : blackCustomMaterial)
                let checker = ModelEntity(mesh: .generateBox(size: 1), materials: [material])
                checker.generateCollisionShapes(recursive: true)
                checker.collision?.filter = CollisionFilter(group: .board, mask: .all)
                checker.position = calculatePosition(from: coordinate, y: Self.height / 2)
                checker.scale = SIMD3<Float>(x: Self.checkerSize, y: Self.height, z: Self.checkerSize)
                let checkerComponent = CheckerComponent(coordinate: coordinate)
                checker.components[CheckerComponent.self] = checkerComponent
                addChild(checker)
            }
        }
        
        borderCancellable = Entity.loadAsync(named: "BoardBorder")
            .receive(on: RunLoop.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] entity in
                    self?.border = entity
                    self?.addChild(entity)
                }
            )
    }
    
    // MARK: - Helper functions
    func calculatePosition(from coordinate: ChessGame.Coordinate, y: Float) -> SIMD3<Float> {
        let squareSize = Self.size / Float(Chessboard.numOfColumns)
        let halfSquareSize = squareSize / 2
        
        let x = -(Self.size / 2) + Float(coordinate.x) * squareSize + halfSquareSize
        let z = Self.size / 2 - Float(coordinate.y) * squareSize - halfSquareSize
        return SIMD3<Float>(x: x, y: y, z: z)
    }
    
    func playAnimation() {
        checkers
            .forEach { entity in
                let currentTransform = entity.transform
                entity.transform.translation += SIMD3<Float>(0, 0.1, 0)
                entity.move(to: currentTransform, relativeTo: entity.parent, duration: BoardGame.startupAnimationDuration)
            }
        
        if let border = border {
            ([border] + descendants)
                .forEach { entity in
                    entity.availableAnimations.forEach {
                        entity.playAnimation($0)
                    }
                }
        }
    }
    
    func highlight(coordinates: [ChessGame.Coordinate]) {
        checkers
            .forEach { checker in
                guard var checkerComponent = checker.components[CheckerComponent.self] as? CheckerComponent,
                      coordinates.contains(checkerComponent.coordinate) else { return }
                checkerComponent.isPossibleMove = true
                checker.components[CheckerComponent.self] = checkerComponent
            }
    }
    
    func unhighlight() {
        checkers
            .forEach { checker in
                guard var checkerComponent = checker.components[CheckerComponent.self] as? CheckerComponent else { return }
                checkerComponent.isPossibleMove = false
                checker.components[CheckerComponent.self] = checkerComponent
            }
    }
}
