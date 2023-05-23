/*
See LICENSE folder for this sample’s licensing information.

Abstract:
BallResetAnimation
*/

import Combine
import Foundation
import RealityKit

class BallResetAnimation {
    weak var root: Entity?
    let completion: () -> Void

    let field: Entity?
    let ballReturn: Entity?
    let door1: Entity
    let door2: Entity
    let doorPhysics: Entity
    let audioElement: Entity

    var ballEntity: BallEntity? {
        return BallEntity.ballEntity
    }

    private let openAnimationDuration: TimeInterval = 0.5
    private let closeAnimationDuration: TimeInterval = 0.3
    private var animations: [AnimationPlaybackController] = []
    private var animationPlaybackSubscriptions = [AnyCancellable]()
    let doorWidth: Float = 69 // cm

    private var ballPhysicsMaterial: PhysicsMaterialResource?
    private var ballAnimationPhysicsMaterial: PhysicsMaterialResource?

    init(root: Entity, completion: @escaping () -> Void) {
        self.completion = completion
        self.field = root.findEntity(named: "Field")
        self.ballReturn = root.findEntity(named: "ballReturnChamber_lod0__04")
        self.door1 = root.findEntity(named: "ballChuteDoor1_scaleX__01")!
        self.door2 = root.findEntity(named: "ballChuteDoor2_scaleX__01")!
        self.audioElement = root.findEntity(named: "Audio_Center")!
        self.doorPhysics = root.findEntity(named: "ballChuteDoorPhysics__01")!

        self.door1.memorizeCurrentTransform()
        self.door2.memorizeCurrentTransform()
    }

    func run() {
        guard let field = field, let ballReturn = ballReturn, let ball = ballEntity else {
            assertionFailure("One or more of field, ballReturn, or ball does not exist, can't run Ball reset animation")
            return
        }

        ball.isEnabled = true

        animations.removeAll()

        // field-space ball-return center
        var ballReturnCenter = field.convert(position: ballReturn.position, from: ballReturn.parent!)

        // offset below field by diameter of ball
        ballReturnCenter.y -= 2 * Constants.bowlingBallRadius

        // from field-space to local-space for ball's parent
        let ballCenterTargetPosition = field.convert(position: ballReturnCenter, to: ball.parent!)

        var ballStartTransform = Transform(scale: .one, rotation: .identity, translation: .zero)
        ballStartTransform.translation = ballCenterTargetPosition

        ball.physicsBody!.mode = .kinematic
        ball.physicsMotion!.linearVelocity = .zero
        ball.physicsMotion!.angularVelocity = .zero

        if ballPhysicsMaterial == nil {
            ballPhysicsMaterial = ball.physicsBody!.material
        }
        let newMaterial = PhysicsMaterialResource.generate(friction: 0.7, restitution: 0)
        ball.physicsBody!.material = newMaterial
        ball.transform = ballStartTransform
        ball.resetPhysicsTransform(recursive: true)
        self.doorPhysics.isEnabled = false
        SyncSoundPublisher.playSound(named: "Reset_Open", on: audioElement)

        open { [weak self] in
            guard let `self` = self else { return }
            ball.physicsBody?.mode = .dynamic
            ball.applyLinearImpulse([0, 70, 0], relativeTo: GamePlayManager.physicsOrigin)
            SyncSoundPublisher.playSound(named: "Woosh_me_1", on: self.audioElement)
            SyncSoundPublisher.playSound(named: "Reset_Close", on: self.audioElement)
            DispatchQueue.main.asyncAfter(wallDeadline: .now() + .milliseconds(500)) {
                self.close { [weak self] in
                    guard let `self` = self else { return }
                    // restore physics
                    self.doorPhysics.isEnabled = true
                    ball.physicsBody!.material = self.ballPhysicsMaterial!
                    self.completion()
                }
            }
        }
    }

    private func open(completion: @escaping () -> Void) {
        var door1Transform = door1.memorizedTransform!
        door1Transform.translation.y -= 1
        var door2Transform = door2.memorizedTransform!
        door2Transform.translation.y -= 1

        let yAnimationTime: TimeInterval = 0.1

        let animation1 = door1.move(to: door1Transform,
                                        relativeTo: door1.parent,
                                        duration: yAnimationTime,
                                        timingFunction: .default)
        let animation2 = door2.move(to: door2Transform,
                                        relativeTo: door2.parent,
                                        duration: yAnimationTime,
                                        timingFunction: .default)
        door1.scene?.publisher(for: AnimationEvents.PlaybackCompleted.self, on: door1)
            .sink { [weak self] event in
                guard let self = self, event.playbackController == animation1 else { return }
                door1Transform.translation.x = self.doorWidth
                door2Transform.translation.x = -self.doorWidth
                let animation1 = self.door1.move(to: door1Transform,
                                                    relativeTo: self.door1.parent,
                                                    duration: self.openAnimationDuration - yAnimationTime,
                                                    timingFunction: .easeOut)
                let animation2 = self.door2.move(to: door2Transform,
                                                    relativeTo: self.door2.parent,
                                                    duration: self.openAnimationDuration - yAnimationTime,
                                                    timingFunction: .easeOut)

                self.door1.scene?.publisher(for: AnimationEvents.PlaybackCompleted.self, on: self.door1)
                    .sink { event in
                        guard event.playbackController == animation1 else { return }
                        completion()
                    }
                    .store(in: &self.animationPlaybackSubscriptions)

                self.animations.append(contentsOf: [animation1, animation2])
            }
            .store(in: &animationPlaybackSubscriptions)

        animations.append(contentsOf: [animation1, animation2])
    }

    private func close(completion: @escaping () -> Void) {
        var door1Transform = door1.transform
        door1Transform.translation.x = 0
        var door2Transform = door2.transform
        door2Transform.translation.x = 0

        let yAnimationTime: TimeInterval = 0.1

        let animation1 = door1.move(to: door1Transform,
                                            relativeTo: door1.parent,
                                            duration: closeAnimationDuration - yAnimationTime,
                                            timingFunction: .easeOut)
        let animation2 = door2.move(to: door2Transform,
                                            relativeTo: door2.parent,
                                            duration: closeAnimationDuration - yAnimationTime,
                                            timingFunction: .easeOut)

        door2.scene?.publisher(for: AnimationEvents.PlaybackCompleted.self, on: door2)
            .sink { [weak self] event in
                guard let self = self, event.playbackController == animation2 else { return }
                door1Transform = self.door1.memorizedTransform!// make sure we go back to original
                door2Transform = self.door2.memorizedTransform!
                let animation1 = self.door1.move(to: door1Transform,
                                                          relativeTo: self.door1.parent,
                                                          duration: yAnimationTime,
                                                          timingFunction: .default)
                let animation2 = self.door2.move(to: door2Transform,
                                                          relativeTo: self.door2.parent,
                                                          duration: yAnimationTime,
                                                          timingFunction: .default)

                self.door2.scene?.publisher(for: AnimationEvents.PlaybackCompleted.self, on: self.door2)
                    .sink { event in
                        guard event.playbackController == animation2 else { return }
                        completion()
                    }
                    .store(in: &self.animationPlaybackSubscriptions)

                self.animations.append(contentsOf: [animation1, animation2])
            }
            .store(in: &animationPlaybackSubscriptions)
        animations.append(contentsOf: [animation1, animation2])
    }
}
