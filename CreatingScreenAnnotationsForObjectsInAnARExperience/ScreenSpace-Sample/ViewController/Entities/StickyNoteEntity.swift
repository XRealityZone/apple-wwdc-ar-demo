/*
See LICENSE folder for this sample’s licensing information.

Abstract:
An entity used to house the AR screen space annotation.
*/

import ARKit
import RealityKit

/// An Entity which has an anchoring component and a screen space view component, where the screen space view is a StickyNoteView.
class StickyNoteEntity: Entity, HasAnchoring, HasScreenSpaceView {
    // ...

    var screenSpaceComponent = ScreenSpaceComponent()
    
    /// Initializes a new StickyNoteEntity and assigns the specified transform.
    /// Also automatically initializes an associated StickyNoteView with the specified frame.
    init(frame: CGRect, worldTransform: simd_float4x4) {
        super.init()
        self.transform.matrix = worldTransform
        // ...
        screenSpaceComponent.view = StickyNoteView(frame: frame, note: self)
    }
    required init() {
        fatalError("init() has not been implemented")
    }
}
