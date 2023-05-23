/*
See LICENSE folder for this sample’s licensing information.

Abstract:
MatchObserver
*/

import Combine
import Foundation
import os.log
import RealityKit

class MatchObserver {
    private let scene: Scene
    private weak var fieldEntity: Entity?
    private var subject: PassthroughSubject<MatchOutput, Never>

    var lastUpdate: Date = Date.distantPast
    var cancellables = [AnyCancellable]()

    init(scene: Scene) {
        self.scene = scene
        self.subject = PassthroughSubject()

        scene.publisher(for: SceneEvents.Update.self)
            .sink { [weak self] _ in
                self?.processUpdate()
            }
            .store(in: &cancellables)
    }

    func processUpdate() {
        guard let fieldEntity = self.fieldEntity ?? scene.findEntity(named: "Field"),
            let stateComponent: MatchStateComponent = fieldEntity.components[MatchStateComponent.self] as? MatchStateComponent else { return }
        self.fieldEntity = fieldEntity

        let newEvents = stateComponent.transitions.filter { $0.date > lastUpdate }
        if let latestUpdate = newEvents.last?.date {
            lastUpdate = latestUpdate
        }
        for event in newEvents {
            os_log(.default, log: GameLog.gameState, "new event %s", "\(event)")
            subject.send(event.state)
        }
    }

    var matchOutputEvents: AnyPublisher<MatchOutput, Never> {
        return subject.eraseToAnyPublisher()
    }
}
