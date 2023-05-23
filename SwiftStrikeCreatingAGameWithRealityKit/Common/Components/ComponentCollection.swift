/*
See LICENSE folder for this sample’s licensing information.

Abstract:
ComponentCollection
*/

import RealityKit

enum ComponentCollection {
    // Registers all Game framework components, as well as any custom components
    // provided by a user of the framework.
    // Should be called before any RealityKit objects are instantiated, such
    // as from the app delegate's application(_:didFinishLaunchingWithOptions:)
    // method.
    static func registerComponents(_ appComponents: [Component.Type]) {
        let components: [Component.Type] = [
            //
            // Please keep in alphabetical order since this
            // reduces merge conflicts
            //
            CameraBillboardComponent.self,
            ChildEntitySwitchComponent.self,
            CollisionSizeComponent.self,
            DeviceIdentifierComponent.self,
            FloorBillboardComponent.self,
            GameAudioComponent.self,
            GameAudioStateComponent.self,
            KinematicVelocityComponent.self,
            OffScreenTrackingComponent.self,
            PlacementIdentifierComponent.self,
            PlayerTeamComponent.self,
            RadiatingForceFieldComponent.self,
            RemoteVelocityComponent.self,
            StandUprightComponent.self,
            TransformMemoryComponent.self,
            TriggerComponent.self,
            UprightStatusComponent.self,
            YAxisBillboardComponent.self
        ]

        (components + appComponents).forEach { (type) in
            type.registerComponent()
            Entity.customComponents.append(type)
        }
    }
}
