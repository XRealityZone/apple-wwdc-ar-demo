/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The game's main view.
*/

import SwiftUI

struct ContentView: View {
    
    @ObservedObject var gameManager = GameManager.shared
    
    var body: some View {
        ZStack {
            ARViewContainer(gameManager: gameManager)
                .edgesIgnoringSafeArea(.all)
                .zIndex(0)
            
            if gameManager.state == .splash {
                SplashScreenView(gameManager: gameManager)
                    .background(.ultraThinMaterial)
                    .transition(.opacity)
                    .zIndex(1)
            } else {
                OverlayView(gameManager: gameManager)
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
    }
}

struct OverlayView: View {
    
    @Environment(\.colorScheme) var colorScheme
    
    @ObservedObject var gameManager: GameManager
    
    var body: some View {
        Group {
            if !gameManager.state.done {
                VStack {
                    Text(gameManager.turn.name + "'s Turn")
                        .padding()
                        .foregroundColor(gameManager.turn.fontColor)
                        .background(gameManager.turn.color)
                        .cornerRadius(10)
                    
                    Spacer()
                }
                .padding()
            } else {
                VStack {
                    if gameManager.state == .checkmate {
                        Text(gameManager.turn.name + " Wins!")
                            .padding()
                            .foregroundColor(gameManager.turn.fontColor)
                            .background(gameManager.turn.color)
                            .cornerRadius(10)
                    } else if gameManager.state == .stalemate {
                        Text("Draw!")
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(10)
                    }
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
