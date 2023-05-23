/*
See LICENSE folder for this sample’s licensing information.

Abstract:
MatchStates
*/

import Foundation
import RealityKit

/// Defines states game can be in
/// States are defined as functions that return GameStates<Input, Output>.State objects
/// These objects handle Input events (concrete type for Match is MatchInput)
/// and generate GameStates<Input, Output>.StateOutput? events
class MatchStates {
    
    /// internal collection of states to run while we are positioning players in beams of light
    var positionPlayers: PositionPlayers?
    
    /// state machine, we start with initial rule PositionPlayers.startPositioning
    var rules: GameStates<MatchInput, MatchOutput>
    
    var scene: Scene
    var mode: GameMode
    var matchTimer: MatchTimer
    var matchTime: CountdownTime
    var isFirstRun = true
    var gameTeamStatus: GameTeamStatus

    init(scene: Scene, mode: GameMode) {
        rules = GameStates()
        self.scene = scene
        self.mode = mode
        self.matchTimer = MatchTimer()
        self.matchTime = CountdownTime()
        self.gameTeamStatus = GameTeamStatus(twoPlayer: mode != .solo)
        let positioning = PositionPlayers(scene: scene, mode: mode, exit: playersPositioned())
        rules.initial(positioning.startPositioning(status: gameTeamStatus))
        positionPlayers = positioning
    }

    /// Called as exit state of positionPlayers,
    /// if positionPlayers sent this state as next, it will take gameTeamStatus and set teams to PlayerTeamEntity in scene
    /// if this is first run it will send event showField and transition into waitForCourt state
    /// otherwise sends readyForBallDrop and transitions to waitForBallDrop
    func playersPositioned() -> GameStates<MatchInput, MatchOutput>.State {
        return .init("playersPositioned") { [weak self] _ in
            guard let self = self else { return nil }
            if let positionPlayers = self.positionPlayers {
                self.gameTeamStatus = positionPlayers.gameTeamStatus
                PlayerTeamEntity.setTeamsIfNotSet(scene: self.scene, status: &self.gameTeamStatus)
                self.gameTeamStatus.lock()
            }
            self.positionPlayers = nil
            if self.isFirstRun {
                return GameStates<MatchInput, MatchOutput>.StateOutput(outputEvent: .showField,
                                                                       nextState: self.waitForCourt())
            } else {
                return GameStates<MatchInput, MatchOutput>.StateOutput(outputEvent: .readyForBallDrop,
                                                                       nextState: self.waitForBallDrop())
            }

        }
    }
    
    /// Waits for animationEnded .courtReady event, sends readyForBallDrop event and transitions into waitForBallDrop state
    /// - Tag: WaitForCourt
    func waitForCourt() -> GameStates<MatchInput, MatchOutput>.State {
        return .init("showCourt") { [weak self] input in
            guard let self = self else { return nil }
            if case MatchInput.animationEnded(.courtReady) = input {
                self.isFirstRun = false
                return GameStates<MatchInput, MatchOutput>.StateOutput(outputEvent: .readyForBallDrop,
                                                                       nextState: self.waitForBallDrop())
            }
            return nil
        }
    }

    /// Waits for animationEnded .ballDrop event, sends matchStarted event and transitions into playingTheGame state
    func waitForBallDrop() -> GameStates<MatchInput, MatchOutput>.State {
        return .init("waiting for ball drop") { [weak self] input in
            guard let self = self else { return nil }
            if case MatchInput.animationEnded(.ballDrop) = input {
                self.matchTime = CountdownTime()
                if UserSettings.enableMatchDuration {
                    self.matchTimer.start(withSeconds: UserSettings.matchDuration)
                    self.matchTime = self.matchTimer.range
                }
                return GameStates.StateOutput(outputEvent: .matchStarted(score: self.currentScore, matchTime: self.matchTime),
                                              nextState: self.playingTheGame())
            }
            return nil
        }
    }

    var currentScore: MatchScore = .starting

    /// actual state game machine is in during the game
    /// possible transition states:
    /// * resetPins on ballInGutter forceBallInGutter inputs with ballOutOfPlay output event
    /// * matchFinished with matchWonBy output event on various game ending input events
    /// * self with matchStarted event containing score and current time
    func playingTheGame() -> GameStates<MatchInput, MatchOutput>.State {
        return .init("playing the game") { [weak self] input in
            guard let self = self else { return nil }
            switch input {
            case let .pinUpdate(team, mask):
                switch team {
                case .teamA: self.currentScore.teamA = mask
                case .teamB: self.currentScore.teamB = mask
                case .none: break
                }
                return .init(outputEvent: .matchStarted(score: self.currentScore, matchTime: self.matchTime), nextState: self.playingTheGame())
            case .ballInGutter, .forceBallInGutter:
                return .init(outputEvent: .ballOutOfPlay, nextState: self.resetPins())
            case .allPinsDown(let team):
                return .init(outputEvent: .matchWonBy(team.opponent), nextState: self.matchFinished())
            case .forceEndSelected:
                let winner = self.currentScore.winner
                return .init(outputEvent: .matchWonBy(winner), nextState: self.matchFinished())
            case .sceneUpdate where UserSettings.enableMatchDuration:
                let gameOver = !self.matchTimer.tick()
                if gameOver {
                    let winner = self.currentScore.winner
                    return .init(outputEvent: .matchWonBy(winner), nextState: self.matchFinished())
                }
                // match time range will change because of host performance delays or breakpoint debugging on host
                if self.matchTimer.rangeChanged {
                    self.matchTime = self.matchTimer.range
                    return .init(outputEvent: .matchStarted(score: self.currentScore, matchTime: self.matchTime),
                                 nextState: self.playingTheGame())
                }
                return nil
            default:
                return nil
            }
        }
    }

    /// resets pins and either ends the game by sending matchWonBy event and transitioning to matchFinished
    /// or triggers another positioning state by sending positioningStarted event and transitioning to startPositioning
    func resetPins() -> GameStates<MatchInput, MatchOutput>.State {
        return .init("resetting pins") { [weak self] input in
            guard let self = self else { return nil }
            switch input {
            case .forceEndSelected:
                let winner = self.currentScore.winner
                return .init(outputEvent: .matchWonBy(winner), nextState: self.matchFinished())
            case .animationEnded(let animation) where animation == .resetPins:
                let positionPlayers = PositionPlayers(scene: self.scene, mode: self.mode, exit: self.playersPositioned())
                self.positionPlayers = positionPlayers
                return .init(outputEvent: .positioningStarted, nextState: positionPlayers.startPositioning(status: self.gameTeamStatus))
            default:
            return nil
            }
        }
    }
    
    /// Final game state, will never exit this one
    func matchFinished() -> GameStates<MatchInput, MatchOutput>.State {
        return .init("match finished") { _ in
            return nil
        }
    }
}
