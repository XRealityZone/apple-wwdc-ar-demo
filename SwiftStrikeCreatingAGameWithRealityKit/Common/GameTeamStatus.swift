/*
See LICENSE folder for this sample’s licensing information.

Abstract:
GameReadyData
*/

import Foundation
import os.log

extension GameLog {
    static let teamStatus = OSLog(subsystem: subsystem, category: "teamStatus")
}

struct GameTeamStatus: Codable, Equatable {

    static let badState = "GameTeamStatus somehow got whacked - bad internal state"

    static func == (lhs: GameTeamStatus, rhs: GameTeamStatus) -> Bool {
        return lhs.gameReadyCount == rhs.gameReadyCount
        && lhs.gameTeamCount == rhs.gameTeamCount
        && lhs.gameReady == rhs.gameReady
        && lhs.gameTeam == rhs.gameTeam
    }

    private var twoPlayer: Bool = false

    private var gameReadyCount: Int = 0
    private var gameTeamsReadyCount: Int = 0
    private var gameTeamCount: Int = 0
    private var locked: Bool = false

    private var gameReady: [Team: [UUID]] = [:]
    private var gameTeam: [Team: [UUID]] = [:]

    private static let playersPerTeamMax = 1
    private static let playersPerReadyMax = 2

    var readyCount: Int { return gameReadyCount }
    var teamsReadyCount: Int { return gameTeamsReadyCount }
    var teamCount: Int { return gameTeamCount }

    init(twoPlayer: Bool) {
        self.twoPlayer = twoPlayer
        self.gameReady = [:]
        self.gameReady[.none] = []
        self.gameReady[.teamA] = []
        self.gameReady[.teamB] = []
        self.gameReadyCount = 0
        self.gameTeamsReadyCount = 0
        self.gameTeam = [:]
        self.gameTeam[.none] = []
        self.gameTeam[.teamA] = []
        self.gameTeam[.teamB] = []
        self.gameTeamCount = 0
    }

    mutating func lock() {
        locked = true
    }

    private func findTeam(for id: UUID, in list: [Team: [UUID]]) -> Team {
        for (team, idList) in list {
            if idList.contains(id) {
                return team
            }
        }
        return .none
    }

    func playerTeam(_ id: UUID) -> Team {
        return findTeam(for: id, in: gameTeam)
    }

    func playerReady(_ id: UUID) -> Team {
        return findTeam(for: id, in: gameReady)
    }

    func readyToStartCount() -> Int {
        var count = 0

        // count the # of teams that are ready in the proper team slot
        // loop through teams that are marked ready
        for (currentReadyTeam, idList) in gameReady where currentReadyTeam != .none {
            for id in idList {
                // to make sure the id has the team that it is ready for
                let currentTeam = playerTeam(id)
                if currentReadyTeam == currentTeam {
                    count += 1
                }
            }
        }

        return count
    }

    mutating func newPlayerTeam(for id: UUID, _ newTeam: Team) -> Bool {
        guard !locked else {
            os_log(.default, log: GameLog.teamStatus, "ignoring attempt to set teams because locked!")
            return false
        }

        let currentTeam = playerTeam(id)
        guard gameTeam[currentTeam] != nil else {
            fatalError(GameTeamStatus.badState)
        }
        gameTeam[currentTeam]!.removeAll {
            if $0 == id {
                if currentTeam != .none {
                    gameTeamCount -= 1
                }
                return true
            }
            return false
        }

        guard let newTeamEntry = gameTeam[newTeam] else {
            fatalError(GameTeamStatus.badState)
        }
        guard newTeam != .none || newTeamEntry.count < GameTeamStatus.playersPerTeamMax else {
            assertionFailure(String(format: "GameReadyData.playerTeam() too many (%s) on team %s",
                                    "\(GameTeamStatus.playersPerTeamMax)", "\(newTeam)"))
            return false
        }

        gameTeam[newTeam]!.append(id)
        if newTeam != .none {
            gameTeamCount += 1
        }
        return true
    }

    mutating func newPlayerReady(for id: UUID, _ newTeam: Team) {
        let currentTeam = playerReady(id)
        guard gameReady[currentTeam] != nil else {
            fatalError(GameTeamStatus.badState)
        }

        let oldTeamReadyCount = gameReady[currentTeam]!.count
        gameReady[currentTeam]!.removeAll {
            if $0 == id {
                if currentTeam != .none {
                    gameReadyCount -= 1
                }
                return true
            }
            return false
        }
        if currentTeam != .none, gameReady[currentTeam]!.isEmpty, oldTeamReadyCount != 0 {
            gameTeamsReadyCount -= 1
        }

        guard let newReadyEntry = gameReady[newTeam] else {
            fatalError(GameTeamStatus.badState)
        }
        guard newReadyEntry.count < GameTeamStatus.playersPerReadyMax else {
            assertionFailure(String(format: "GameReadyData.playerReady() too many (%s) ready %s",
                                    "\(GameTeamStatus.playersPerReadyMax)", "\(newTeam)"))
            return
        }

        let wasTeamReady = !gameReady[newTeam]!.isEmpty
        gameReady[newTeam]!.append(id)
        if newTeam != .none {
            gameReadyCount += 1
        }
        if newTeam != .none, !wasTeamReady, gameReady[newTeam]!.count == 1 {
            gameTeamsReadyCount += 1
        }
    }

    func dump() {
        os_log(.default, log: GameLog.teamStatus, "--------------")
        os_log(.default, log: GameLog.teamStatus, "    teams ready = %s", "\(gameTeamsReadyCount)")
        os_log(.default, log: GameLog.teamStatus, "    ready to start = %s", "\(readyToStartCount())")

        os_log(.default, log: GameLog.teamStatus, "    total ready = %s", "\(gameReadyCount)")
        gameReady.forEach { (team, list) in
            os_log(.default, log: GameLog.teamStatus, "        %s: %s", "\(team)", "\(list)")
        }

        os_log(.default, log: GameLog.teamStatus, "    total teams = %s", "\(gameTeamCount)")
        gameTeam.forEach { (team, list) in
            os_log(.default, log: GameLog.teamStatus, "        %s: %s", "\(team)", "\(list)")
        }
        os_log(.default, log: GameLog.teamStatus, "--------------")
    }
}
