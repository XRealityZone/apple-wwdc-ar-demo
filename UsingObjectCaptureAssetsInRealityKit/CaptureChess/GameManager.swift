/*
See LICENSE folder for this sample’s licensing information.

Abstract:
An object that manages a game.
*/

import RealityKit
import Combine
import SwiftUI

// MARK: - GameManager
class GameManager: ObservableObject {
    
    @Published var state: State = .splash
    
    @Published var turn: ChessGame.Player = .player1
    
    @Published var selectedPiece: ChessPiece?
    @Published var game: ChessGame = ChessGame()
    
    @Published var okayToStart = false
    @Published var loadProgress: Float = 0
    
    var piecesLoaded: Int8 = 0
    
    public func incrementPiecesLoaded() {
        piecesLoaded += 1
        loadProgress = Float(piecesLoaded) / Float(ChessPieceData.data.count)
        if piecesLoaded >= ChessPieceData.data.count {
            okayToStart = true
        }
        print("Pieces loaded: \(piecesLoaded), okayToStart: \(okayToStart)")
    }
    
    static let shared = GameManager()
    required init() {}
}

// MARK: - State
extension GameManager {
    enum State {
        case splash
        case playing
        case checkmate
        case stalemate
        
        var done: Bool {
            switch self {
            case .checkmate, .stalemate:
                return true
            default:
                return false
            }
        }
    }
}
