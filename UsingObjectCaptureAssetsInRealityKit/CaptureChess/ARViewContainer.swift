/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A SwiftUI view that contains an ARView.
*/

import RealityKit
import SwiftUI

struct ARViewContainer: UIViewRepresentable {
    
    let gameManager: GameManager
    
    func makeUIView(context: Context) -> ChessViewport {
        ChessViewport(gameManager: gameManager)
    }
    
    func updateUIView(_ uiView: ChessViewport, context: Context) {}
}
