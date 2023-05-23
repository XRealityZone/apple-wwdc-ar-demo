/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Field Entity
*/

import Combine
import Foundation
import os.log
import RealityKit

final class FieldEntity: Entity, LoadedEntity, HasPhysics, GameResettable {

    var ballResetAnimation: BallResetAnimation!
    var pinResetAnimation: PinResetAnimation!
    var winnerAnimation: WinnerAnimation!
    var drawAnimationA: DrawAnimation!
    var drawAnimationB: DrawAnimation!

    var notificationTokens: [NSObjectProtocol] = []

    static let startBallDropNotificationName = Notification.Name(rawValue: "startBallDropNotification")
    static let winnerNotificationName = Notification.Name(rawValue: "startWinnerNotification")
    static let drawNotificationName = Notification.Name(rawValue: "startDrawNotification")
    static let startPinResetNotificationName = Notification.Name("startPinResetNotification")
    static let showFieldNotificationName = Notification.Name("showFieldNotificationName")

    static var showAudioEntities = false

    var courtEntity: Entity!

    var openingAnimations: [AnimationPlaybackController] = []
    var animationPlaybackSubscriptions = [AnyCancellable]()

    static func loadAsync() -> AnyPublisher<FieldEntity, Error> {
        let court = Asset.name(for: .court)
        return Entity.loadAsync(named: court)
            .zip(WinnerAnimation.loadAsync(), DrawAnimation.loadAsync())
            .map { (court, winner, draw) in
                do {
                    let field = try FieldEntity.configure(court: court)
                    field.winnerAnimation = winner
                    field.drawAnimationA = draw
                    let drawB = DrawAnimation(sign: (draw.sign?.clone(recursive: true))!)
                    field.drawAnimationB = drawB
                    field.children.append(winner)
                    field.children.append(draw)
                    field.children.append(drawB)
                    return field
                } catch {
                    fatalError("\(error)")
                }
            }
            .eraseToAnyPublisher()
    }

    private static func configure(court: Entity) throws -> FieldEntity {
        let field = FieldEntity()
        field.name = "Field"

        try process(courtEntity: court)
        court.name = "Court"
        field.courtEntity = court
        field.addChild(court)

        let triggerBoxHeight: Float = 20
        let triggerBoxSize: SIMD3<Float> = [Constants.groundWidth * 2, triggerBoxHeight, Constants.groundWidth * 2]

        let audioEntity1 = ModelEntity()
        audioEntity1.name = "Audio_PinReset1"
        audioEntity1.position = [0, 1.3, Team.teamB.zSign * 6]
        if showAudioEntities {
            audioEntity1.model = ModelComponent(mesh: MeshResource.generateBox(size: 0.3),
                                                materials: [SimpleMaterial(color: .red, isMetallic: false)])
        }
        field.children.append(audioEntity1)

        let audioEntity2 = ModelEntity()
        audioEntity2.name = "Audio_PinReset2"
        audioEntity2.position = [0, 1.3, Team.teamA.zSign * 6]
        if showAudioEntities {
            audioEntity2.model = ModelComponent(mesh: MeshResource.generateBox(size: 0.3),
                                                materials: [SimpleMaterial(color: .blue, isMetallic: false)])
        }
        field.children.append(audioEntity2)

        let audioEntityCenter = ModelEntity()
        audioEntityCenter.name = "Audio_Center"
        audioEntityCenter.position = [0, 1.3, 0]
        if showAudioEntities {
            audioEntityCenter.model = ModelComponent(mesh: MeshResource.generateBox(size: 0.3),
                                                     materials: [SimpleMaterial(color: .green, isMetallic: false)])
        }
        field.children.append(audioEntityCenter)

        field.ballResetAnimation = BallResetAnimation(root: court.rootEntity!, completion: {
            let note = Notification.animationEnded(.ballDrop)
            print("BallDropAnimation complete. Posting notification.", to: &logViewStream)
            os_log("BallDropAnimation complete. Posting notification.")
            NotificationCenter.default.post(note)
        })
        field.pinResetAnimation = PinResetAnimation(field: field, completion: {})

        let name = FieldEntity.startBallDropNotificationName
        let center = NotificationCenter.default
        var note: NSObjectProtocol
        note = center.addObserver(
            forName: name,
            object: nil,
            queue: .main) { [weak field] _ in
                field?.ballResetAnimation.run()
        }
        field.notificationTokens.append(note)

        note = center.addObserver(forName: FieldEntity.winnerNotificationName,
                                  object: nil,
                                  queue: .main) { [weak field] note in
            guard let team = note.object as? Team else { fatalError() }
            field?.removeAllPewPew()
            field?.pinResetAnimation.run(resetStanding: false)

            if team == .none {
                field?.drawAnimationA.run(team: Team.teamA) {
                    os_log("draw animation A finished")
                }
                field?.drawAnimationB.run(team: Team.teamB) {
                    os_log("draw animation B finished")
                }
            } else {
                field?.winnerAnimation.run(team: team) {
                    os_log("winner animation finished")
                }
            }
        }
        field.notificationTokens.append(note)

        note = center.addObserver(forName: FieldEntity.drawNotificationName,
                                  object: nil,
                                  queue: .main) { [weak field] _ in
            field?.removeAllPewPew()
            field?.pinResetAnimation.run(resetStanding: false)
            field?.drawAnimationA.run(team: Team.teamA) {
                os_log("draw animation A finished")
            }
            field?.drawAnimationB.run(team: Team.teamB) {
                os_log("draw animation B finished")
            }
        }
        field.notificationTokens.append(note)

        note = center.addObserver(forName: FieldEntity.startPinResetNotificationName,
                                  object: nil,
                                  queue: .main) { [weak field] _ in
            field?.removeAllPewPew()
            field?.pinResetAnimation.run(resetStanding: true)
        }
        field.notificationTokens.append(note)

        note = center.addObserver(forName: FieldEntity.showFieldNotificationName,
                                  object: nil,
                                  queue: .main) { [weak field] _ in
            field?.showField(animated: true)
        }
        field.notificationTokens.append(note)

        let gutterCollisionEntityA = BelowCourtBallTriggerEntity(size: triggerBoxSize)
        gutterCollisionEntityA.position = [0, -(triggerBoxHeight / 2.0 + 0.5), -6]

        let gutterCollisionEntityB = BelowCourtBallTriggerEntity(size: triggerBoxSize)
        gutterCollisionEntityB.position = [0, -(triggerBoxHeight / 2.0 + 0.5), 6]

        field.children.append(gutterCollisionEntityA)
        field.children.append(gutterCollisionEntityB)

        return field
    }

    func gameReset() {
        children.forEach { entity in
            if let resettable = entity as? GameResettable {
                resettable.gameReset()
            }
        }
        pinResetAnimation.gameReset()
        prepareToShowField()
        notificationTokens = []
    }

    func removeAllPewPew() {
        // remove any debug pins that may exist so pins don't end up on top of them
        var cubes: [Entity] = []
        forEachInHierarchy { entity, _ in
            if entity.name == "PewPew!" {
                cubes.append(entity)
            }
        }
        cubes.forEach { $0.removeFromParent() }
    }

    func resetUprightPins() {
        var pins: [PinEntity] = []
        forEachInHierarchy { entity, _ in
            if let pinEntity = entity as? PinEntity, pinEntity.upright {
                pins.append(pinEntity)
            }
        }
        pins.forEach { $0.gameReset() }
    }

    func resetAllPins() {
        var pins: [PinEntity] = []
        forEachInHierarchy { entity, _ in
            if let pinEntity = entity as? PinEntity {
                pins.append(pinEntity)
            }
        }
        pins.forEach { $0.gameReset() }
    }

    private static func process(courtEntity: Entity) throws {
        let pipeline = Pipeline()
        try pipeline.process(root: courtEntity) { (entity, shapes) in
            if entity.name.contains("courtWalls") {
                entity.components[PhysicsBodyComponent.self] = PhysicsBodyComponent.generate(
                    shapes: shapes,
                    mass: PhysicsConstants.wallMass,
                    staticFriction: PhysicsConstants.wallFriction,
                    restitution: PhysicsConstants.wallRestitution,
                    mode: .static
                )
                entity.components[CollisionComponent.self] = CollisionComponent.generate(
                    shapes: shapes,
                    mode: .default,
                    group: .wall,
                    mask: [.ball, .pin]
                )
            } else {
                entity.components[PhysicsBodyComponent.self] = PhysicsBodyComponent.generate(
                    shapes: shapes,
                    mass: PhysicsConstants.groundMass,
                    staticFriction: PhysicsConstants.groundFriction,
                    restitution: PhysicsConstants.groundRestitution,
                    mode: .static
                )
                entity.components[CollisionComponent.self] = CollisionComponent.generate(
                    shapes: shapes,
                    mode: .default,
                    group: .ground,
                    mask: [.ball, .pin]
                )
            }
        }
    }

    private static func process(introEntity: Entity) throws {
        let pipeline = Pipeline()
        try pipeline.process(root: introEntity)

        let removedEntityNames = ["court_cosmic__01", "ball_ballA__01"]
        for name in removedEntityNames {
            guard let entity = introEntity.findEntity(named: name) else {
                fatalError()
            }
            entity.removeFromParent()
        }
    }

    func prepareToShowField() {
        hideField()
    }

    func hideField(animated: Bool = false) {
        // Move the rails down
        let rails = findEntity(named: "court_courtRails__01")!
        rails.transform.translation.y = -80

        // Hide the pins
        findEntities(ofType: PinEntity.self).forEach {
            $0.gameReset()
            $0.isEnabled = false
        }

        // Hide the ball
        findEntities(ofType: BallEntity.self).forEach {
            $0.isEnabled = false
        }

        // Close the gutters
        pinResetAnimation.gutter1.isEnabled = true
        pinResetAnimation.gutter1.transform = .identity

        pinResetAnimation.gutter2.isEnabled = true
        pinResetAnimation.gutter2.transform = .identity
    }

    func showField(animated: Bool = false) {
        let railDuration = 0.3
        let pinDuration = 0.3
        let gutterDuration = 0.3
        let pinStartOffsetSec = 0.300
        let pinRowOffsetSec = 0.100

        let railCurve: AnimationTimingFunction = .easeOut
        let pinScaleCurve: AnimationTimingFunction = .easeOut
        let gutterCurve: AnimationTimingFunction = .easeOut

        let ballStart = 500

        var counter = 0
        var animations: [AnimationPlaybackController] = [] {
            didSet {
                counter += 1
            }
        }
        let completion: () -> Void = {
            counter -= 1
            if counter == 0 {
                // Leaving this here for documentation of how we'd trigger the state change at the end of a
                // group of animations.
//                let note = Notification.animationEnded(.courtReady)
//                NotificationCenter.default.post(note)
            }
        }

        // Start the ball after a delay to overlap animation
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(ballStart)) {
            let note = Notification.animationEnded(.courtReady)
            NotificationCenter.default.post(note)
        }

        // Move the rails up
        let rails = findEntity(named: "court_courtRails__01")!
        let railAnimation = rails.move(to: Transform.identity,
                                       relativeTo: rails.parent!,
                                       duration: railDuration,
                                       timingFunction: railCurve)
        rails.scene?.publisher(for: AnimationEvents.PlaybackCompleted.self, on: rails)
            .sink { event in
                guard event.playbackController == railAnimation else { return }
                completion()
            }
            .store(in: &animationPlaybackSubscriptions)

        animations.append(railAnimation)

        // Open the gutters
        let gutter1 = pinResetAnimation.gutter1
        let gutter2 = pinResetAnimation.gutter2

        var gutter1Transform = gutter1.transform
        gutter1Transform.translation.z = 130.42
        let gutter1Anim = gutter1.move(to: gutter1Transform,
                                       relativeTo: gutter1.parent!,
                                       duration: gutterDuration,
                                       timingFunction: gutterCurve)
        gutter1.scene?.publisher(for: AnimationEvents.PlaybackCompleted.self, on: gutter1)
            .sink { event in
                guard event.playbackController == gutter1Anim else { return }
                completion()
                gutter1.isEnabled = false
            }
            .store(in: &animationPlaybackSubscriptions)

        var gutter2Transform = gutter2.transform
        gutter2Transform.translation.z = -130.42
        let gutter2Anim = gutter2.move(to: gutter2Transform,
                                            relativeTo: gutter2.parent!,
                                            duration: gutterDuration,
                                            timingFunction: gutterCurve)
        gutter2.scene?.publisher(for: AnimationEvents.PlaybackCompleted.self, on: gutter2)
            .sink { event in
                guard event.playbackController == gutter2Anim else { return }
                completion()
                gutter2.isEnabled = false
            }
            .store(in: &animationPlaybackSubscriptions)
        animations.append(gutter1Anim)
        animations.append(gutter2Anim)

        // Show the pins
        counter += 1
        let pins = findEntities(ofType: PinEntity.self)
        pinResetAnimation.resetPins(pins: pins,
                                    startOffsetSec: pinStartOffsetSec,
                                    rowOffsetSec: pinRowOffsetSec,
                                    pinGrowDurationSec: pinDuration,
                                    pinGrowCurve: pinScaleCurve,
                                    outerCompletion: { completion() })
    }
}
