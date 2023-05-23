/*
See LICENSE folder for this sample’s licensing information.

Abstract:
OffScreenTrackingComponent
*/

import Foundation
import RealityKit
import UIKit

struct OffScreenTrackingComponent: Component {
    private(set) var identifier: UUID = UUID()
    var imageToken: String = ""
    var imageSize: CGFloat = 50
}

extension OffScreenTrackingComponent: Codable {}

protocol HasOffScreenTracking where Self: Entity {}

extension HasOffScreenTracking {
    var offScreenTracking: OffScreenTrackingComponent {
        get { return components[OffScreenTrackingComponent.self] ?? OffScreenTrackingComponent() }
        set { components[OffScreenTrackingComponent.self] = newValue }
    }
}
