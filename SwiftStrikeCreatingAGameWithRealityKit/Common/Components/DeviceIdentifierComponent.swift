/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Device Identifier Component
*/

import Foundation
import RealityKit
import UIKit

/// IdentifierComponent
/// Use this component to add a device specific identifier to any Entity.
/// Useful for creating entities on a device that may not be a host in a
/// networked application.
struct DeviceIdentifierComponent: Component {

    private static var deviceIdentifier: UUID = {
        // if for some reason the UIDevice.current.identifierForVendor
        // property failed to provide a valid UUID, then create a random
        // one for reuse on this device
        UIDevice.current.identifierForVendor ?? UUID()
    }()

    let identifier: UUID

    init(_ id: UUID? = nil) {
        identifier = id ?? DeviceIdentifierComponent.deviceIdentifier
    }

}

extension DeviceIdentifierComponent: Codable {}

protocol HasDeviceIdentifier where Self: Entity {}

extension HasDeviceIdentifier {

    var deviceIdentifier: DeviceIdentifierComponent {
        get { return components[DeviceIdentifierComponent.self] ?? DeviceIdentifierComponent() }
        set { components[DeviceIdentifierComponent.self] = newValue }
    }

    var deviceUUID: UUID {
        return deviceIdentifier.identifier
    }

}
