/*
See LICENSE folder for this sample’s licensing information.

Abstract:
DrawAnimation
*/

import Combine
import RealityKit

extension Team {
    var winnerSignAnimationPosition: SIMD3<Float> {
        let zValue: Float = UserSettings.isTableTop ? 0.01 : -7.24
        switch self {
        case .none: return .zero
        case .teamA: return [0.0, 1.05, zSign * zValue]
        case .teamB: return [0.0, 1.05, zSign * zValue]
        }
    }

    var drawSignAnimationPosition: SIMD3<Float> {
        let zValue: Float = UserSettings.isTableTop ? 2.5 : -7.24
        switch self {
        case .none: return .zero
        case .teamA: return [0.0, 1.05, zSign * zValue]
        case .teamB: return [0.0, 1.05, zSign * zValue]
        }
    }

    var signAnimationRotation: simd_quatf {
        switch self {
        case .none: return .identity
        case .teamA: return .identity
        case .teamB: return simd_quatf(angle: Float.pi, axis: [0, 1, 0])
        }
    }
}

final class DrawAnimation: Entity, LoadedEntity, GameResettable {
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

    static func loadAsync() -> AnyPublisher<DrawAnimation, Error> {
        let signName = Asset.name(for: .drawSign)
        return Entity.loadAsync(named: signName)
            .map { (neonDraw) -> DrawAnimation in
                return DrawAnimation(sign: neonDraw)
            }.eraseToAnyPublisher()
    }

    func run(team: Team, completion: @escaping () -> Void) {
        guard let sign = sign else { return }
        sign.isEnabled = true
        var newTransform: Transform = .identity
        newTransform.translation = team.drawSignAnimationPosition
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
            .sink { [weak self] _ in
                self?.signAnimation.stop()
                sign.isEnabled = false
            }
            .store(in: &animationPlaybackSubscriptions)
    }

    func gameReset() {
        guard let sign = sign else { return }
        signAnimation.stop()
        sign.isEnabled = false
    }
}
