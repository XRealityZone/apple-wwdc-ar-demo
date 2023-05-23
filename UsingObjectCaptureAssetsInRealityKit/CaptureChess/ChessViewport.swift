/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A game-specific subclass of ARView.
*/

import RealityKit
import ARKit
import Combine
import UIKit

private let animationDuration = 0.25

class ChessViewport: ARView {
    
    private let gameManager: GameManager
    private let boardGame: BoardGame
    private let boardAnchor: AnchorEntity = AnchorEntity(
        plane: .horizontal,
        classification: [.floor, .table],
        minimumBounds: SIMD2<Float>(0.1, 0.1)
    )
    
    var bloomTexture: MTLTexture?
    
    private var subscriptions = Set<AnyCancellable>()
    
    init(gameManager: GameManager) {
        self.gameManager = gameManager
        
        MetalLibLoader.initializeMetal()
        AnimationSystem.registerSystem()
        
        self.boardGame = BoardGame()
        super.init(frame: .zero)
        
        // Turn on people occlusion.
        if ARWorldTrackingConfiguration.isSupported {
            automaticallyConfigureSession = false
            
            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = .horizontal
            if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
                configuration.frameSemantics.insert(.personSegmentationWithDepth)
            }
            session.run(configuration)
        }
        
        boardAnchor.isEnabled = false
        boardAnchor.addChild(boardGame)
        scene.addAnchor(boardAnchor)
        
        if let environmentResource = try? EnvironmentResource.load(named: "studio_ibl_chess") {
            environment.lighting.resource = environmentResource
        }
        
        let gestureView = GestureView(gameManager: gameManager, boardGame: boardGame)
        addSubview(gestureView)
        gestureView.translatesAutoresizingMaskIntoConstraints = false
        addConstraints([
            gestureView.topAnchor.constraint(equalTo: topAnchor),
            gestureView.leadingAnchor.constraint(equalTo: leadingAnchor),
            gestureView.trailingAnchor.constraint(equalTo: trailingAnchor),
            gestureView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        gameManager.$state
            .filter { $0 == .playing }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.boardAnchor.isEnabled = true
                self.boardGame.playStartupAnimation()
            }
            .store(in: &subscriptions)
        
        renderCallbacks.postProcess = postEffectBloom
    }
    
    required init(frame frameRect: CGRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

/// View that handles gestures.
private class GestureView: UIView {
    
    private let gameManager: GameManager
    private let boardGame: BoardGame
    
    init(gameManager: GameManager, boardGame: BoardGame) {
        self.gameManager = gameManager
        self.boardGame = boardGame
        super.init(frame: .zero)
        
        // Set up gestures
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tapGesture.numberOfTapsRequired = 1
        addGestureRecognizer(tapGesture)
        
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTapGesture.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTapGesture)
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        panGesture.maximumNumberOfTouches = 1
        addGestureRecognizer(panGesture)
        
        let rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation))
        addGestureRecognizer(rotationGesture)
        
        let scaleGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch))
        addGestureRecognizer(scaleGesture)
    }
    
    required init(coder: NSCoder) {
        fatalError()
    }
    
    @objc
    func handleTap(sender: UITapGestureRecognizer) {
        guard let viewport = superview as? ChessViewport,
              let ray = viewport.ray(through: sender.location(in: viewport)),
              !gameManager.state.done else {
            return
        }
        
        // A piece is selected, so move that piece.
        if let selectedPiece = gameManager.selectedPiece {
            guard let raycastResult = viewport.scene.raycast(
                origin: ray.origin,
                direction: ray.direction,
                length: 5,
                query: .nearest,
                mask: [.board, .piece]
            ).first else {
                return
            }
            
            // If the piece is selected, unselect it.
            if (raycastResult.entity as? HasCollision)?.collision?.filter.group == .piece,
               let piece = raycastResult.entity.parentChessPiece,
               piece.player == gameManager.turn {
                boardGame.unselect(selectedPiece)
                boardGame.unhighlight()
                boardGame.select(piece)
                gameManager.selectedPiece = piece
                let coordinates = gameManager.game.possibleMoves(for: piece.coordinate, player: gameManager.turn)
                boardGame.highlight(coordinates: coordinates)
                return
            }
            
            guard let coordinate = boardGame.coordinate(from: raycastResult.entity) else { return }
            let move = ChessGame.Move(from: selectedPiece.coordinate, to: coordinate)
            let isInCheck = gameManager.game.isInCheck(for: gameManager.turn)
            // Move the piece.
            let previousGame = gameManager.game
            if gameManager.game.validateMove(move) {
                let moves = gameManager.game.makeMove(move)
                
                // If the piece was in check before, then it must get out of check.
                if isInCheck, gameManager.game.isInCheck(for: gameManager.turn) {
                    gameManager.game = previousGame
                    print("Must get out of check")
                    return
                }
                
                // If the piece wasn't in check before, it's not allowed to move into check.
                if !isInCheck, gameManager.game.isInCheck(for: gameManager.turn) {
                    gameManager.game = previousGame
                    print("Illegal move, cannot move to check")
                    return
                }
                
                boardGame.unhighlight()
                boardGame.update(moves: moves)
                gameManager.selectedPiece = nil
                gameManager.turn.toggle()
                print("\(gameManager.game.printBoard())")
                
                if gameManager.game.isInCheckmate(for: gameManager.turn) {
                    gameManager.state = .checkmate
                    gameManager.turn.toggle() // Previous player wins
                    return
                }
                
                if gameManager.game.isInStalemate(for: gameManager.turn) {
                    gameManager.state = .stalemate
                    return
                }
            } else {
                print("Not a valid move!: \(move)")
            }
        }
        
        // No piece is selected yet, so select one.
        else {
            guard let raycastResult = viewport.scene.raycast(origin: ray.origin,
                                                             direction: ray.direction,
                                                             length: 5,
                                                             query: .nearest,
                                                             mask: .piece).first,
                  let piece = raycastResult.entity.parentChessPiece,
                  piece.player == gameManager.turn else {
                return
            }
            boardGame.select(piece)
            gameManager.selectedPiece = piece
            let coordinates = gameManager.game.possibleMoves(for: piece.coordinate, player: gameManager.turn)
            boardGame.highlight(coordinates: coordinates)
        }
    }
    
    @objc
    func handleDoubleTap(sender: UITapGestureRecognizer) {
        moveBoard(to: sender.location(in: self))
    }
    
    @objc
    func handlePan(sender: UIPanGestureRecognizer) {
        let location = sender.location(in: self)
        moveBoard(to: location)
    }
    
    @objc
    func handleRotation(sender: UIRotationGestureRecognizer) {
        let orientation = simd_quatf(angle: -Float(sender.rotation), axis: SIMD3<Float>(0, 1, 0))
        boardGame.setOrientation(orientation, relativeTo: boardGame)
        sender.rotation = 0
    }
    
    @objc
    func handlePinch(sender: UIPinchGestureRecognizer) {
        boardGame.setScale(SIMD3<Float>(repeating: Float(sender.scale)), relativeTo: boardGame)
        boardGame.scale = SIMD3<Float>(repeating: min(max(0.5, boardGame.scale.x), 1.5))
    }
    
    private func moveBoard(to location: CGPoint) {
        guard let viewport = superview as? ChessViewport,
              let raycastResult = viewport.raycast(from: location, allowing: .existingPlaneInfinite, alignment: .horizontal).first else {
            return
        }
        let location = Transform(matrix: raycastResult.worldTransform).translation
        let newTransform = Transform(
            scale: boardGame.scale(relativeTo: nil),
            rotation: boardGame.orientation(relativeTo: nil),
            translation: location
        )
        boardGame.move(to: newTransform, relativeTo: nil, duration: animationDuration)
    }
}

extension GestureView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer is UIPinchGestureRecognizer, otherGestureRecognizer is UIRotationGestureRecognizer {
            return true
        }
        return false
    }
}
