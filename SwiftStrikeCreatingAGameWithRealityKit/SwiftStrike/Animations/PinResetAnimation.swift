/*
See LICENSE folder for this sample’s licensing information.

Abstract:
PinResetAnimation
*/

import Combine
import Foundation
import os.log
import RealityKit

extension GameLog {
    static let pinResetAnimation = OSLog(subsystem: subsystem, category: "pinResetAnimation")
}

enum PinResetAnimationTunables {
    static var enableSweeperA = TunableBool("Enable Sweeper for TeamA", def: true)
    static var enableSweeperB = TunableBool("Enable Sweeper for TeamB", def: true)
    static var enableGutterDoorA = TunableBool("Enable Gutter Door for TeamA", def: true)
    static var enableGutterDoorB = TunableBool("Enable Gutter Door for TeamB", def: true)
}

class PinResetAnimation {
    weak var field: FieldEntity?

    let door1: Entity
    let door2: Entity

    let audioEnd1: Entity
    let audioEnd2: Entity

    let gutter1: Entity
    let gutter2: Entity

    private var sweepers = [SweeperEntity]()
    private var sweeperAnimations = [AnimationPlaybackController]()

    private let animationTime: TimeInterval = 1.0
    private let door1OpenTransform: Transform
    private let door2OpenTransform: Transform

    private var door1Animation: AnimationPlaybackController?
    private var door2Animation: AnimationPlaybackController?
    private var doorAnimation: AnimationPlaybackController?
    private var doorOpenSubscription: AnyCancellable?
    private var doorCloseSubscription: AnyCancellable?

    private var syncSink: AnyCancellable?

    private var standingPins: [PinEntity] = []

    private var animationPlaybackSubscriptions = [AnyCancellable]()

    init(field: FieldEntity, completion: @escaping () -> Void) {
        self.field = field

        // somehow the game and the field assets have swapped ideas of which side of the court A and B are on
        // so when we load the entities, we load 2 from A in the assets, and 1 from B in the assets
        // so that 1 is consistent with A in the game
        guard let door1 = field.findEntity(named: "teamB_pinChuteDoor_scaleZ__01") else { fatalError() }
        guard let door2 = field.findEntity(named: "teamA_pinChuteDoor_scaleZ__01") else { fatalError() }
        self.door1 = door1
        self.door2 = door2

        guard let audioEnd1 = field.findEntity(named: "Audio_PinReset2") else { fatalError() }
        guard let audioEnd2 = field.findEntity(named: "Audio_PinReset1") else { fatalError() }
        self.audioEnd1 = audioEnd1
        self.audioEnd2 = audioEnd2

        guard let gutter1 = field.findEntity(named: "teamB_pinGutterDoor_scaleZ__02") else { fatalError() }
        guard let gutter2 = field.findEntity(named: "teamA_pinGutterDoor_scaleZ__02") else { fatalError() }
        self.gutter1 = gutter1
        self.gutter2 = gutter2

        door1.memorizeCurrentTransform()
        door2.memorizeCurrentTransform()

        let boundingBox = door1.visualBounds(relativeTo: door1.parent!)
        let boxSize = boundingBox.max - boundingBox.min
        os_log(.default, log: GameLog.pinResetAnimation, "door box size %s", "\(boxSize.terseDescription)")
        let boxSizeZ = boxSize.z

        let door1Transform = door1.transform
        let door2Transform = door2.transform

        var door1TargetTransform = door1Transform
        var door2TargetTransform = door2Transform

        door1TargetTransform.translation.z = -boxSizeZ
        door2TargetTransform.translation.z = boxSizeZ

        os_log(.default, log: GameLog.pinResetAnimation, "teamA door1 open Z %5.2f -> %5.2f",
               door1Transform.translation.z, door1TargetTransform.translation.z)
        os_log(.default, log: GameLog.pinResetAnimation, "teamB door2 open Z %5.2f -> %5.2f",
               door2Transform.translation.z, door2TargetTransform.translation.z)
        door1OpenTransform = door1TargetTransform
        door2OpenTransform = door2TargetTransform
    }

    private enum SweeperConstants {
        // sweeper overlap width of field per edge
        static let ballDiameter = Constants.bowlingBallRadius * 2.0
        // how much to extend sweeper beyond field width on each side
        static let widthOverlap: Float = 1.0
        static let width = Constants.groundWidth + (widthOverlap * 2.0)
        // sweeper should under cut pin so it falls towards center of court, but is pushed back towards gutter
        static let height: Float = 0.25
        // sweeper only needs to have some depth (smaller than ball is fine)
        static let depth: Float = 0.5
        static let size: SIMD3<Float> = [width, height, depth]
        // start on the other side of field off the end to make
        // sure no pins start inside sweeper body
        static let start: Float = -(Constants.groundLength * 0.5) - depth
        // position between center of court and head pin were we can
        // accelerate to a faster velocity to move pins into gutter
        static let middle: Float = 2.0
        // end before open gutter
        static let gutterClosedSize = ballDiameter + 0.2
        static let end = (Constants.groundLength * 0.5) - (gutterClosedSize + (depth * 0.5))
        // distance of sweeper motion along Z axis
        static let travel = Double(end - start)
        // from old sweeper code, distance travels was 19 m in 3 s, we added a 1.5* get more impact on the pins
        static let velocity = 1.5 * 19.0 / 3.0
        // time we wait for the sweepers to move 3/4 way across field into position for pin sweep
        static let startTime: TimeInterval = 1.0
        // time after sweepers arrive in field before we sweep the pins
        static let waitToSweepTime = 0.5
        // calculate animation time using target distance of travel and our target velocity
        static let continueTime: TimeInterval = travel / velocity
    }

    private func addSweeper(team: Team) -> SweeperEntity {
        let sweeper = SweeperEntity(size: SweeperConstants.size, team: team)
        field?.addChild(sweeper)
        return sweeper
    }

    private func makeSweepers() {
        if PinResetAnimationTunables.enableSweeperA.value {
            sweepers.append(addSweeper(team: .teamA))
        }
        if PinResetAnimationTunables.enableSweeperB.value {
            sweepers.append(addSweeper(team: .teamB))
        }
    }

    private func makeSweeperAnimation(sweeper: SweeperEntity,
                                      startZ: Float,
                                      endZ: Float,
                                      time: TimeInterval,
                                      timingFunction: AnimationTimingFunction) -> AnimationPlaybackController {
        let yOffset = SweeperConstants.height * 0.5
        var start: Transform = .identity
        start.translation = [0, yOffset, startZ]

        var end: Transform = .identity
        end.translation = [0, yOffset, endZ]

        sweeper.transform = start
        return sweeper.move(to: end, relativeTo: GamePlayManager.physicsOrigin, duration: time, timingFunction: timingFunction)
    }

    private func makeSweeperAnimations(from startZ: Float,
                                       to endZ: Float,
                                       in time: TimeInterval,
                                       timingFunction animationTimingFunction: AnimationTimingFunction? = nil) {
        assert(sweeperAnimations.isEmpty)
        sweeperAnimations = [AnimationPlaybackController]()

        guard !sweepers.isEmpty else {
            return
        }

        let timingFunction = animationTimingFunction ?? .default
        sweepers.forEach { sweeper in
            let team = sweeper.team
            #if DEBUG
            os_log(.default,
                   log: GameLog.pinResetAnimation,
                   "add animation: start=%0.2f, end=%0.2f, travel=%0.2f, time=%0.2f, velocity=%0.2f, %s",
                   startZ,
                   endZ,
                   endZ - startZ,
                   time,
                   (endZ - startZ) / Float(time),
                   "\(sweeper.name)")
            #endif
            sweeperAnimations.append(makeSweeperAnimation(sweeper: sweeper,
                                                          startZ: startZ * team.zSign,
                                                          endZ: endZ * team.zSign,
                                                          time: time,
                                                          timingFunction: timingFunction))
        }
    }

    private func startSweeperAnimations() {
        makeSweeperAnimations(from: SweeperConstants.start, to: SweeperConstants.middle, in: SweeperConstants.startTime, timingFunction: .linear)
    }

    private func continueSweeperAnimations() {
        makeSweeperAnimations(from: SweeperConstants.middle, to: SweeperConstants.end, in: SweeperConstants.continueTime)
    }

    private func animateSweepers(_ completion: (() -> Void)? = nil) {
        guard let scene = field?.scene, !sweeperAnimations.isEmpty else {
            completion?()
            return
        }

        let mergeMany = Publishers.MergeMany(sweeperAnimations
            .compactMap {
                return $0.entity
            }
            .map { eventSource in
                scene.publisher(for: AnimationEvents.PlaybackCompleted.self, on: eventSource)
            }
        )

        assert(syncSink == nil)
        syncSink = mergeMany
            .sink { [weak self] event in
                guard let self = self, self.sweeperAnimations.contains(event.playbackController) else { return }
                self.sweeperAnimations.removeAll {
                    if $0 == event.playbackController {
                        return true
                    }
                    return false
                }
                if self.sweeperAnimations.isEmpty {
                    DispatchQueue.main.async {
                        self.syncSink = nil
                        completion?()
                    }
                }
            }
    }

    func clearField(completion: @escaping () -> Void) {
        continueSweeperAnimations()
        animateSweepers(completion)
    }

    func saveUprightPins(_ fieldEntity: FieldEntity) {
        standingPins.removeAll()
        var teamPinCount = [Team: Int]()
        teamPinCount[.none] = 0
        teamPinCount[.teamA] = 0
        teamPinCount[.teamB] = 0
        fieldEntity.forEachInHierarchy { entity, _ in
            if let pinEntity = entity as? PinEntity, pinEntity.upright {
                standingPins.append(pinEntity)
                teamPinCount[pinEntity.placementTeam]! += 1
            }
        }
        os_log(.default, log: GameLog.pinResetAnimation, "%d teamA pins, %d teamB pins, %d pins with no team",
               teamPinCount[.teamA]!, teamPinCount[.teamB]!, teamPinCount[.none]!)
    }

    func run(resetStanding: Bool) {
        guard let field = field else { fatalError() }

        saveUprightPins(field)

        let group = DispatchGroup()
        // make sure the pin reset happens after both clear and door animations are done
        group.enter()
        group.enter()

        makeSweepers()
        startSweeperAnimations()
        animateSweepers {
            DispatchQueue.main.asyncAfter(deadline: .now() + DispatchTimeInterval.milliseconds(Int(SweeperConstants.waitToSweepTime * 1000.0))) {
                self.clearField { [weak self] in
                    if let self = self {
                        self.sweepers.forEach { entity in
                            entity.removeFromParent()
                        }
                        self.sweepers = []
                    }
                    group.leave()
                }

                let door1 = self.door1 as? HasPhysicsBody
                let door2 = self.door2 as? HasPhysicsBody

                // we have to do this because this body doesn't have a mesh, so it doesn't get turned into a ModelEntity
                if PinResetAnimationTunables.enableGutterDoorA.value, let door1 = door1 {
                    SyncSoundPublisher.playSound(named: "Pin_reset_animation_01", on: self.audioEnd1)
                    door1.physicsBody?.mode = .kinematic
                }
                if PinResetAnimationTunables.enableGutterDoorB.value, let door2 = door2 {
                    SyncSoundPublisher.playSound(named: "Pin_reset_animation_02", on: self.audioEnd2)
                    door2.physicsBody?.mode = .kinematic
                }

                self.open { [weak self] in
                    guard let self = self else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(250)) {
                        self.close {
                            if PinResetAnimationTunables.enableGutterDoorA.value, let door1 = door1 {
                                door1.physicsBody?.mode = .static
                            }
                            if PinResetAnimationTunables.enableGutterDoorB.value, let door2 = door2 {
                                door2.physicsBody?.mode = .static
                            }

                            // make sure the floor is not moving and is static before resetting pins
                            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(250)) {
                                group.leave()
                            }
                        }
                    }
                }
            }
        }

        if resetStanding {
            group.notify(queue: .main) { [weak self] in
                guard let self = self else { return }
                self.resetStanding(pins: self.standingPins) {
                    let note = Notification.animationEnded(.resetPins)
                    NotificationCenter.default.post(note)
                }
            }
        }
    }

    func gameReset() {
        syncSink = nil

        animationPlaybackSubscriptions = []

        doorOpenSubscription = nil
        doorCloseSubscription = nil

        door1Animation = nil
        door2Animation = nil
        doorAnimation = nil

        sweeperAnimations = []
        sweepers = []

        standingPins = []

        door1.restoreToMemorizedTransform()
        door2.restoreToMemorizedTransform()
    }

    private func open(completion: @escaping () -> Void) {
        os_log(.default, log: GameLog.pinResetAnimation, "teamA door1 open start Z %5.2f",
               door1.position(relativeTo: GamePlayManager.physicsOrigin).z)
        os_log(.default, log: GameLog.pinResetAnimation, "teamB door2 open start Z %5.2f",
               door2.position(relativeTo: GamePlayManager.physicsOrigin).z)
        var entity: Entity?
        doorAnimation = nil
        if PinResetAnimationTunables.enableGutterDoorA.value {
            entity = door1
            door1Animation = door1.move(to: door1OpenTransform,
                                        relativeTo: door1.parent,
                                        duration: animationTime,
                                        timingFunction: .easeInOut)
            doorAnimation = door1Animation
        }
        if PinResetAnimationTunables.enableGutterDoorB.value {
            if entity == nil {
                entity = door2
            }
            door2Animation = door2.move(to: door2OpenTransform,
                                        relativeTo: door2.parent,
                                        duration: animationTime,
                                        timingFunction: .easeInOut)
            if doorAnimation == nil {
                doorAnimation = door2Animation
            }
        }
        if let doorEntity = entity {
            doorOpenSubscription = doorEntity.scene?.publisher(for: AnimationEvents.PlaybackCompleted.self, on: doorEntity)
                .sink { [weak self] event in
                    guard let self = self, event.playbackController == self.doorAnimation else { return }
                    // make sure we don't get the close animation completed event
                    self.doorOpenSubscription = nil
                    os_log(.default, log: GameLog.pinResetAnimation, "teamA door1 open end Z %5.2f",
                           self.door1.position(relativeTo: GamePlayManager.physicsOrigin).z)
                    os_log(.default, log: GameLog.pinResetAnimation, "teamB door2 open end Z %5.2f",
                           self.door2.position(relativeTo: GamePlayManager.physicsOrigin).z)
                    completion()
                }
        } else {
            completion()
        }
    }

    private func close(completion: @escaping () -> Void) {
        os_log(.default, log: GameLog.pinResetAnimation, "teamA door1 close start Z %5.2f",
               door1.position(relativeTo: GamePlayManager.physicsOrigin).z)
        os_log(.default, log: GameLog.pinResetAnimation, "teamB door2 close start Z %5.2f",
               door2.position(relativeTo: GamePlayManager.physicsOrigin).z)
        var entity: Entity?
        doorAnimation = nil
        if PinResetAnimationTunables.enableGutterDoorA.value {
            entity = door1
            door1Animation = door1.move(to: door1.memorizedTransform!,
                                        relativeTo: door1.parent,
                                        duration: animationTime,
                                        timingFunction: .easeInOut)
            doorAnimation = door1Animation
        }
        if PinResetAnimationTunables.enableGutterDoorB.value {
            if entity == nil {
                entity = door2
            }
            door2Animation = door2.move(to: door2.memorizedTransform!,
                                        relativeTo: door2.parent,
                                        duration: animationTime,
                                        timingFunction: .easeInOut)
            if doorAnimation == nil {
                doorAnimation = door2Animation
            }
        }

        if let doorEntity = entity {
            doorCloseSubscription = doorEntity.scene?.publisher(for: AnimationEvents.PlaybackCompleted.self, on: doorEntity)
                .sink { [weak self] event in
                    guard let self = self, event.playbackController == self.doorAnimation else { return }
                    self.doorCloseSubscription = nil
                    os_log(.default, log: GameLog.pinResetAnimation, "teamA door1 close end Z %5.2f",
                           self.door1.position(relativeTo: GamePlayManager.physicsOrigin).z)
                    os_log(.default, log: GameLog.pinResetAnimation, "teamB door2 close end Z %5.2f",
                           self.door2.position(relativeTo: GamePlayManager.physicsOrigin).z)
                    completion()
                }
        } else {
            completion()
        }
    }

    private func resetStanding(pins: [PinEntity], outerCompletion: @escaping () -> Void) {
        let pinRowOffsetTime = 0.100
        let pinScaleDuration = 0.300
        let pinScaleCurve = AnimationTimingFunction.easeOut
        resetPins(pins: pins,
                  startOffsetSec: 0.0,
                  rowOffsetSec: pinRowOffsetTime,
                  pinGrowDurationSec: pinScaleDuration,
                  pinGrowCurve: pinScaleCurve,
                  outerCompletion: outerCompletion)
    }

    static let pinRowOffsetTime = 0.100
    static let pinScaleDuration = 0.300

    func resetPins(pins: [PinEntity],
                   startOffsetSec: Double = 0.0,
                   rowOffsetSec: Double = PinResetAnimation.pinRowOffsetTime,
                   pinGrowDurationSec: Double = PinResetAnimation.pinScaleDuration,
                   pinGrowCurve: AnimationTimingFunction = .easeOut,
                   outerCompletion: @escaping () -> Void) {
        var counter = 0
        var counterMax = 0
        var animations: [AnimationPlaybackController] = [] {
            didSet {
                counter += 1
                counterMax = counter
            }
        }
        #if DEBUG
        let startTime = DispatchTime.now()
        #endif
        let completion: () -> Void = {
            counter -= 1
            if counter == 0 {
                #if DEBUG
                let endTime = DispatchTime.now()
                os_log(.default, log: GameLog.pinResetAnimation,
                       "All(%d) pins are reset after %0.4f ms.",
                       counterMax, Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / Double(1_000_000.0))
                #endif
                outerCompletion()
            }
        }

        let group1: [PinEntity] = pins.filter { $0.placementID == 1 }
        let group2: [PinEntity] = pins.filter { pin in
            let id = pin.placementID
            return [2, 3].contains(id)
        }
        let group3: [PinEntity] = pins.filter { pin in
            let id = pin.placementID
            return [4, 5, 6].contains(id)
        }
        let group4: [PinEntity] = pins.filter { pin in
            let id = pin.placementID
            return [7, 8, 9, 10].contains(id)
        }

        /// - Tag: PinResetCode
        pins.forEach { pin in
            // put the whole pin where it should go
            pin.gameReset()
            // we need to set the physicsBody.mode to kinematic
            // so that the animation does not operate at the same
            // time physics is - we reset it to dynamic when the
            // animation completes
            pin.physicsBody?.mode = .kinematic
            // initial scale for animating pin "in" is 0
            pin.renderEntity.transform.scale = .zero
        }

        [group1, group2, group3, group4].enumerated().publisher
            .flatMap { index, group -> AnyPublisher<PinEntity, Never> in
                let startTime = startOffsetSec + (Double(index) * rowOffsetSec)
                return group.publisher
                    .delay(for: .seconds(startTime), scheduler: DispatchQueue.main)
                    .compactMap { return $0.renderEntity.scene != nil ? $0 : nil }
                    .flatMap { (pin: PinEntity) -> AnyPublisher<PinEntity, Never> in
                        let anim = pin.renderEntity.move(to: Transform.identity,
                                                         relativeTo: pin,
                                                         duration: pinGrowDurationSec,
                                                         timingFunction: pinGrowCurve)
                        animations.append(anim)
                        return pin.renderEntity.scene!
                            .publisher(for: AnimationEvents.PlaybackCompleted.self, on: pin.renderEntity)
                            .filter { $0.playbackController == anim }
                            .map { _ in return pin }
                        .eraseToAnyPublisher()
                    }
                    .eraseToAnyPublisher()
            }
            .sink { pin in
                pin.physicsBody?.mode = .dynamic
                pin.gameReset()
                #if DEBUG
                let endTime = DispatchTime.now()
                os_log(.default, log: GameLog.pinResetAnimation,
                       "%s is upright after %0.4f ms.",
                       "\(pin)", Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / Double(1_000_000.0))
                #endif
                completion()
            }
            .store(in: &self.animationPlaybackSubscriptions)
    }
}
