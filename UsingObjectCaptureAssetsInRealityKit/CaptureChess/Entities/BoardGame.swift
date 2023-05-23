/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A parent entity for the chessboard and chess pieces.
*/
import Foundation
import RealityKit

// MARK: - BoardGame
class BoardGame: Entity {
    
    static let liftDropAnimationDuration: Double = 0.5
    static let startupAnimationDuration: Double = 2
    
    private var chessboard: Chessboard? {
        children
            .compactMap { $0 as? Chessboard }
            .first
    }
    
    private var pieces: [ChessPiece] {
        scene?
            .performQuery(.chessPieceQuery)
            .compactMap { $0 as? ChessPiece }
            .filter { $0.isEnabled } ?? []
    }
    
    required init() {
        super.init()
        
        setUp()
    }
    
    private func setUp() {
        // Set up the chessboard.
        let chessboard = Chessboard()
        addChild(chessboard)
        
        // Set up the chess pieces.
        ChessPieceData.data.forEach {
            let position = chessboard.calculatePosition(from: $0.coordinate, y: Chessboard.height)
            let chessPiece = ChessPiece($0)
            chessPiece.position = position
            addChild(chessPiece)
        }
    }
    
    func playStartupAnimation() {
        chessboard?.playAnimation()
        pieces.forEach {
            $0.startupAnimation()
        }
    }
    
    func select(_ piece: ChessPiece) {
        piece.select()
    }
    
    func unselect(_ piece: ChessPiece) {
        piece.unselect()
    }
    
    func coordinate(from entity: Entity) -> ChessGame.Coordinate? {
        guard let checkerComponent = entity.components[CheckerComponent.self] as? CheckerComponent else {
            return (entity.parentChessPiece?.components[ChessPieceComponent.self] as? ChessPieceComponent)?.coordinate
        }
        return checkerComponent.coordinate
    }
    
    func removePiece(at coordinate: ChessGame.Coordinate) {
        if let victim = getPiece(at: coordinate) {
            victim.capturedAnimation()
        }
    }
    
    func getPiece(at coordinate: ChessGame.Coordinate) -> ChessPiece? {
        pieces.first(where: { $0.chessPiece?.coordinate == coordinate })
    }
    
    func promote(piece: ChessPiece) {
        guard let chessPiece = piece.chessPiece else { return }
        
        if let queenChessPieceData = ChessPieceData.data.first(where: { $0.isPlayer1 == piece.chessPiece?.isPlayer1 && $0.type == .queen }) {
            piece.setup(with: queenChessPieceData)
        }
        
        piece.chessPiece?.coordinate = chessPiece.coordinate
    }
    
    func update(moves: [ChessGame.Move]) {
        moves.forEach {
            guard let piece = getPiece(at: $0.from) else { return }
            // If a piece is there, remove it.
            removePiece(at: $0.to)
            
            self.move(piece: piece, to: $0.to)
            
            if $0.isPromotion {
                promote(piece: piece)
            }
        }
    }
    
    func highlight(coordinates: [ChessGame.Coordinate]) {
        chessboard?.highlight(coordinates: coordinates)
    }
    
    func unhighlight() {
        chessboard?.unhighlight()
    }
    
    private func slidePiece(piece: ChessPiece, to position: SIMD3<Float>, callback: @escaping() -> Void = {}) {
        let slideTransform = Transform(
            scale: piece.scale,
            rotation: piece.orientation,
            translation: position
        )
        piece.move(to: slideTransform, relativeTo: self, duration: BoardGame.liftDropAnimationDuration)
        DispatchQueue.main.asyncAfter(deadline: .now() + BoardGame.liftDropAnimationDuration, execute: callback)
    }
    
    private func move(piece: ChessPiece, to coordinate: ChessGame.Coordinate) {
        guard let newPosition = chessboard?.calculatePosition(from: coordinate, y: piece.position.y) else { return }
        piece.chessPiece?.coordinate = coordinate
        
        // Start the slide animation.
        slidePiece(piece: piece, to: newPosition) {
            self.unselect(piece)
        }
    }
}
