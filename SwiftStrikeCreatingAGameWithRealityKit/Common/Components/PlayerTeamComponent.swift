/*
See LICENSE folder for this sample’s licensing information.

Abstract:
PlayerTeamComponent
*/

import Foundation
import os.log
import RealityKit

/// Records the team for the associated player entity
struct PlayerTeamComponent: Component {

    var team: Team {
        didSet {
            self.timestamp = Date()
        }
    }

    // not encoded/decoded
    var timestamp: Date

    init() {
        self.team = .none
        self.timestamp = Date.distantPast
        os_log(.default, log: GameLog.general, "PlayerTeamComponent created...")
    }

}

extension PlayerTeamComponent: Codable {

    enum CodingKeys: CodingKey {
        case team
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.team = try container.decode(Team.self, forKey: .team)
        self.timestamp = Date()

        // debug only...
        let newTeam = self.team
        #if DEBUG
        DispatchQueue.main.async {
            os_log(.default, log: GameLog.general, "PlayerTeamComponent new team '%s' from network", "\(newTeam)")
        }
        #endif
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(team, forKey: .team)
    }

}

extension PlayerTeamComponent: WatchedComponent {}

protocol HasPlayerTeam where Self: Entity {}

extension HasPlayerTeam {

    var playerTeam: PlayerTeamComponent {
        get { return components[PlayerTeamComponent.self] ?? PlayerTeamComponent() }
        set { components[PlayerTeamComponent.self] = newValue }
    }

    var onTeam: Team {
        get { return playerTeam.team }
        set { playerTeam.team = newValue }
    }

}
