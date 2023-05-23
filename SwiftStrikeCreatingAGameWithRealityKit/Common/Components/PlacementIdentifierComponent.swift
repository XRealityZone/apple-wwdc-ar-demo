/*
See LICENSE folder for this sample’s licensing information.

Abstract:
PlacementIdentifierComponent
*/

import RealityKit

/// This component contains the configuraion for any object in game that
/// requires team and identifier (like Pins in SwiftStrike which are related to
/// a Team, and have a position (identifier) 1-10, or the beams of light which
/// have a Team, but the identifier is not used (0).
struct PlacementIdentifierComponent: Component {
    var team: Team = .none
    var identifier: Int = 0
}

extension PlacementIdentifierComponent: Codable {}

protocol HasPlacementIdentifier where Self: Entity {}

extension HasPlacementIdentifier {

    var placementIdentifier: PlacementIdentifierComponent {
        get { return components[PlacementIdentifierComponent.self] ?? PlacementIdentifierComponent() }
        set { components[PlacementIdentifierComponent.self] = newValue }
    }

    var placementTeam: Team {
        get { return placementIdentifier.team }
        set { placementIdentifier.team = newValue }
    }

    var placementID: Int {
        get { return placementIdentifier.identifier }
        set { placementIdentifier.identifier = newValue }
    }

}
