/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Unit tests.
*/

import XCTest

final class CaptureChessTests: XCTestCase {

    func testSampleGame1() throws {
        var game = ChessGame()
        var player: ChessGame.Player = .player1
        
        for i in (0..<sampleGame1Moves.count) {
            let move = sampleGame1Moves[i]
            XCTAssert(game.validateMove(move), "Failed with move: \(move)")
            game.makeMove(move)
            player.toggle()
            if [20, 28, 30].contains(i) {
                XCTAssert(game.isInCheck(for: player))
            }
        }
        
        XCTAssert(game.isInCheckmate(for: player))
    }
    
    func testSampleGame2() throws {
        var game = ChessGame()
        var player: ChessGame.Player = .player1
        
        for i in (0..<sampleGame2Moves.count) {
            let move = sampleGame2Moves[i]
            XCTAssert(game.validateMove(move), "Failed with move: \(move)")
            game.makeMove(move)
            player.toggle()
            if [15, 25, 27, 29, 33, 35, 37].contains(i) {
                XCTAssert(game.isInCheck(for: player))
            }
        }
        
        XCTAssert(game.isInCheckmate(for: player))
    }

}
