/*
See LICENSE folder for this sample’s licensing information.

Abstract:
MatchStateComponent
*/

import Foundation
import RealityKit

extension MatchOutput: Codable {
    enum CaseIdentifier: Int, Codable {
        case positioningStarted
        case positioningFinished

        case showField

        case waitingForPlayersToStart
        case countingDownToStart

        case readyForBallDrop
        case matchStarted
        case ballOutOfPlay

        case matchWonBy
    }

    enum CodingKeys: Int, CodingKey {
        case state
        case waitingCount
        case secondsRemaining
        case score
        case matchTime
        case team
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let caseIdentifier = try container.decode(CaseIdentifier.self, forKey: .state)
        switch caseIdentifier {
        case .positioningStarted:
            self = .positioningStarted
        case .positioningFinished:
            self = .positioningFinished
        case .showField:
            self = .showField
        case .waitingForPlayersToStart:
            let waitingCount = try container.decode(Int.self, forKey: .waitingCount)
            self = .waitingForPlayersToStart(count: waitingCount)
        case .countingDownToStart:
            let secondsRemaining = try container.decode(Int.self, forKey: .secondsRemaining)
            self = .countingDownToStart(secondsRemaining: secondsRemaining)
        case .readyForBallDrop:
            self = .readyForBallDrop
        case .matchStarted:
            let score = try container.decode(MatchScore.self, forKey: .score)
            let matchTime = try container.decode(CountdownTime.self, forKey: .matchTime)
            self = .matchStarted(score: score, matchTime: matchTime)
        case .ballOutOfPlay:
            self = .ballOutOfPlay
        case .matchWonBy:
            let team = try container.decode(Team.self, forKey: .team)
            self = .matchWonBy(team)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .positioningStarted:
            try container.encode(CaseIdentifier.positioningStarted, forKey: .state)
        case .positioningFinished:
            try container.encode(CaseIdentifier.positioningFinished, forKey: .state)
        case .showField:
            try container.encode(CaseIdentifier.showField, forKey: .state)
        case .waitingForPlayersToStart(count: let count):
            try container.encode(CaseIdentifier.waitingForPlayersToStart, forKey: .state)
            try container.encode(count, forKey: .waitingCount)
        case .countingDownToStart(let secondsRemaining):
            try container.encode(CaseIdentifier.countingDownToStart, forKey: .state)
            try container.encode(secondsRemaining, forKey: .secondsRemaining)
        case .readyForBallDrop:
            try container.encode(CaseIdentifier.readyForBallDrop, forKey: .state)
        case .matchStarted(let score, let matchTime):
            try container.encode(CaseIdentifier.matchStarted, forKey: .state)
            try container.encode(score, forKey: .score)
            try container.encode(matchTime, forKey: .matchTime)
        case .ballOutOfPlay:
            try container.encode(CaseIdentifier.ballOutOfPlay, forKey: .state)
        case .matchWonBy(let team):
            try container.encode(CaseIdentifier.matchWonBy, forKey: .state)
            try container.encode(team, forKey: .team)

        }
    }
}

struct MatchStateComponent: Component, Codable {
    struct Transition: Codable {
        var date: Date
        var state: MatchOutput
    }

    var transitions = [Transition]()

    mutating func append(_ state: MatchOutput) {
        transitions.append(Transition(date: Date(), state: state))
    }

    init() {}
}
