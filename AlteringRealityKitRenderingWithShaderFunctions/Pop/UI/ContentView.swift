/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The app's main SwiftUI view.
*/

import Foundation
import SwiftUI
import RealityKit
import MetalKit
import ARKit

@available(iOS 15.0, *)
struct ContentView: View {
    let maxTapDistance = CGFloat(10)
    var body: some View {
        let container = RealityViewContainer()
        container
            .edgesIgnoringSafeArea(.all)
            .overlay(
                ResetButton(title: "Reset",
                          logMessage: "User requested reset.")
                    
            )
            // In SwiftUI, a tap gesture doesn't return the tap location, so
            // use a drag gesture and only fire if the drag distance is less
            // than a specified threshold.
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onEnded { value in
                        let dragX = abs(value.location.x - value.startLocation.x)
                        let dragY = abs(value.location.y - value.startLocation.y)
                        if dragX < maxTapDistance && dragY < maxTapDistance {
                            ApplicationActions.shared.screenTapped(point: value.location)
                        }
                    }
            )
    }
}

#if DEBUG
@available(iOS 15.0, *)
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif

@available(iOS 15.0, *)
struct ResetButton: View {
    
    var title: String
    var logMessage: String?
    
    var body: some View {
        
        Button(action: {
            if let message = logMessage {
                print(message)
            }
            ApplicationActions.shared.resetRobots()
        }) {
            Text(title)
                .fontWeight(.bold)
                .font(.title)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
                .foregroundColor(.white)
                .padding(30)
        }
        .position(x: 100, y: 60)
    }
}
