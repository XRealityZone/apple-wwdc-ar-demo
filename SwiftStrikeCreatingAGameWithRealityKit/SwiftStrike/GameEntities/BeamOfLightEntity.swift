/*
See LICENSE folder for this sample’s licensing information.

Abstract:
BeamOfLightEntity.swift
*/

import Combine
import RealityKit

class BeamOfLightEntity: Entity, HasTrigger, HasCollision, HasPlacementIdentifier, LoadedEntity, GameResettable {

    static let waitingName = "_waiting"
    static let readyName = "_ready"

    static let shape = ShapeResource.createCapsule(totalHeight: Constants.beamHeight, radius: Constants.beamWidth)

    static func makeBeamGroup(pipeline: Pipeline, tabletop: Bool) -> AnyPublisher <Entity, Error> {
        var toLoad = [AssetToLoad]()
        toLoad.append(AssetToLoad(for: .startLightsBeam, options: Asset.optionsConditionalCombine(.waiting, tabletop, .tabletop)))
        toLoad.append(AssetToLoad(for: .startLightsBeam, options: Asset.optionsConditionalCombine(.ready, tabletop, .tabletop)))
        return loadEntitiesAsync(toLoad)
        .tryMap { entitiesLoaded in
            guard let waiting = entitiesLoaded[Asset.optionsConditionalCombine(.waiting, tabletop, .tabletop)],
            let ready = entitiesLoaded[Asset.optionsConditionalCombine(.ready, tabletop, .tabletop)] else {
                return Entity(named: "animation_container")
            }
            waiting.name = waitingName
            try pipeline.process(root: waiting)
            ready.name = readyName
            try pipeline.process(root: ready)
            return Entity(named: "animation_container", children: [waiting, ready])
        }
        .eraseToAnyPublisher()
    }

    static func makeGlowGroup(pipeline: Pipeline, tabletop: Bool) -> AnyPublisher <Entity, Error> {
        var toLoad = [AssetToLoad]()
        toLoad.append(AssetToLoad(for: .startLightsGlow, options: .waiting))
        toLoad.append(AssetToLoad(for: .startLightsGlow, options: .ready))
        return loadEntitiesAsync(toLoad)
        .tryMap { entitiesLoaded in
            guard let waiting = entitiesLoaded[.waiting],
            let ready = entitiesLoaded[.ready] else {
                return Entity(named: "glow_group")
            }
            waiting.name = waitingName
            try pipeline.process(root: waiting)
            ready.name = readyName
            try pipeline.process(root: ready)
            return Entity(named: "glow_group", children: [waiting, ready])
        }
        .eraseToAnyPublisher()
    }

    static func loadAsync() -> AnyPublisher<BeamOfLightEntity, Error> {

        let tabletop: Bool = UserSettings.isTableTop
        let pipeline = Pipeline()

        return makeBeamGroup(pipeline: pipeline, tabletop: tabletop)
            .zip(makeGlowGroup(pipeline: pipeline, tabletop: tabletop))
            .map { (beamGroup, glowGroup) -> BeamOfLightEntity in
                let beamOfLight = BeamOfLightEntity()
                if UserSettings.disableBeamsOfLight == false {
                    beamOfLight.children.append(contentsOf: [beamGroup, glowGroup])
                    beamOfLight.state = .waiting
                }
                return beamOfLight
            }
            .eraseToAnyPublisher()
    }

    enum State: Int {
        case waiting
        case ready
    }

    private func enableBeams(named name: String, enable: Bool) {
        forEachInHierarchy { (entity, _) in
            if entity.name == name {
                entity.isEnabled = enable
            }
        }
    }

    var state: State = .waiting {
        didSet {
            switch state {
            case .waiting:
                enableBeams(named: BeamOfLightEntity.waitingName, enable: true)
                enableBeams(named: BeamOfLightEntity.readyName, enable: false)
            case .ready:
                enableBeams(named: BeamOfLightEntity.waitingName, enable: false)
                enableBeams(named: BeamOfLightEntity.readyName, enable: true)
            }
        }
    }

    required init() {
        super.init()
        trigger = TriggerComponent(triggered: false)
        collision = CollisionComponent(shapes: [BeamOfLightEntity.shape], mode: .trigger, filter: .sensor)
    }

    func clone(with team: Team) -> BeamOfLightEntity {
        let clone = self.clone(recursive: true)
        clone.placementIdentifier = PlacementIdentifierComponent(team: team, identifier: 0)
        return clone
    }

    func gameReset() {
        state = .waiting
    }
}
