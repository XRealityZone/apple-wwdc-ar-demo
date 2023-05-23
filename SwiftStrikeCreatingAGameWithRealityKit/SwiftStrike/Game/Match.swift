/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Match
*/

import Combine
import Foundation
import os.log
import RealityKit

struct MatchScore: Codable, Equatable {
    var teamA: UprightMask
    var teamB: UprightMask

    // Team which is currently winning
    // Returns .none in case of a draw
    var winner: Team {
        let scoreA = teamA.pinsDown
        let scoreB = teamB.pinsDown
        if scoreA == scoreB {
            return .none
        } else if scoreA > scoreB {
            return .teamA
        } else {
            return .teamB
        }
    }

    subscript(team: Team) -> UprightMask { return team == .teamA ? teamA : teamB }

    static let starting = MatchScore(teamA: UprightMask(), teamB: UprightMask())
}

enum MatchOutput: Equatable {
    case positioningStarted
    case positioningFinished

    case showField

    //positioning events
    case waitingForPlayersToStart(count: Int)
    case countingDownToStart(secondsRemaining: Int)

    //gameplay
    case readyForBallDrop
    case matchStarted(score: MatchScore, matchTime: CountdownTime)
    case ballOutOfPlay

    case matchWonBy(Team)
}

enum StartAreaTrigger {
    case started
    case ended
}

// MARK: - Animation
enum Animation: String {
    case ballDrop
    case resetPins
    case courtReady
}

extension Notification.Name {
    static let animationEnded = Notification.Name("AnimationEnded")
}

extension Notification {
    static let animationNameKey = "AnimationNameKey"
    static func animationEnded(_ animation: Animation) -> Notification {
        return Notification(name: .animationEnded, object: nil, userInfo: [animationNameKey: animation.rawValue])
    }

    var animation: Animation? {
        guard let userInfo = userInfo,
            let name = userInfo[Notification.animationNameKey] as? String,
            let animation = Animation(rawValue: name) else {
                return nil
        }
        return animation
    }
}

// input events
extension Notification.Name {
    static let forceStartSelected = Notification.Name("ForceStartSelected")
    static let forceBallInGutter = Notification.Name("ForceBallInGutter")
    static let forceEndSelected = Notification.Name("ForceEndSelected")
}

/// - Tag: MatchInputListing
enum MatchInput {
    case sceneUpdate
    case startArea(StartAreaTrigger, id: UUID, team: Team, ready: Bool)
    case forceStartSelected
    case animationEnded(Animation)
    case forceBallInGutter
    case ballInGutter
    case pinUpdate(Team, UprightMask)
    case allPinsDown(Team)
    case forceEndSelected
}

class Match {
    var matchStates: MatchStates
    var matchEvents: AnyPublisher<MatchOutput, Never>!
    let scene: Scene
    var cancellables = [AnyCancellable]()
    weak var fieldEntity: Entity?

    init(scene: Scene, mode: GameMode) {
        self.scene = scene
        guard let fieldEntity = scene.findEntity(named: "Field") else {
            fatalError("no field entity")
        }
        self.fieldEntity = fieldEntity
        self.matchStates = MatchStates(scene: scene, mode: mode)
        self.matchEvents = events()
    }

    private func events() -> AnyPublisher<MatchOutput, Never> {
        let publisher = Publishers
            .MergeMany([
                startAreaEvents(),
                sceneUpdateEvents(),
                forceStartEvents(),
                forceBallInGutterEvents(),
                forceEndEvents(),
                animationsEndedEvents(),
                pinUpdateEvents(),
                allPinsDownEvents(),
                ballGutterEvents()
            ])
            .handleGameEvents(matchStates.rules)
        publisher
            .prepend(.positioningStarted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                os_log(.default, log: GameLog.gameState, "Match event sink: %s", String(describing: event))
                self?.updateComponent(event)
            }
            .store(in: &cancellables)
        return AnyPublisher(publisher)
    }

    func updateComponent(_ state: MatchOutput) {
        var stateComponent: MatchStateComponent =
            fieldEntity?.components[MatchStateComponent.self] ?? MatchStateComponent()
        stateComponent.append(state)
        fieldEntity?.components[MatchStateComponent.self] = stateComponent
    }
}

extension Match {
    private func startAreaEvents() -> AnyPublisher<MatchInput, Never> {
        let triggerBegan = scene.publisher(for: CollisionEvents.Began.self)
            .compactMap { (began: CollisionEvents.Began) -> (PlayerTeamEntity, Team)? in
                if began.isTriggerEvent, let result = began.whoEnteredTheTrigger() {
                    return result
                }
                return nil
            }.map { (playerTeamEntity, newTeam) -> MatchInput in
                os_log(.default, log: GameLog.collision, "entity %s entered trigger", playerTeamEntity.name)
                return MatchInput.startArea(.started, id: playerTeamEntity.deviceUUID, team: newTeam, ready: true)
            }

        let triggerEnded = scene.publisher(for: CollisionEvents.Ended.self)
            .compactMap { (end: CollisionEvents.Ended) -> (PlayerTeamEntity, Team)? in
                if end.isTriggerEvent, let result = end.whoExitedTheTrigger() {
                    return result
                }
                return nil
            }.map { (playerTeamEntity, newTeam) -> MatchInput in
                os_log(.default, log: GameLog.collision, "entity %s exited trigger", playerTeamEntity.name)
                return MatchInput.startArea(.ended, id: playerTeamEntity.deviceUUID, team: newTeam, ready: false)
            }

        let publisher = triggerBegan.merge(with: triggerEnded)
        return AnyPublisher(publisher)
    }

    private func ballGutterEvents() -> AnyPublisher<MatchInput, Never> {
        let triggerBegan = scene.publisher(for: CollisionEvents.Began.self)
            .filter { $0.isBallInGutterCollision() }
            .map { _ -> MatchInput in
                os_log(.default, log: GameLog.general, "ball entered gutter")
                return MatchInput.ballInGutter
            }
        return AnyPublisher(triggerBegan)
    }

    private func forceStartEvents() -> AnyPublisher<MatchInput, Never> {
        return NotificationCenter.default.publisher(for: .forceStartSelected)
            .map { _ in MatchInput.forceStartSelected }
            .eraseToAnyPublisher()
    }
    
    private func forceBallInGutterEvents() -> AnyPublisher<MatchInput, Never> {
        return NotificationCenter.default.publisher(for: .forceBallInGutter)
            .map { _ in MatchInput.forceBallInGutter }
            .eraseToAnyPublisher()
    }

    private func forceEndEvents() -> AnyPublisher<MatchInput, Never> {
        return NotificationCenter.default.publisher(for: .forceEndSelected)
            .map { _ in MatchInput.forceEndSelected }
            .eraseToAnyPublisher()
    }

    private func sceneUpdateEvents() -> AnyPublisher<MatchInput, Never> {
        let publisher = scene.publisher(for: SceneEvents.Update.self)
            .map { _ in MatchInput.sceneUpdate }

        return AnyPublisher(publisher)
    }

    private func animationsEndedEvents() -> AnyPublisher<MatchInput, Never> {
        let publisher = NotificationCenter.default.publisher(for: .animationEnded)
            .compactMap { $0.animation }
            .map { MatchInput.animationEnded($0) }

        return AnyPublisher(publisher)
    }

    private func allPinsDownEvents() -> AnyPublisher<MatchInput, Never> {
        let publisher = NotificationCenter.default.publisher(for: .uprightStatus)
            .filter { $0.uprightMask.firstNBitsSet(10) }
            .map { MatchInput.allPinsDown($0.team) }
        return AnyPublisher(publisher)
    }

    private func pinUpdateEvents() -> AnyPublisher<MatchInput, Never> {
        let publisher = NotificationCenter.default.publisher(for: .uprightStatus)
            .map { MatchInput.pinUpdate($0.team, $0.uprightMask) }
        return AnyPublisher(publisher)
    }
}

extension MatchOutput {
    var message: String? {
        switch self {
        case .positioningStarted:
            return NSLocalizedString("Walk into beam of light", comment: "")
        case .waitingForPlayersToStart(count: let count):
            if count == 1 {
                return NSLocalizedString("Waiting for 1 player to walk into light", comment: "")
            } else {
                let format = NSLocalizedString("Waiting for %d players to walk into light", comment: "")
                return String.localizedStringWithFormat(format, count)
            }
        case .countingDownToStart(secondsRemaining: let remaining):
            let format = NSLocalizedString("Starting in %d!", comment: "")
            return String.localizedStringWithFormat(format, remaining)
        case .matchWonBy(let team):
            if team == .none {
                return NSLocalizedString("We have a draw!", comment: "")
            }
            return NSLocalizedString("We have a winner!", comment: "")
        default:
            return nil
        }
    }
}

extension CollisionEvents.Began {
    func whoEnteredTheTrigger() -> (PlayerTeamEntity, Team)? {
        var playerTeamEntity = entityA as? PlayerTeamEntity
        var trigger = entityB as? HasTrigger & HasPlacementIdentifier
        if trigger == nil {
            playerTeamEntity = entityB as? PlayerTeamEntity
            trigger = entityA as? HasTrigger & HasPlacementIdentifier
        }
        // one of two entities needs to have the Trigger Component and be a BeamOfLightEntity
        // and the other has to be an Entity with the PlayerTeamComponent
        guard let foundTrigger = trigger,
            let foundPlayerTeam = playerTeamEntity,
            let beamOfLight = trigger as? BeamOfLightEntity else { return nil }

        if !foundTrigger.triggered {
            foundTrigger.triggered = true
            beamOfLight.state = .ready
            return (foundPlayerTeam, foundTrigger.placementTeam)
        }
        return nil
    }
}

extension CollisionEvents.Ended {
    func whoExitedTheTrigger() -> (PlayerTeamEntity, Team)? {
        var playerTeamEntity = entityA as? PlayerTeamEntity
        var trigger = entityB as? HasTrigger & HasPlacementIdentifier
        if trigger == nil {
            playerTeamEntity = entityB as? PlayerTeamEntity
            trigger = entityA as? HasTrigger & HasPlacementIdentifier
        }
        // one of two entities needs to have the Trigger Component and be a BeamOfLightEntity
        // and the other has to be an Entity with the PlayerTeamComponent
        guard let foundTrigger = trigger,
            let foundPlayerTeam = playerTeamEntity,
            let beamOfLight = trigger as? BeamOfLightEntity else { return nil }

        if foundTrigger.triggered {
            foundTrigger.triggered = false
            beamOfLight.state = .waiting
            return (foundPlayerTeam, foundTrigger.placementTeam)
        }
        return nil
    }
}
