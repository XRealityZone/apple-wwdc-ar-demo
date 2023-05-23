/*
See LICENSE folder for this sample’s licensing information.

Abstract:
AnimationGroup
*/

import Combine
import RealityKit

class AnimationGroup {
    let rootEntity: Entity // The root entity
    var completion: (() -> Void)?
    private var entities: [Entity] = []
    private var animationControllers: [AnimationPlaybackController] = []
    private let repeats: Bool
    private var inFlightCount = 0
    private var subscriptions = [AnyCancellable]()

    enum State {
        case new, running, paused, complete
    }
    private(set) var state: State = .new

    init(_ entity: Entity, repeats: Bool = false) {
        self.rootEntity = entity
        self.repeats = repeats
        entity.forEachInHierarchy { ent, _ in
            ent.memorizeCurrentTransform()
        }
    }

    private func checkForCompletionAndCallCallback() {
        precondition(inFlightCount >= 0)
        if inFlightCount == 0 {
            state = .complete
            completion?()
        }
    }

    func start() {
        entities.removeAll()
        animationControllers.removeAll()

        rootEntity.forEachInHierarchy { entity, _ in
            entities.append(entity) // see 2
            entity.availableAnimations.forEach { animationResource in
                self.inFlightCount += 1
                let resource = repeats ? animationResource.repeat(duration: .infinity) : animationResource
                
                let animationController = entity.playAnimation(resource,
                                                               transitionDuration: 1.0,
                                                               separateAnimatedValue: false,
                                                               startsPaused: false)
                
                entity.scene?.publisher(for: AnimationEvents.PlaybackCompleted.self, on: entity)
                    .sink { [weak self] event in
                        guard let self = self, event.playbackController == animationController else { return }
                        self.inFlightCount -= 1
                        self.checkForCompletionAndCallCallback()
                    }
                    .store(in: &subscriptions)
                animationControllers.append(animationController)
            }
        }
        state = .running
    }

    func stop() {
        inFlightCount = 0
        animationControllers.forEach { $0.stop() }
        state = .complete
    }

    func pause() {
        if state != .running { return }
        animationControllers.forEach { $0.pause() }
        state = .paused
    }

    func resume() {
        if state != .paused { return }
        animationControllers.forEach { $0.resume() }
        state = .running
    }

    func reset() {
        rootEntity.forEachInHierarchy { entity, _ in
            entity.restoreToMemorizedTransform()
        }
    }
}
