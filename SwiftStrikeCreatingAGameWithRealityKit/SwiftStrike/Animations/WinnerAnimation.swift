/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Run the winner animation
*/

import Combine
import RealityKit

final class WinnerAnimation: Entity, LoadedEntity, GameResettable {
    weak var sign: Entity?
    var signAnimation: AnimationGroup!
    var placeAnimation: AnimationPlaybackController?
    var animationPlaybackSubscriptions = [AnyCancellable]()

    init(sign: Entity) {
        super.init()
        self.sign = sign
        self.signAnimation = AnimationGroup(sign, repeats: true)
        sign.isEnabled = false
        addChild(sign)
    }

    required init() {
        super.init()
    }

    static func loadAsync() -> AnyPublisher<WinnerAnimation, Error> {
        let signName = Asset.name(for: .winnerSign)
        return Entity.loadAsync(named: signName)
            .map { (neonWinner) -> WinnerAnimation in
                return WinnerAnimation(sign: neonWinner)
            }.eraseToAnyPublisher()
    }

    func run(team: Team, completion: @escaping () -> Void) {
        guard let sign = sign else { return }
        sign.isEnabled = true
        var newTransform: Transform = .identity
        newTransform.translation = team.winnerSignAnimationPosition
        newTransform.rotation = team.signAnimationRotation
        let finalTransform = newTransform
        newTransform.scale = [0, 0, 0]
        transform = newTransform
        placeAnimation = move(to: finalTransform, relativeTo: parent!, duration: 0.2)
        scene?.publisher(for: AnimationEvents.PlaybackCompleted.self, on: self)
            .sink { [weak self] _ in
                self?.signAnimation.start()
            }
            .store(in: &animationPlaybackSubscriptions)
        signAnimation.completion = completion
    }

    func stop() {
        guard let sign = sign else { return }
        var transform = sign.transform
        transform.scale = .zero
        placeAnimation = move(to: transform, relativeTo: parent!, duration: 0.1)
        scene?.publisher(for: AnimationEvents.PlaybackCompleted.self, on: self)
            .sink { _ in
                sign.isEnabled = false
            }
            .store(in: &animationPlaybackSubscriptions)
    }

    func gameReset() {
        guard let sign = sign else { return }
        sign.isEnabled = false
    }
}
