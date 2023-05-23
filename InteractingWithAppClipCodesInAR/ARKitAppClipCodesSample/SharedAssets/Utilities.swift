/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Utility functions for the sample app.
*/

import UIKit
import RealityKit
import ARKit
import Combine

///- Tag: GetProductKey
func getProductKey(from url: URL) -> String { return url.lastPathComponent }

func initializeUSDZ(urlForUSDZ: URL, initializationCompletionHandler: @escaping (Bool, Entity?) -> Void) {
    debugPrint("Initializing from \(urlForUSDZ)")
    // Important: load models only on the main thread.
    DispatchQueue.main.async {
        var cancellable: Cancellable? = nil
        cancellable = ModelEntity.loadModelAsync(contentsOf: urlForUSDZ)
            .sink(receiveCompletion: { completion in
                cancellable!.cancel()
                if case let .failure(error) = completion {
                    debugPrint("Unable to load a model due to error \(error)")
                    initializationCompletionHandler(false, nil)
                }
            }, receiveValue: { (model: ModelEntity) in
                cancellable!.cancel()
                initializationCompletionHandler(true, model)
            })
    }
}

extension UIView {
    func fillParentView() {
        if let parentView = superview {
            leadingAnchor.constraint(equalTo: parentView.leadingAnchor).isActive = true
            trailingAnchor.constraint(equalTo: parentView.trailingAnchor).isActive = true
            topAnchor.constraint(equalTo: parentView.topAnchor).isActive = true
            bottomAnchor.constraint(equalTo: parentView.bottomAnchor).isActive = true
        }
    }
    
    func lowerCenterInParentView() {
        if let parentView = superview {
            centerXAnchor.constraint(equalTo: parentView.centerXAnchor).isActive = true
            centerYAnchor.constraint(equalTo: parentView.centerYAnchor, constant: UIScreen.main.bounds.height / 4).isActive = true
        }
    }
}

extension Entity {
    func present(on parent: Entity) {
        
        /* The sunflower model's hardcoded scale.
        An app may wish to assign a unique scale value per App Clip Code model. */
        let finalScale = SIMD3<Float>.one * 5
        
        parent.addChild(self)
        // To display the model, initialize it at a small scale, then animate by transitioning to the original scale.
        self.move(
            to: Transform(
                scale: SIMD3<Float>.one * (1.0 / 1000),
                rotation: simd_quatf.init(angle: Float.pi, axis: SIMD3<Float>(x: 0, y: 1, z: 0))
            ),
            relativeTo: self
        )
        self.move(
            to: Transform(
                scale: finalScale,
                rotation: simd_quatf.init(angle: Float.pi, axis: SIMD3<Float>(x: 0, y: 1, z: 0))
            ),
            relativeTo: self,
            duration: 3
        )
    }
}
