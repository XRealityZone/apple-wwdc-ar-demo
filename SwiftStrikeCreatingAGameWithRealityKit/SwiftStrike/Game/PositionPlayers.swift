/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Position Players
*/

import Combine
import Foundation
import RealityKit

extension GameMode {
    var players: Int {
        switch self {
        case .solo: return 1
        default: return 2
        }
    }
}

/// Collection of GameStates that are used for positioning players in beam of light
class PositionPlayers {
    static let countDownTimerMax: Int = 3

    private var exit: GameStates<MatchInput, MatchOutput>.State
    private var scene: Scene
    private var mode: GameMode
    var gameTeamStatus: GameTeamStatus

    init(scene: Scene, mode: GameMode, exit: GameStates<MatchInput, MatchOutput>.State) {
        self.scene = scene
        self.mode = mode
        self.exit = exit
        self.gameTeamStatus = GameTeamStatus(twoPlayer: mode != .solo)
    }
    
    /// Starts game positioning, it either outputs positioningStarted staying in current state or if poritioning already started
    /// sends waitingForPlayersToStart event and transitions to waitForWalkIn
    func startPositioning(status gameTeamStatus: GameTeamStatus) -> GameStates<MatchInput, MatchOutput>.State {
        self.gameTeamStatus = gameTeamStatus
        var sentPositioningStarted = false
        return .init("startPositioning") { [weak self] _ in
            guard let self = self else { return nil }
            if !sentPositioningStarted {
                sentPositioningStarted = true
                return .init(outputEvent: .positioningStarted, nextState: nil)
            } else {
                let waitingForMax = self.mode.players
                return .init(outputEvent: .waitingForPlayersToStart(count: waitingForMax),
                             nextState: self.waitForWalkIn(data: WaitingForPlayers(readyCount: 0, waitingFor: waitingForMax)))
            }
        }
    }

    /// waits for startArea event, on it updates WaitingForPlayers data, and if we have both players in the beam we
    /// transition to countDown state, else we transition to waitForWalkIn with newly created data and continue waiting
    func waitForWalkIn(data: WaitingForPlayers) -> GameStates<MatchInput, MatchOutput>.State {
        return .init("waitForWalkIn waiting for \(data)") { [weak self] input in
            guard let self = self else { return nil }
            if case MatchInput.forceStartSelected = input {
                return .init(outputEvent: .positioningFinished, nextState: self.exit)
            }
            if let newData = data.newDataFor(event: input, scene: self.scene, status: &self.gameTeamStatus), newData != data {
                if newData.waitingFor == newData.readyCount {
                    return .init(outputEvent: .countingDownToStart(secondsRemaining: PositionPlayers.countDownTimerMax),
                                 nextState: self.countDown(data: .countingDown(Date(), PositionPlayers.countDownTimerMax)))
                } else {
                    return .init(outputEvent: newData.output,
                                 nextState: self.waitForWalkIn(data: newData))
                }
            }
            return nil
        }
    }
    
    /// if we get event that user exited the beam and new number of players in the beam is less than number of players, we
    /// transition back to waitForWalkIn state, otherwise we continue counting down untill we reach
    /// remainingTime 0 and we transition to exit state
    func countDown(data: CountingDown) -> GameStates<MatchInput, MatchOutput>.State {
        return .init("countDown \(data)") { [weak self] input in
            guard let self = self else { return nil }

            if case .startArea(let trigger, let id, let team, let ready) = input {
                if let playerTeamEntity = self.scene.playerTeamEntity(for: id) {
                    playerTeamEntity.updatePlayerReady(scene: self.scene, status: &self.gameTeamStatus, team: team, ready: ready)
                }
                if trigger == .ended {
                    let waitingForMax = self.mode.players
                    return .init(outputEvent: .waitingForPlayersToStart(count: 1),
                                 nextState: self.waitForWalkIn(data: WaitingForPlayers(readyCount: self.gameTeamStatus.readyToStartCount(),
                                                                                       waitingFor: waitingForMax)))
                }
            }

            if let newData = data.newDataFor(event: input), newData != data {
                switch newData {
                case .endPositioning:
                    return .init(outputEvent: .positioningFinished,
                                 nextState: self.exit)

                case .countingDown:
                    return .init(outputEvent: .countingDownToStart(secondsRemaining: newData.remainingTime),
                                 nextState: self.countDown(data: newData))
                }
            }
            return nil
        }
    }
}

struct WaitingForPlayers: Equatable {
    var readyCount: Int
    var waitingFor: Int

    init(readyCount: Int, waitingFor: Int) {
        self.readyCount = readyCount
        self.waitingFor = waitingFor
    }

    func newDataFor(event: MatchInput, scene: Scene, status gameTeamStatus: inout GameTeamStatus) -> WaitingForPlayers? {
        guard case .startArea(_, let id, let team, let ready) = event,
        let playerTeamEntity = scene.playerTeamEntity(for: id) else { return nil }
        playerTeamEntity.updatePlayerReady(scene: scene, status: &gameTeamStatus, team: team, ready: ready)
        return WaitingForPlayers(readyCount: gameTeamStatus.readyToStartCount(), waitingFor: waitingFor)
    }

    var output: MatchOutput {
        if waitingFor == readyCount {
            return .countingDownToStart(secondsRemaining: PositionPlayers.countDownTimerMax)
        } else {
            return .waitingForPlayersToStart(count: waitingFor - readyCount)
        }
    }
}

enum CountingDown {
    case endPositioning
    case countingDown(Date, Int)

    var remainingTime: Int {
        switch self {
        case let .countingDown(_, time):
            return time
        case .endPositioning:
            return 0
        }
    }

    var startDate: Date {
        switch self {
        case let .countingDown(date, _):
            return date
        case .endPositioning:
            return Date.distantPast
        }
    }

    func newDataFor(event: MatchInput) -> CountingDown? {
        if remainingTime == 0 {
            return .endPositioning
        } else if startDate.timeIntervalSinceNow < -1.0 {
            return .countingDown(Date(), remainingTime - 1)
        }
        return nil
    }

    var message: String? {
        return "Starting game in \(remainingTime)"
    }
}

extension CountingDown: Equatable {
    static func ==(lhs: CountingDown, rhs: CountingDown) -> Bool {
        switch (lhs, rhs) {
        case (.endPositioning, .endPositioning):
            return true
        case (.countingDown(let lhsTime, let lhsRemaining), .countingDown(let rhsTime, let rhsRemaining)):
            return lhsRemaining == rhsRemaining && lhsTime == rhsTime
        default:
            return false
        }
    }
}

