/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Game-specific RealityKit components.
*/

import RealityKit

protocol HasChessPiece: Entity { }

extension HasChessPiece {
    var chessPiece: ChessPieceComponent? {
        get {
            components[ChessPieceComponent.self]
        }
        set {
            components[ChessPieceComponent.self] = newValue
        }
    }
}

struct CheckerComponent: Component {
    static let query = EntityQuery(where: .has(CheckerComponent.self))
    
    let coordinate: ChessGame.Coordinate
    var isPossibleMove: Bool = false
}

struct ChessPieceComponent: Component {
    
    static let query = EntityQuery(where: .has(ChessPieceComponent.self))
    
    let isPlayer1: Bool
    var coordinate: ChessGame.Coordinate
    var type: ChessGame.Piece.PieceType
}
