/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Unit tests.
*/

// Sample game from: https://www.chessgames.com/perl/chessgame?gid=1233404
let sampleGame1Moves: [ChessGame.Move] = [
    // e4 e5
    ChessGame.Move(from: ChessGame.Coordinate(x: 4, y: 1), to: ChessGame.Coordinate(x: 4, y: 3)),
    ChessGame.Move(from: ChessGame.Coordinate(x: 4, y: 6), to: ChessGame.Coordinate(x: 4, y: 4)),
    
    // Nf3 d6
    ChessGame.Move(from: ChessGame.Coordinate(x: 6, y: 0), to: ChessGame.Coordinate(x: 5, y: 2)),
    ChessGame.Move(from: ChessGame.Coordinate(x: 3, y: 6), to: ChessGame.Coordinate(x: 3, y: 5)),
    
    // d4 Bg4
    ChessGame.Move(from: ChessGame.Coordinate(x: 3, y: 1), to: ChessGame.Coordinate(x: 3, y: 3)),
    ChessGame.Move(from: ChessGame.Coordinate(x: 2, y: 7), to: ChessGame.Coordinate(x: 6, y: 3)),
    
    // d4xe5 Bxf3
    ChessGame.Move(from: ChessGame.Coordinate(x: 3, y: 3), to: ChessGame.Coordinate(x: 4, y: 4)),
    ChessGame.Move(from: ChessGame.Coordinate(x: 6, y: 3), to: ChessGame.Coordinate(x: 5, y: 2)),
    
    // Qxf3 d5xe5
    ChessGame.Move(from: ChessGame.Coordinate(x: 3, y: 0), to: ChessGame.Coordinate(x: 5, y: 2)),
    ChessGame.Move(from: ChessGame.Coordinate(x: 3, y: 5), to: ChessGame.Coordinate(x: 4, y: 4)),
    
    // Bc4 Nf6
    ChessGame.Move(from: ChessGame.Coordinate(x: 5, y: 0), to: ChessGame.Coordinate(x: 2, y: 3)),
    ChessGame.Move(from: ChessGame.Coordinate(x: 6, y: 7), to: ChessGame.Coordinate(x: 5, y: 5)),
    
    // Qb3 Qe7
    ChessGame.Move(from: ChessGame.Coordinate(x: 5, y: 2), to: ChessGame.Coordinate(x: 1, y: 2)),
    ChessGame.Move(from: ChessGame.Coordinate(x: 3, y: 7), to: ChessGame.Coordinate(x: 4, y: 6)),
    
    // Nc3 c6
    ChessGame.Move(from: ChessGame.Coordinate(x: 1, y: 0), to: ChessGame.Coordinate(x: 2, y: 2)),
    ChessGame.Move(from: ChessGame.Coordinate(x: 2, y: 6), to: ChessGame.Coordinate(x: 2, y: 5)),
    
    // Bg5 b5
    ChessGame.Move(from: ChessGame.Coordinate(x: 2, y: 0), to: ChessGame.Coordinate(x: 6, y: 4)),
    ChessGame.Move(from: ChessGame.Coordinate(x: 1, y: 6), to: ChessGame.Coordinate(x: 1, y: 4)),
    
    // Nxb5 c6xb5
    ChessGame.Move(from: ChessGame.Coordinate(x: 2, y: 2), to: ChessGame.Coordinate(x: 1, y: 4)),
    ChessGame.Move(from: ChessGame.Coordinate(x: 2, y: 5), to: ChessGame.Coordinate(x: 1, y: 4)),
    
    // Bxb5+ Nd7
    ChessGame.Move(from: ChessGame.Coordinate(x: 2, y: 3), to: ChessGame.Coordinate(x: 1, y: 4)), // Check
    ChessGame.Move(from: ChessGame.Coordinate(x: 1, y: 7), to: ChessGame.Coordinate(x: 3, y: 6)),
    
    // 0-0-0 Rd8
    ChessGame.Move(from: ChessGame.Coordinate(x: 4, y: 0), to: ChessGame.Coordinate(x: 2, y: 0)),
    ChessGame.Move(from: ChessGame.Coordinate(x: 0, y: 7), to: ChessGame.Coordinate(x: 3, y: 7)),
    
    // Rxd7 Rxd7
    ChessGame.Move(from: ChessGame.Coordinate(x: 3, y: 0), to: ChessGame.Coordinate(x: 3, y: 6)),
    ChessGame.Move(from: ChessGame.Coordinate(x: 3, y: 7), to: ChessGame.Coordinate(x: 3, y: 6)),
    
    // Rd1 Qe6
    ChessGame.Move(from: ChessGame.Coordinate(x: 7, y: 0), to: ChessGame.Coordinate(x: 3, y: 0)),
    ChessGame.Move(from: ChessGame.Coordinate(x: 4, y: 6), to: ChessGame.Coordinate(x: 4, y: 5)),
    
    // Bxd7+ Nxd7
    ChessGame.Move(from: ChessGame.Coordinate(x: 1, y: 4), to: ChessGame.Coordinate(x: 3, y: 6)), // Check
    ChessGame.Move(from: ChessGame.Coordinate(x: 5, y: 5), to: ChessGame.Coordinate(x: 3, y: 6)),
    
    // Qb8+ Nxb8
    ChessGame.Move(from: ChessGame.Coordinate(x: 1, y: 2), to: ChessGame.Coordinate(x: 1, y: 7)), // Check
    ChessGame.Move(from: ChessGame.Coordinate(x: 3, y: 6), to: ChessGame.Coordinate(x: 1, y: 7)),
    
    // Rd8#
    ChessGame.Move(from: ChessGame.Coordinate(x: 3, y: 0), to: ChessGame.Coordinate(x: 3, y: 7)) // Checkmate
]

// Sample game from, https://www.chessgames.com/perl/chessgame?gid=1257910
let sampleGame2Moves: [ChessGame.Move] = [
    // e4e 5
    ChessGame.Move(from: ChessGame.Coordinate(x: 4, y: 1), to: ChessGame.Coordinate(x: 4, y: 3)),
    ChessGame.Move(from: ChessGame.Coordinate(x: 4, y: 6), to: ChessGame.Coordinate(x: 4, y: 4)),
    
    // Nf3 Nc6
    ChessGame.Move(from: ChessGame.Coordinate(x: 6, y: 0), to: ChessGame.Coordinate(x: 5, y: 2)),
    ChessGame.Move(from: ChessGame.Coordinate(x: 1, y: 7), to: ChessGame.Coordinate(x: 2, y: 5)),
    
    // Bc4 Bc5
    ChessGame.Move(from: ChessGame.Coordinate(x: 5, y: 0), to: ChessGame.Coordinate(x: 2, y: 3)),
    ChessGame.Move(from: ChessGame.Coordinate(x: 5, y: 7), to: ChessGame.Coordinate(x: 2, y: 4)),
    
    // c3 Nf6
    ChessGame.Move(from: ChessGame.Coordinate(x: 2, y: 1), to: ChessGame.Coordinate(x: 2, y: 2)),
    ChessGame.Move(from: ChessGame.Coordinate(x: 6, y: 7), to: ChessGame.Coordinate(x: 5, y: 5)),
    
    // d4 e5xd4
    ChessGame.Move(from: ChessGame.Coordinate(x: 3, y: 1), to: ChessGame.Coordinate(x: 3, y: 3)),
    ChessGame.Move(from: ChessGame.Coordinate(x: 4, y: 4), to: ChessGame.Coordinate(x: 3, y: 3)),
    
    // e5 Ne4
    ChessGame.Move(from: ChessGame.Coordinate(x: 4, y: 3), to: ChessGame.Coordinate(x: 4, y: 4)),
    ChessGame.Move(from: ChessGame.Coordinate(x: 5, y: 5), to: ChessGame.Coordinate(x: 4, y: 3)),
    
    // Bd5 Nxf2
    ChessGame.Move(from: ChessGame.Coordinate(x: 2, y: 3), to: ChessGame.Coordinate(x: 3, y: 4)),
    ChessGame.Move(from: ChessGame.Coordinate(x: 4, y: 3), to: ChessGame.Coordinate(x: 5, y: 1)),
    
    // Kxf2 dxc3+
    ChessGame.Move(from: ChessGame.Coordinate(x: 4, y: 0), to: ChessGame.Coordinate(x: 5, y: 1)),
    ChessGame.Move(from: ChessGame.Coordinate(x: 3, y: 3), to: ChessGame.Coordinate(x: 2, y: 2)), // Check
    
    // Kg3 cxb2
    ChessGame.Move(from: ChessGame.Coordinate(x: 5, y: 1), to: ChessGame.Coordinate(x: 6, y: 2)),
    ChessGame.Move(from: ChessGame.Coordinate(x: 2, y: 2), to: ChessGame.Coordinate(x: 1, y: 1)),
    
    // Bxb2 Ne7
    ChessGame.Move(from: ChessGame.Coordinate(x: 2, y: 0), to: ChessGame.Coordinate(x: 1, y: 1)),
    ChessGame.Move(from: ChessGame.Coordinate(x: 2, y: 5), to: ChessGame.Coordinate(x: 4, y: 6)),
    
    // Ng5 Nxd5
    ChessGame.Move(from: ChessGame.Coordinate(x: 5, y: 2), to: ChessGame.Coordinate(x: 6, y: 4)),
    ChessGame.Move(from: ChessGame.Coordinate(x: 4, y: 6), to: ChessGame.Coordinate(x: 3, y: 4)),
    
    // Nxf7 0-0
    ChessGame.Move(from: ChessGame.Coordinate(x: 6, y: 4), to: ChessGame.Coordinate(x: 5, y: 6)),
    ChessGame.Move(from: ChessGame.Coordinate(x: 4, y: 7), to: ChessGame.Coordinate(x: 6, y: 7)),
    
    // Nxd8 Bf2+
    ChessGame.Move(from: ChessGame.Coordinate(x: 5, y: 6), to: ChessGame.Coordinate(x: 3, y: 7)),
    ChessGame.Move(from: ChessGame.Coordinate(x: 2, y: 4), to: ChessGame.Coordinate(x: 5, y: 1)), // Check
    
    // Kh3 d6+
    ChessGame.Move(from: ChessGame.Coordinate(x: 6, y: 2), to: ChessGame.Coordinate(x: 7, y: 2)),
    ChessGame.Move(from: ChessGame.Coordinate(x: 3, y: 6), to: ChessGame.Coordinate(x: 3, y: 5)), // Check
    
    // e6 Nf4+
    ChessGame.Move(from: ChessGame.Coordinate(x: 4, y: 4), to: ChessGame.Coordinate(x: 4, y: 5)),
    ChessGame.Move(from: ChessGame.Coordinate(x: 3, y: 4), to: ChessGame.Coordinate(x: 5, y: 3)), // Check
    
    // Kg4 Nxe6
    ChessGame.Move(from: ChessGame.Coordinate(x: 7, y: 2), to: ChessGame.Coordinate(x: 6, y: 3)),
    ChessGame.Move(from: ChessGame.Coordinate(x: 5, y: 3), to: ChessGame.Coordinate(x: 4, y: 5)),
    
    // Nxe6 Bxe6+
    ChessGame.Move(from: ChessGame.Coordinate(x: 3, y: 7), to: ChessGame.Coordinate(x: 4, y: 5)),
    ChessGame.Move(from: ChessGame.Coordinate(x: 2, y: 7), to: ChessGame.Coordinate(x: 4, y: 5)), // Check
    
    // Kg5 Rf5+
    ChessGame.Move(from: ChessGame.Coordinate(x: 6, y: 3), to: ChessGame.Coordinate(x: 6, y: 4)),
    ChessGame.Move(from: ChessGame.Coordinate(x: 5, y: 7), to: ChessGame.Coordinate(x: 5, y: 4)), // Check
    
    // Kg4 h5+
    ChessGame.Move(from: ChessGame.Coordinate(x: 6, y: 4), to: ChessGame.Coordinate(x: 6, y: 3)),
    ChessGame.Move(from: ChessGame.Coordinate(x: 7, y: 6), to: ChessGame.Coordinate(x: 7, y: 4)), // Check
    
    // Kh3 Rf3#
    ChessGame.Move(from: ChessGame.Coordinate(x: 6, y: 3), to: ChessGame.Coordinate(x: 7, y: 2)),
    ChessGame.Move(from: ChessGame.Coordinate(x: 5, y: 4), to: ChessGame.Coordinate(x: 5, y: 2))
]
