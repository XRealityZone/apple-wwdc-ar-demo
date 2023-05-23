/*
See LICENSE folder for this sample’s licensing information.

Abstract:
An object that contains game-specific data.
*/
import simd

struct ChessPieceData {
    let name: String
    let assetName: String
    let isPlayer1: Bool
    let coordinate: ChessGame.Coordinate
    let orientation: simd_quatf
    let type: ChessGame.Piece.PieceType
}

extension ChessPieceData {
    static let data = [
        // Define the player 1 pieces.
        ChessPieceData(
            name: "Player 1 Rook 1",
            assetName: "rook-light",
            isPlayer1: true,
            coordinate: ChessGame.Coordinate(x: 0, y: 0),
            orientation: simd_quatf(angle: .pi, axis: .j),
            type: .rook
        ),
        ChessPieceData(
            name: "Player 1 Knight 1",
            assetName: "knight-light",
            isPlayer1: true,
            coordinate: ChessGame.Coordinate(x: 1, y: 0),
            orientation: simd_quatf(angle: .pi, axis: .j),
            type: .knight
        ),
        ChessPieceData(
            name: "Player 1 Bishop 1",
            assetName: "bishop-light",
            isPlayer1: true,
            coordinate: ChessGame.Coordinate(x: 2, y: 0),
            orientation: simd_quatf(angle: -.pi / 2, axis: .j),
            type: .bishop
        ),
        ChessPieceData(
            name: "Player 1 Queen",
            assetName: "queen-light",
            isPlayer1: true,
            coordinate: ChessGame.Coordinate(x: 3, y: 0),
            orientation: simd_quatf(angle: .pi, axis: .j),
            type: .queen
        ),
        ChessPieceData(
            name: "Player 1 King",
            assetName: "king-light",
            isPlayer1: true,
            coordinate: ChessGame.Coordinate(x: 4, y: 0),
            orientation: simd_quatf(angle: .pi, axis: .j),
            type: .king
        ),
        ChessPieceData(
            name: "Player 1 Bishop 2",
            assetName: "bishop-light",
            isPlayer1: true,
            coordinate: ChessGame.Coordinate(x: 5, y: 0),
            orientation: simd_quatf(angle: .pi / 2, axis: .j),
            type: .bishop
        ),
        ChessPieceData(
            name: "Player 1 Knight 2",
            assetName: "knight-light",
            isPlayer1: true,
            coordinate: ChessGame.Coordinate(x: 6, y: 0),
            orientation: simd_quatf(angle: .pi, axis: .j),
            type: .knight
        ),
        ChessPieceData(
            name: "Player 1 Rook 2",
            assetName: "rook-light",
            isPlayer1: true,
            coordinate: ChessGame.Coordinate(x: 7, y: 0),
            orientation: simd_quatf(angle: .pi, axis: .j),
            type: .rook
        ),
        ChessPieceData(
            name: "Player 1 Pawn 1",
            assetName: "pawn-light",
            isPlayer1: true,
            coordinate: ChessGame.Coordinate(x: 0, y: 1),
            orientation: .identity,
            type: .pawn
        ),
        ChessPieceData(
            name: "Player 1 Pawn 2",
            assetName: "pawn-light",
            isPlayer1: true,
            coordinate: ChessGame.Coordinate(x: 1, y: 1),
            orientation: simd_quatf(angle: .pi / 2, axis: .j),
            type: .pawn
        ),
        ChessPieceData(
            name: "Player 1 Pawn 3",
            assetName: "pawn-light",
            isPlayer1: true,
            coordinate: ChessGame.Coordinate(x: 2, y: 1),
            orientation: simd_quatf(angle: .pi, axis: .j),
            type: .pawn
        ),
        ChessPieceData(
            name: "Player 1 Pawn 4",
            assetName: "pawn-light",
            isPlayer1: true,
            coordinate: ChessGame.Coordinate(x: 3, y: 1),
            orientation: simd_quatf(angle: -.pi / 2, axis: .j),
            type: .pawn
        ),
        ChessPieceData(
            name: "Player 1 Pawn 5",
            assetName: "pawn-light",
            isPlayer1: true,
            coordinate: ChessGame.Coordinate(x: 4, y: 1),
            orientation: .identity,
            type: .pawn
        ),
        ChessPieceData(
            name: "Player 1 Pawn 6",
            assetName: "pawn-light",
            isPlayer1: true,
            coordinate: ChessGame.Coordinate(x: 5, y: 1),
            orientation: simd_quatf(angle: .pi / 2, axis: .j),
            type: .pawn
        ),
        ChessPieceData(
            name: "Player 1 Pawn 7",
            assetName: "pawn-light",
            isPlayer1: true,
            coordinate: ChessGame.Coordinate(x: 6, y: 1),
            orientation: simd_quatf(angle: .pi, axis: .j),
            type: .pawn
        ),
        ChessPieceData(
            name: "Player 1 Pawn 8",
            assetName: "pawn-light",
            isPlayer1: true,
            coordinate: ChessGame.Coordinate(x: 7, y: 1),
            orientation: simd_quatf(angle: -.pi / 2, axis: .j),
            type: .pawn
        ),
        // Define the player 2 pieces.
        ChessPieceData(
            name: "Player 2 Rook 1",
            assetName: "rook-dark",
            isPlayer1: false,
            coordinate: ChessGame.Coordinate(x: 0, y: 7),
            orientation: .identity,
            type: .rook
        ),
        ChessPieceData(
            name: "Player 2 Knight 1",
            assetName: "knight-dark",
            isPlayer1: false,
            coordinate: ChessGame.Coordinate(x: 1, y: 7),
            orientation: .identity,
            type: .knight
        ),
        ChessPieceData(
            name: "Player 2 Bishop 1",
            assetName: "bishop-dark",
            isPlayer1: false,
            coordinate: ChessGame.Coordinate(x: 2, y: 7),
            orientation: simd_quatf(angle: -.pi / 2, axis: .j),
            type: .bishop
        ),
        ChessPieceData(
            name: "Player 2 Queen",
            assetName: "queen-dark",
            isPlayer1: false,
            coordinate: ChessGame.Coordinate(x: 3, y: 7),
            orientation: .identity,
            type: .queen
        ),
        ChessPieceData(
            name: "Player 2 King",
            assetName: "king-dark",
            isPlayer1: false,
            coordinate: ChessGame.Coordinate(x: 4, y: 7),
            orientation: .identity,
            type: .king
        ),
        ChessPieceData(
            name: "Player 2 Bishop 2",
            assetName: "bishop-dark",
            isPlayer1: false,
            coordinate: ChessGame.Coordinate(x: 5, y: 7),
            orientation: simd_quatf(angle: .pi / 2, axis: .j),
            type: .bishop
        ),
        ChessPieceData(
            name: "Player 2 Knight 2",
            assetName: "knight-dark",
            isPlayer1: false,
            coordinate: ChessGame.Coordinate(x: 6, y: 7),
            orientation: .identity,
            type: .knight
        ),
        ChessPieceData(
            name: "Player 2 Rook 2",
            assetName: "rook-dark",
            isPlayer1: false,
            coordinate: ChessGame.Coordinate(x: 7, y: 7),
            orientation: .identity,
            type: .rook
        ),
        ChessPieceData(
            name: "Player 2 Pawn 1",
            assetName: "pawn-dark",
            isPlayer1: false,
            coordinate: ChessGame.Coordinate(x: 0, y: 6),
            orientation: .identity,
            type: .pawn
        ),
        ChessPieceData(
            name: "Player 2 Pawn 2",
            assetName: "pawn-dark",
            isPlayer1: false,
            coordinate: ChessGame.Coordinate(x: 1, y: 6),
            orientation: simd_quatf(angle: .pi / 2, axis: .j),
            type: .pawn
        ),
        ChessPieceData(
            name: "Player 2 Pawn 3",
            assetName: "pawn-dark",
            isPlayer1: false,
            coordinate: ChessGame.Coordinate(x: 2, y: 6),
            orientation: simd_quatf(angle: .pi, axis: .j),
            type: .pawn
        ),
        ChessPieceData(
            name: "Player 2 Pawn 4",
            assetName: "pawn-dark",
            isPlayer1: false,
            coordinate: ChessGame.Coordinate(x: 3, y: 6),
            orientation: simd_quatf(angle: -.pi / 2, axis: .j),
            type: .pawn
        ),
        ChessPieceData(
            name: "Player 2 Pawn 5",
            assetName: "pawn-dark",
            isPlayer1: false,
            coordinate: ChessGame.Coordinate(x: 4, y: 6),
            orientation: .identity,
            type: .pawn
        ),
        ChessPieceData(
            name: "Player 2 Pawn 6",
            assetName: "pawn-dark",
            isPlayer1: false,
            coordinate: ChessGame.Coordinate(x: 5, y: 6),
            orientation: simd_quatf(angle: .pi / 2, axis: .j),
            type: .pawn
        ),
        ChessPieceData(
            name: "Player 2 Pawn 7",
            assetName: "pawn-dark",
            isPlayer1: false,
            coordinate: ChessGame.Coordinate(x: 6, y: 6),
            orientation: simd_quatf(angle: .pi, axis: .j),
            type: .pawn
        ),
        ChessPieceData(
            name: "Player 2 Pawn 8",
            assetName: "pawn-dark",
            isPlayer1: false,
            coordinate: ChessGame.Coordinate(x: 7, y: 6),
            orientation: simd_quatf(angle: -.pi / 2, axis: .j),
            type: .pawn
        )
    ]
}
