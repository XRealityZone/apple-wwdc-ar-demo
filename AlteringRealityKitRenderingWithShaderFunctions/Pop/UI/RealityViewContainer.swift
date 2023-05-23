/*
See LICENSE folder for this sample’s licensing information.

Abstract:
SwiftUI container view around RealityView.
*/

import Foundation
import SwiftUI
import RealityKit
import MetalKit
import ARKit

@available(iOS 15.0, *)
struct RealityViewContainer: UIViewRepresentable {
    
    public init() {
    }
    
    func makeUIView(context: Context) -> RealityView {
        let arView = RealityView(frame: .zero)
        arView.setup()
        context.coordinator.realityView = arView
        return arView
    }
    
    func updateUIView(_ view: RealityView, context: Context) {
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
    
    class Coordinator: NSObject {
        var realityView: RealityView?
        
        override init() {
        }
    }
}
