/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The game's splash screen.
*/
import SwiftUI


struct SplashScreenView: View {
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    @State var isStarted: Bool = false
    let gradients = Gradient(colors: [.yellow, .yellow.opacity(0)])
    
    @ObservedObject var gameManager: GameManager
    
    private var titleSize: CGFloat {
        horizontalSizeClass == .regular ? 84 : 50
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Rectangle()
                    .fill(RadialGradient(gradient: gradients, center: .center, startRadius: 5, endRadius: geometry.size.width / 2.0))
                    .opacity(isStarted ? 0 : 0.3)
                
                VStack {
                    Spacer()
                        .frame(height: 80)
                    HStack {
                        EmptyCircle()
                            .offset(x: isStarted ? -20.0 : 0.0)
                            .opacity(isStarted ? 0 : 1)
                        Spacer()
                        RectangleGrid()
                            .scaleEffect(isStarted ? 0.5 : 1)
                            .opacity(isStarted ? 0 : 1)
                        Spacer()
                        EmptyCircle()
                            .offset(x: isStarted ? 20.0 : 0.0)
                            .opacity(isStarted ? 0 : 1)
                    }
                    Spacer()
                        .frame(height: 48)
                    Text("capture chess")
                        .padding()
                        .font(.system(size: titleSize, weight: .regular))
                        .opacity(isStarted ? 0 : 1)
                    Spacer()
                        .frame(height: 48)
                    ZStack {
                        Rectangle()
                            .stroke(lineWidth: horizontalSizeClass == .regular ? 6 : 3)
                            .background(Color(.clear))
                            .frame(width: geometry.size.width / 2.0, height: geometry.size.width / 2.0)
                            .scaleEffect(isStarted ? 0.8 : 1)
                            .opacity(isStarted ? 0 : 1)
                            .rotation3DEffect(.degrees(isStarted ? 45: 0), axis: (x: 1, y: 0, z: 0))
                        Rectangle()
                            .frame(width: geometry.size.width / 1.3, height: 2)
                            .opacity(0.5)
                            .scaleEffect(isStarted ? 0.5 : 1)
                            .opacity(isStarted ? 0 : 1)
                    }
                    Spacer()
                    HStack {
                        EmptyCircle()
                            .offset(x: isStarted ? -20.0 : 0.0)
                            .opacity(isStarted ? 0 : 1)
                        Spacer()
                        Button(action: {
                            isStarted = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation {
                                    gameManager.state = .playing
                                }
                            }
                        }) {
                            Text("START")
                                .padding(32)
                                .frame(height: 60)
                                .foregroundColor(.black)
                                .font(.headline)
                                .background(colorScheme == .light ? .yellow: .blue)
                        }
                        .opacity(isStarted || !gameManager.okayToStart ? 0 : 1)
                        Spacer()
                        EmptyCircle()
                            .offset(x: isStarted ? 20.0 : 0.0)
                            .opacity(isStarted ? 0 : 1)
                    }
                    Spacer()
                        .frame(height: 20)
                    ProgressView(value: gameManager.loadProgress) {
                        Text("Loading assets (\(gameManager.piecesLoaded) of \(ChessPieceData.data.count))...")
                            .multilineTextAlignment(.center)
                            .frame(alignment: .center)
                    }
                    .frame(alignment:.top)
                    .padding()
                    .opacity(gameManager.okayToStart ? 0 : 1)
                    
                }
                .padding(horizontalSizeClass == .regular ? 64 : 20)
                
                Image(colorScheme == .light ? "WoodenKingLight" : "WoodenKingDark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width / 1.5)
                    .scaleEffect(isStarted ? 0.9 : 1)
                    .opacity(isStarted ? 0 : 1)
            }
        }
        .ignoresSafeArea()
        .animation(.spring(response: 1.5), value: isStarted)
    }
}

struct RectangleGrid: View {
    var body: some View {
        VStack {
            RectangleRow()
            RectangleRow()
        }
    }
}

struct RectangleRow: View {
    var body: some View {
        HStack {
            ForEach((1...8), id: \.self) { rectgroup in
                Rectangle()
                    .frame(width: 8, height: 8)
            }
        }
        .opacity(0.7)
    }
}

private struct EmptyCircle: View {
    var body: some View {
        Circle()
            .stroke(lineWidth: 2)
            .opacity(0.5)
            .background(Color(.clear))
            .frame(width: 10, height: 10)
    }
}

struct SplashScreenView_Preview: PreviewProvider {
    static var previews: some View {
        SplashScreenView(gameManager: GameManager.shared)
            .previewDevice(PreviewDevice(rawValue: "iPhone 13"))
        
        SplashScreenView(gameManager: GameManager.shared)
            .previewDevice(PreviewDevice(rawValue: "iPad Pro (10.5-inch)"))
    }
}

