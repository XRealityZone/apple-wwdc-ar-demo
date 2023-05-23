/*
See LICENSE folder for this sample’s licensing information.

Abstract:
An objects that represents a game of chess.
*/


import SwiftUI

/// Structure that represents a chess game.
struct ChessGame {
    
    typealias Board = [[ChessGame.Piece?]]
    
     /// Coordinate for the chessboard, which assumes the bottom left is (0, 0).
     /// Examples:
     ///    (0, 0) -> a1
     ///    (5, 3) -> f4
    struct Coordinate: Equatable {
        
        struct Delta: Equatable {
            let x, y: Int
        }
        
        var x, y: Int
        
        static func - (lhs: Coordinate, rhs: Coordinate) -> Delta {
            return Delta(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
        }
        
        static func + (lhs: Coordinate, rhs: Delta) -> Coordinate {
            return Coordinate(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
        }
        
        static func += (lhs: inout Coordinate, rhs: Delta) {
            lhs.x += rhs.x
            lhs.y += rhs.y
        }
    }
    
    /// A structure that represents a single chess piece.
    struct Piece {
        let player: Player
        let type: PieceType
        
        enum PieceType {
            case pawn
            case bishop
            case knight
            case rook
            case queen
            case king
            
            var value: Int {
                switch self {
                case .pawn:
                    return 1
                case .bishop, .knight:
                    return 3
                case .rook:
                    return 5
                case .queen:
                    return 9
                case .king:
                    return -1
                }
            }
            
            var isTall: Bool {
                switch self {
                case .queen, .king:
                    return true
                default:
                    return false
                }
            }
        }
        
        var emoji: String {
            switch type {
            case .pawn:
                return player == .player1 ? "♙" : "♟"
            case .bishop:
                return player == .player1 ? "♗" : "♝"
            case .knight:
                return player == .player1 ? "♘" : "♞"
            case .rook:
                return player == .player1 ? "♖" : "♜"
            case .queen:
                return player == .player1 ? "♕" : "♛"
            case .king:
                return player == .player1 ? "♔" : "♚"
            }
        }
        
        /// Validates a  move for a specific piece type.
        /// - Parameters:
        ///   - move: Move to be validated.
        /// - Returns: Returns true if valid; otherwise, false.
        func validateMove(_ move: Move) -> Bool {
            let delta = move.to - move.from
            switch self.type {
            case .pawn:
                guard delta.x == 0 else { return false }
                if player == .player1 {
                    // It is their first move, and they can move up two ranks.
                    if move.from.y == 1 {
                        guard 0 < delta.y, delta.y <= 2 else { return false }
                    } else {
                        guard delta.y == 1 else { return false }
                    }
                } else {
                    // It's their first move, and they can move up two ranks.
                    if move.from.y == 6 {
                        guard -2 <= delta.y, delta.y < 0 else { return false }
                    } else {
                        guard delta.y == -1 else { return false }
                    }
                }
                return true
            case .bishop:
                // Diagonal only.
                return abs(delta.x) == abs(delta.y)
            case .knight:
                // L-shape only.
                return (abs(delta.x) == 1 && abs(delta.y) == 2) || (abs(delta.x) == 2 && abs(delta.y) == 1)
            case .rook:
                // Horizontal or vertical only.
                return (abs(delta.x) == 0 || abs(delta.y) == 0)
            case .queen:
                // Diagonal or horizontal or vertical.
                let bishop = Piece(player: player, type: .bishop)
                let rook = Piece(player: player, type: .rook)
                return bishop.validateMove(move) || rook.validateMove(move)
            case .king:
                // Move only one square in all directions.
                return abs(delta.x) <= 1 && abs(delta.y) <= 1
            }
        }
    }
    
    /// Represents a move that a piece can make.
    struct Move {
        let from: Coordinate
        let to: Coordinate
        var isPromotion: Bool = false
        
        var delta: Coordinate.Delta {
            to - from
        }
    }
    
    enum Player {
        case player1
        case player2
        
        var name: String {
            switch self {
            case .player1:
                return "Player 1"
            case .player2:
                return "Player 2"
            }
        }
        
        var color: Color {
            switch self {
            case .player1:
                return .yellow
            case .player2:
                return .blue
            }
        }
        
        var fontColor: Color {
            switch self {
            case .player1:
                return .black
            case .player2:
                return .white
            }
        }
    }
    
    var board: Board = .initialBoard
    var history: [Move] = []
}

// MARK: - Helper functions
extension ChessGame.Player {
    mutating func toggle() {
        self = self == .player1 ? .player2 : .player1
    }
}

extension ChessGame {
    func piece(at coordinate: Coordinate) -> Piece? {
        board[coordinate.x][coordinate.y]
    }
    
    private mutating func setPiece(at coordinate: Coordinate, piece: Piece) {
        board[coordinate.x][coordinate.y] = piece
    }
    
    private mutating func removePiece(at coordinate: Coordinate) {
        board[coordinate.x][coordinate.y] = nil
    }
    
    @discardableResult
    mutating func makeMove(_ move: Move) -> [Move] {
        guard let piece = piece(at: move.from) else { return [] }
        
        var moves: [Move] = []
        
        // Check if castling is valid, and move the rook if it is.
        if piece.type == .king, validateCastling(move) {
            let delta = move.delta
            let rookCoordinate = delta.x == 2 ? move.from + Coordinate.Delta(x: 3, y: 0) : move.from + Coordinate.Delta(x: -4, y: 0)
            if let rookPiece = self.piece(at: rookCoordinate) {
                removePiece(at: rookCoordinate)
                let newRookCoordinate = rookCoordinate + Coordinate.Delta(x: delta.x == 2 ? -2 : 3, y: 0)
                setPiece(at: newRookCoordinate, piece: rookPiece)
                moves.append(Move(from: rookCoordinate, to: newRookCoordinate))
            }
        }
        // Check if en passant is a valid move, and perform it if it is.
        else if piece.type == .pawn, validateEnPassant(move),
                let lastMove = history.last {
            removePiece(at: lastMove.to)
            moves.append(Move(from: lastMove.to, to: lastMove.to))
        }
        
        setPiece(at: move.to, piece: piece)
        removePiece(at: move.from)
        
        history.append(move)
        
        // Check if this move should be a promotion.
        if validatePromotion(at: move.to) {
            let promotedPiece = Piece(player: piece.player, type: .queen)
            setPiece(at: move.to, piece: promotedPiece)
            var promotionMove = move
            promotionMove.isPromotion = true
            moves.append(promotionMove)
        } else {
            moves.append(move)
        }
        
        return moves
    }
}

// MARK: - State check
extension ChessGame {
    private func kingCoordinate(for player: ChessGame.Player) -> Coordinate? {
        for x in 0..<Chessboard.numOfColumns {
            for y in 0..<Chessboard.numOfColumns {
                let coordinate = Coordinate(x: x, y: y)
                if let piece = piece(at: coordinate),
                   piece.player == player,
                   piece.type == .king {
                    return coordinate
                }
            }
        }
        return nil
    }
    
    private func coordinates(for player: ChessGame.Player) -> [Coordinate] {
        var coordinates = [Coordinate]()
        for x in 0..<Chessboard.numOfColumns {
            for y in 0..<Chessboard.numOfColumns {
                let coordinate = Coordinate(x: x, y: y)
                if let piece = piece(at: coordinate),
                   piece.player == player {
                    coordinates.append(coordinate)
                }
            }
        }
        return coordinates
    }
    
    // King is under attack for player.
    func isInCheck(for player: ChessGame.Player) -> Bool {
        guard let kingCoordinate = kingCoordinate(for: player) else {
            print("Can't find king!?")
            return false
        }
        
        var player = player
        player.toggle()
        let validMovePiece = coordinates(for: player)
            .first(where: { coordinate in
                let move = ChessGame.Move(from: coordinate, to: kingCoordinate)
                return validateMove(move)
            })
        
        return validMovePiece != nil
    }
    
    private var allCoordinates: [Coordinate] {
        var coordinates: [Coordinate] = []
        (0..<Chessboard.numOfColumns).forEach { x in
            (0..<Chessboard.numOfColumns).forEach { y in
                coordinates.append(Coordinate(x: x, y: y))
            }
        }
        return coordinates
    }
    
    func possibleMoves(for coordinate: Coordinate, player: Player) -> [Coordinate] {
        allCoordinates
            .map { Move(from: coordinate, to: $0) }
            .filter { validateMove($0) }.filter {
                // Can't move to check.
                var nextMoveGame = self
                nextMoveGame.makeMove($0)
                return !nextMoveGame.isInCheck(for: player)
            }
            .map { $0.to }
    }
    
    func isInStalemate(for player: ChessGame.Player) -> Bool {
        let playerCoordinates = coordinates(for: player)
        for playerCoordinate in playerCoordinates {
            for coordinate in allCoordinates {
                let move = Move(from: playerCoordinate, to: coordinate)
                var nextPlayGame = self
                nextPlayGame.makeMove(move)
                if validateMove(move), !nextPlayGame.isInCheck(for: player) {
                    return false
                }
            }
        }
        return true
    }
    
    func isInCheckmate(for player: ChessGame.Player) -> Bool {
        guard isInCheck(for: player) else { return false }
        // If the piece is in check and can't make any moves to get out of
        // check, then it's a checkmate.
        let playerCoordinates = coordinates(for: player)
        for playerCoordinate in playerCoordinates {
            for coordinate in allCoordinates {
                let move = Move(from: playerCoordinate, to: coordinate)
                if validateMove(move) {
                    var nextMoveGame = self
                    nextMoveGame.makeMove(move)
                    if !nextMoveGame.isInCheck(for: player) {
                        return false
                    }
                }
            }
        }
        return true
    }
}

// MARK: - Validation
extension ChessGame {
    func validateMove(_ move: Move) -> Bool {
        guard let movingPiece = piece(at: move.from) else {
            // There's no piece at the specified coordinate.
            return false
        }
        
        let delta = move.delta
        
        if let victim = piece(at: move.to) {
            // Can't move to a coordinate a player's piece occupies.
            guard victim.player != movingPiece.player else { return false }
            
            // Check if the pawn can capture this piece.
            // This is a special case because pawns can capture only diagonally.
            if movingPiece.type == .pawn {
                guard abs(delta.x) == 1 else { return false }
                return movingPiece.player == .player1 ? delta.y == 1 : delta.y == -1
            }
        }
        
        switch movingPiece.type {
        case .pawn:
            return (movingPiece.validateMove(move) && !pieceExists(move)) || validateEnPassant(move)
        case .bishop:
            return movingPiece.validateMove(move) && !pieceExists(move)
        case .knight:
            return movingPiece.validateMove(move)
        case .rook:
            return movingPiece.validateMove(move) && !pieceExists(move)
        case .queen:
            return movingPiece.validateMove(move) && !pieceExists(move)
        case .king:
            return movingPiece.validateMove(move) || validateCastling(move)
        }
    }
    
    private func validateEnPassant(_ move: Move) -> Bool {
        guard let movingPiece = piece(at: move.from),
              let lastMove = history.last else { return false }
        
        // Check if the capturing pawn has advanced exactly three ranks.
        guard movingPiece.type == .pawn,
              movingPiece.player == .player1 ? move.from.y == 4 : move.from.y == 3 else { return false }
        
        // Check if the captured pawn moved two squares in one move, landing right next to the capturing pawn.
        guard let victim = piece(at: lastMove.to),
              victim.type == .pawn,
              victim.player != movingPiece.player,
              move.from.y == lastMove.to.y,
              abs(move.from.x - lastMove.to.x) == 1 else { return false }
        
        // Perform capture on the turn immediately after the pawn being captured moves.
        let lastMoveDelta = lastMove.to - lastMove.from
        guard abs(lastMoveDelta.y) == 2,
              move.to.x == lastMove.to.x,
              movingPiece.player == .player1 ? move.to.y == lastMove.to.y + 1 : move.to.y == lastMove.to.y - 1 else { return false }
        return true
    }
    
    private func validateCastling(_ move: Move) -> Bool {
        guard let king = piece(at: move.from) else { return false }
        
        let kingCoordinate = move.from
        let delta = move.to - move.from
        
        // Check if kingside or queenside castling.
        guard abs(delta.x) == 2, delta.y == 0 else { return false }
        
        // Can't castle if king is in check.
        guard !isInCheck(for: king.player) else { return false }
        
        // Check if any of the moves king passes through could be attacked.
        let incrementX = delta.x == 0 ? 0 : (delta.x > 0 ? 1 : -1)
        let incrementY = delta.y == 0 ? 0 : (delta.y > 0 ? 1 : -1)
        
        var coordinate = move.from + Coordinate.Delta(x: incrementX, y: incrementY)
        while coordinate != move.to {
            let passThroughMove = Move(from: kingCoordinate, to: coordinate)
            var nextMoveGame = self
            nextMoveGame.makeMove(passThroughMove)
            if nextMoveGame.isInCheck(for: king.player) {
                return false
            }
            coordinate += Coordinate.Delta(x: incrementX, y: incrementY)
        }
        
        // Check if the king or rook have made a move yet.
        let rookCoordinate = delta.x == 2 ? move.from + Coordinate.Delta(x: 3, y: 0) : move.from + Coordinate.Delta(x: -4, y: 0)
        guard kingCoordinate.x == 4,
              king.player == .player1 ? kingCoordinate.y == 0 : kingCoordinate.y == 7,
              !history.contains(where: { $0.from == rookCoordinate }),
              !history.contains(where: { $0.from == kingCoordinate }) else { return false }
        
        // Check if there are any pieces in between the king and the rook.
        guard !pieceExists(move) else { return false }
        return true
    }
    
    /// Check if there are pieces between the to and from value of the move.
    /// - Parameter move: The move the player is about to make.
    /// - Returns: Returns true is there is a piece between the two coordinates. Otherwise, returns false.
    private func pieceExists(_ move: Move) -> Bool {
        let delta = move.to - move.from
        
        let incrementX = delta.x == 0 ? 0 : (delta.x > 0 ? 1 : -1)
        let incrementY = delta.y == 0 ? 0 : (delta.y > 0 ? 1 : -1)
        
        var coordinate = move.from + Coordinate.Delta(x: incrementX, y: incrementY)
        while coordinate != move.to {
            if piece(at: coordinate) != nil {
                return true
            }
            coordinate += Coordinate.Delta(x: incrementX, y: incrementY)
        }
        return false
    }
    
    private func validatePromotion(at coordinate: Coordinate) -> Bool {
        guard let piece = piece(at: coordinate),
              piece.type == .pawn,
              (piece.player == .player1 && coordinate.y == 7) || (piece.player == .player2 && coordinate.y == 0) else { return false }
        return true
    }
}

extension ChessGame {
    func printBoard() {
        (0..<Chessboard.numOfColumns).reversed().forEach { row in
            var rowString = ""
            (0..<Chessboard.numOfColumns).forEach { col in
                rowString += board[col][row]?.emoji ?? " "
            }
            print(rowString)
        }
    }
}

extension ChessGame.Board {
    static let initialBoard: ChessGame.Board =
        [
            // a
            [
                ChessGame.Piece(player: .player1, type: .rook), // a1
                ChessGame.Piece(player: .player1, type: .pawn), // a2
                nil, // a3
                nil, // a4
                nil, // a5
                nil, // a6
                ChessGame.Piece(player: .player2, type: .pawn), // a7
                ChessGame.Piece(player: .player2, type: .rook) // a8
            ],
            // b
            [
                ChessGame.Piece(player: .player1, type: .knight), // b1
                ChessGame.Piece(player: .player1, type: .pawn), // b2
                nil, // b3
                nil, // b4
                nil, // b5
                nil, // b6
                ChessGame.Piece(player: .player2, type: .pawn), // b7
                ChessGame.Piece(player: .player2, type: .knight) // b8
            ],
            // c
            [
                ChessGame.Piece(player: .player1, type: .bishop), // c1
                ChessGame.Piece(player: .player1, type: .pawn), // c2
                nil, // c3
                nil, // c4
                nil, // c5
                nil, // c6
                ChessGame.Piece(player: .player2, type: .pawn), // c7
                ChessGame.Piece(player: .player2, type: .bishop) // c8
            ],
            // d
            [
                ChessGame.Piece(player: .player1, type: .queen), // d1
                ChessGame.Piece(player: .player1, type: .pawn), // d2
                nil, // d3
                nil, // d4
                nil, // d5
                nil, // d6
                ChessGame.Piece(player: .player2, type: .pawn), // d7
                ChessGame.Piece(player: .player2, type: .queen) // d8
            ],
            // e
            [
                ChessGame.Piece(player: .player1, type: .king), // e1
                ChessGame.Piece(player: .player1, type: .pawn), // e2
                nil, // e3
                nil, // e4
                nil, // e5
                nil, // e6
                ChessGame.Piece(player: .player2, type: .pawn), // e7
                ChessGame.Piece(player: .player2, type: .king) // e8
            ],
            // f
            [
                ChessGame.Piece(player: .player1, type: .bishop), // f1
                ChessGame.Piece(player: .player1, type: .pawn), // f2
                nil, // f3
                nil, // f4
                nil, // f5
                nil, // f6
                ChessGame.Piece(player: .player2, type: .pawn), // f7
                ChessGame.Piece(player: .player2, type: .bishop) // f8
            ],
            // g
            [
                ChessGame.Piece(player: .player1, type: .knight), // g1
                ChessGame.Piece(player: .player1, type: .pawn), // g2
                nil, // g3
                nil, // g4
                nil, // g5
                nil, // g6
                ChessGame.Piece(player: .player2, type: .pawn), // g7
                ChessGame.Piece(player: .player2, type: .knight) // g8
            ],
            // h
            [
                ChessGame.Piece(player: .player1, type: .rook), // h1
                ChessGame.Piece(player: .player1, type: .pawn), // h2
                nil, // h3
                nil, // h4
                nil, // h5
                nil, // h6
                ChessGame.Piece(player: .player2, type: .pawn), // h7
                ChessGame.Piece(player: .player2, type: .rook) // h8
            ]
        ]
}
