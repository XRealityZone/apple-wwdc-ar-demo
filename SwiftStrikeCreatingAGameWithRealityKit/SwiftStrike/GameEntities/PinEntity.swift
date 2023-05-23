/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Pin Entity
*/

import Combine
import Foundation
import os.log
import RealityKit

extension GameLog {
    static let pinEntity = OSLog(subsystem: subsystem, category: "pinEntity")
}

extension Team {
    var collisionGroup: CollisionGroup { return self == .teamA ? .pinTeamA : .pinTeamB }
}

final class PinEntity: Entity, LoadedEntity, HasPhysics, HasModel, HasGameAudioComponent,
    HasPlacementIdentifier, HasUprightStatus, HasChildEntitySwitch, GameResettable {

    static let pinUprightDefaultParameters = UprightStatusParameters(
        framesRequiredForStill: 3,
        linearVelocityThreshold: 0.01,
        angularVelocityThreshold: 0.01,
        framesRequiredForUprightNoChange: 3,
        uprightPositionYThreshold: 0.1,
        uprightNormalYThreshold: 0.1,
        belowSurface: -0.01,
        continuousState: false
    )

    static var pinA: Entity!
    static var pinB: Entity!
    static var pinATransparent: Entity!
    static var pinBTransparent: Entity!
    static var pinAUnlit: Entity!
    static var pinBUnlit: Entity!
    static var pinAUnlitTransparent: Entity!
    static var pinBUnlitTransparent: Entity!
    static var pinEntityA: PinEntity!
    static var pinEntityB: PinEntity!

    // PinEntity has two children under renderEntity
    // either one or the other is enabled by the
    // ChildEntitySwitchComponent.
    // For visualMode == .normal
    // these are named "Opaque" and Transparent" so that
    // the blink pin transparent feature can select one or the
    // other.
    // For visualMode == .cosmic
    // these are named "Lit" and "Unlit" so that when the pins
    // fall we can switch models to remove the billboards and
    // see the "lights" on the pins go out
    static let opaqueChildName: String = "Opaque"
    static let transparentChildName: String = "Transparent"
    static let litChildName: String = "Lit"
    static let unlitChildName: String = "Unlit"
    static let unlitTransparentChildName: String = "UnlitTransparent"

    private static var cosmicMode: Bool = false

    private var curAlpha: Float = 1.0

    struct PinState: OptionSet, Hashable {
        var rawValue: UInt
        init(rawValue: UInt) {
            self.rawValue = rawValue
        }
        static let normal = PinState([])
        static let transparent = PinState(rawValue: 1 << 0)
        static let unlit = PinState(rawValue: 1 << 1)
    }
    var pinState = PinState.normal
    static var pinStateToName = [PinState: String]()

    // This entity collects any ModelEntities (and their children) into one node we can animate
    var renderEntity: Entity {
        return children.first!
    }

    static func loadAsync() -> AnyPublisher<(PinEntity, PinEntity), Error> {
        cosmicMode = UserSettings.visualMode == .cosmic
        var pinsToLoad = [AssetToLoad]()

        // first opaque/normal pin models
        pinsToLoad.append(AssetToLoad(for: .pin, options: .teamA))
        pinsToLoad.append(AssetToLoad(for: .pin, options: .teamB))

        // second transparent pin models
        pinsToLoad.append(AssetToLoad(for: .pin, options: [.teamA, .transparent]))
        pinsToLoad.append(AssetToLoad(for: .pin, options: [.teamB, .transparent]))

        // for cosmic mode we need unlit versions for when they fall
        if cosmicMode {
            pinsToLoad.append(AssetToLoad(for: .pin, options: [.teamA, .unlit]))
            pinsToLoad.append(AssetToLoad(for: .pin, options: [.teamB, .unlit]))
            pinsToLoad.append(AssetToLoad(for: .pin, options: [.teamA, .unlit, .transparent]))
            pinsToLoad.append(AssetToLoad(for: .pin, options: [.teamB, .unlit, .transparent]))
        }

        PinEntity.pinStateToName[.normal] = cosmicMode ? litChildName : opaqueChildName
        PinEntity.pinStateToName[.transparent] = transparentChildName
        PinEntity.pinStateToName[.unlit] = unlitChildName
        PinEntity.pinStateToName[[.unlit, .transparent]] = unlitTransparentChildName

        return loadEntitiesAsync(pinsToLoad)
            .map { entitiesLoaded -> (PinEntity, PinEntity) in
                do {
                    let firstChildName = cosmicMode ? litChildName : opaqueChildName
                    self.pinEntityA = PinEntity()
                    self.pinEntityB = PinEntity()
                    self.pinEntityA.addChild(Entity()) // add our renderEntity
                    self.pinEntityB.addChild(Entity())

                    os_log(.default, log: GameLog.preloading, "Pipeline.process() PinA...")
                    self.pinA = PinEntity.process(entity: entitiesLoaded[.teamA],
                                                      name: firstChildName,
                                                      parent: self.pinEntityA,
                                                      team: .teamA)
                    os_log(.default, log: GameLog.preloading, "Pipeline.process() PinB...")
                    self.pinB = PinEntity.process(entity: entitiesLoaded[.teamB],
                                                      name: firstChildName,
                                                      parent: self.pinEntityB,
                                                      team: .teamB)

                    os_log(.default, log: GameLog.preloading, "Pipeline.process() PinA Transparent...")
                    self.pinATransparent = PinEntity.process(entity: entitiesLoaded[[.teamA, .transparent]],
                                                                 name: transparentChildName,
                                                                 parent: self.pinEntityA,
                                                                 team: .teamA)
                    os_log(.default, log: GameLog.preloading, "Pipeline.process() PinB Transparent...")
                    self.pinBTransparent = PinEntity.process(entity: entitiesLoaded[[.teamB, .transparent]],
                                                                 name: transparentChildName,
                                                                 parent: self.pinEntityB,
                                                                 team: .teamB)

                    // cosmic mode has 2 additional models for unlit
                    if entitiesLoaded.count > 4 {
                        self.pinAUnlit = PinEntity.process(entity: entitiesLoaded[[.teamA, .unlit]],
                                                               name: unlitChildName,
                                                               parent: self.pinEntityA,
                                                               team: .teamA)
                        self.pinBUnlit = PinEntity.process(entity: entitiesLoaded[[.teamB, .unlit]],
                                                               name: unlitChildName,
                                                               parent: self.pinEntityB,
                                                               team: .teamB)
                        self.pinAUnlitTransparent = PinEntity.process(entity: entitiesLoaded[[.teamA, .unlit, .transparent]],
                                                                      name: unlitTransparentChildName,
                                                                      parent: self.pinEntityA,
                                                                      team: .teamA)
                        self.pinBUnlitTransparent = PinEntity.process(entity: entitiesLoaded[[.teamB, .unlit, .transparent]],
                                                                      name: unlitTransparentChildName,
                                                                      parent: self.pinEntityB,
                                                                      team: .teamB)
                    }

                    self.pinEntityA.addPinRootComponents([firstChildName, transparentChildName, unlitChildName, unlitTransparentChildName])
                    self.pinEntityB.addPinRootComponents([firstChildName, transparentChildName, unlitChildName, unlitTransparentChildName])

                    self.pinEntityA.pinState = .normal
                    self.pinEntityA.setModelForTransparentAndLit()
                    self.pinEntityB.pinState = .normal
                    self.pinEntityB.setModelForTransparentAndLit()
                    return (self.pinEntityA, self.pinEntityB)
                }
            }
            .tryMap { $0 }  // Never -> Error
            .eraseToAnyPublisher()
    }

    // the pins sit slightly below the floor (-0.004), so if the threshold is 0, the floor glow will always be off.
    static let nameToEntityMap: [NameToEntityEntry] = [
        NameToEntityEntry(name: "floorcard") {
            let entity = FloorBillboardEntity()
            entity.floorBillboard.bias = 0.002
            entity.floorBillboard.floorOffsetThreshold = -0.004
            return entity
        },
        NameToEntityEntry(name: "outlinecard") {
            return YAxisBillboardEntity()
        }
    ]

    private static func process(entity: Entity?,
                                name: String,
                                parent: PinEntity,
                                team: Team) -> Entity? {
        guard let entity = entity else { return nil }
        let pipeline = Pipeline()
        // removeUSDZScaling() is used to change the default scale node added by RealityKit
        // when loading a usdz with no metadata (metersPerUnit).  The default scale in
        // usdz files is cm. so that scale node defaults to 0.01.  SwiftStrike's Pin
        // models were authored, along with their collision meshes, in meter scale.
        // So we change the scale node 0.01 for cm. to 1.0 for m. if needed.
        pipeline.removeUSDZScaling(root: entity)
        pipeline.removeRedundantEntities(root: entity)
        let firstChild = parent.renderEntity.children.isEmpty
        do {
            try pipeline.process(root: entity) { (_, shapes) in
                // only set up the physics and extra parent components once,
                // assuming first child will have the correct collision data
                if firstChild {
                    var collisionMask: CollisionGroup = [.ball, .ground, .wall, .pin]
                    var collisionGroup: CollisionGroup = .pin
                    switch team {
                    case .teamA:
                        collisionGroup.insert(.pinTeamA)
                        collisionMask.insert(.pinTeamA)
                    case .teamB:
                        collisionGroup.insert(.pinTeamB)
                        collisionMask.insert(.pinTeamB)
                    default:
                        fatalError("Unknown team. Pin must be TeamA or TeamB.")
                    }
                    parent.name = "Pin"
                    parent.components[PhysicsBodyComponent.self] = PhysicsBodyComponent.generate(
                        shapes: shapes,
                        mass: PhysicsConstants.pinMass,
                        staticFriction: PhysicsConstants.pinStaticFriction,
                        kineticFriction: PhysicsConstants.pinKineticFriction,
                        restitution: PhysicsConstants.pinRestitution,
                        mode: .dynamic
                    )
                    parent.components[CollisionComponent.self] = CollisionComponent.generate(
                        shapes: shapes,
                        mode: .default,
                        group: collisionGroup,
                        mask: collisionMask
                    )
                }
            }
        } catch {
            os_log(.default, log: GameLog.pinEntity, "PinEntity.process ERROR: %s", "\(error)")
        }

        // we move all children of the entity to a new parent
        // so that we can drop the entity that only contains
        // the scale factor from the usdz load, which is 1.0
        // for pins
        var pinModel: Entity?
        // must create array of children so that while processing the
        // children we can change the parent without affecting the collection
        // we are iterating
        let children: [Entity] = entity.children.compactMap { $0 }
        children.forEach { child in
            child.setParent(parent.renderEntity)
            if child.name.hasPrefix("pin_") {
                assert(pinModel == nil, "more than one child with 'pin_' prefix?!?")
                // only identify the first child name prefixed by "pin_"
                if pinModel == nil {
                    pinModel = child
                }
            }
            child.insertBillboardsIfNeeded(nameToEntityMap: PinEntity.nameToEntityMap, name)
        }
        guard let foundPinModel = pinModel else {
            os_log(.error, log: GameLog.general, "Error: no child in Pin file named 'pin_' to identify Pin model")
            fatalError()
        }
        return foundPinModel
    }

    static func clonePin(pinToClone: PinEntity, origin: Entity, position: SIMD3<Float>, team: Team, id: Int) -> PinEntity {
        let newPin = pinToClone.clone(recursive: true)
        newPin.move(to: float4x4(translation: position), relativeTo: origin)
        newPin.placementIdentifier = PlacementIdentifierComponent(team: team, identifier: id)
        os_log(.default, log: GameLog.gameboard, "PinEntity.clonePin(): memorize %s p=%s, r=%s,%s",
               "\(newPin)",
               "\(newPin.position.terseDescription)",
               "\(newPin.transform.rotation.real)",
               "\(newPin.transform.rotation.imag.terseDescription)")
        newPin.memorizeCurrentTransform()
        return newPin
    }

    static func loadPins(origin: Entity) -> [PinEntity] {
        func generatePinPositions(rows: Int, relativeTo position: SIMD3<Float>) -> [SIMD3<Float>] {
            return generatePinPositions(rows: rows).map {
                return [$0.x + position.x, $0.y + position.y, $0.z + position.z]
            }
        }

        func generatePinPositions(rows: Int) -> [SIMD3<Float>] {
            // bowling pins are laid out:
            //     TeamA (+Z)  TeamB (-Z)
            //     7 8 9 10         1
            //      4 5 6          3 2
            //       2 3          6 5 4
            //        1         10 9 8 7
            var result: [SIMD3<Float>] = []
            let depthPerRow = Constants.pinSpacing / cos(.pi / 20)
            for rowNum in 0 ..< rows {
                let rowHorizontal = Float(rowNum) * Constants.pinSpacing / 2
                let rowDepth = depthPerRow * Float(rowNum)
                let rowOrigin = SIMD3<Float>(rowHorizontal, 0.0, rowDepth)
                for pinNum in 0 ... rowNum {
                    result.append(rowOrigin - SIMD3<Float>(Float(pinNum) * Constants.pinSpacing, 0, 0))
                }
            }
            return result
        }
        let pinPositions = generatePinPositions(rows: Constants.pinRows,
                                                relativeTo: SIMD3<Float>(0, Constants.pinMagicYOffset, Constants.deckOrigin))

        os_log(.default, log: GameLog.gameboard, "Board origin: %s", "\(origin.position(relativeTo: GamePlayManager.physicsOrigin).terseDescription)")
        var pins = clonePins(of: pinEntityA, for: .teamA, at: pinPositions, relativeTo: origin)
        pins += clonePins(of: pinEntityB, for: .teamB, at: pinPositions, relativeTo: origin)

        return pins
    }

    static func clonePins(of pinEntity: PinEntity, for team: Team, at positions: [SIMD3<Float>], relativeTo origin: Entity) -> [PinEntity] {
        // assign indices 1 to 10 to the pin positions
        let ids = 1...10
        let zSign = team.zSign
        let pinLocations = zip(positions.map {
            return SIMD3<Float>(zSign * $0.x, $0.y, zSign * $0.z)
        }, ids)
        let pins: [PinEntity] = pinLocations.map { (position, id) in
            let clone = clonePin(pinToClone: pinEntity, origin: origin, position: position, team: team, id: id)
            os_log(.default, log: GameLog.gameboard, "%s: %s", "\(clone)", "\(position.terseDescription)")
            return clone
        }
        return pins
    }

    static func selectPinSoundVariant(_ entity: Entity, _ impactPosition: SIMD3<Float>) -> String? {
        guard let pinEntity = entity as? PinEntity else {
            return nil
        }
        let bounds = pinEntity.visualBounds(recursive: true, relativeTo: nil, excludeInactive: true)
        let middle = (bounds.min.y + bounds.max.y) / 2.0

        if impactPosition.y < middle {
            return "Bottom"
        } else {
            return "Top"
        }
    }

    func physicsReset() {
        physicsMotion?.angularVelocity = .zero
        physicsMotion?.linearVelocity = .zero
        restoreToMemorizedTransform()
        resetPhysicsTransform(recursive: true)
    }

    func gameReset() {
        physicsReset()
        uprightStatus.reset()
        pinState = .normal
        setModelForTransparentAndLit()

        isEnabled = true
    }

    /// - Tag: AddPinRootComponents
    private func addPinRootComponents(_ childNames: [String]) {
        physicsMotion = PhysicsMotionComponent()
        childEntitySwitch.childEntityNamesList = childNames
        audio = GameAudioComponent.load(named: "pin-audio")
        uprightStatus = UprightStatusComponent()
    }

    private func setModelForTransparentAndLit() {
        if let activeName = PinEntity.pinStateToName[pinState] {
            enableChildrenEntities(named: activeName)
        }
    }

    func setLit(_ lit: Bool) {
        let unlit = !lit
        guard pinState.contains(.unlit) != unlit else { return }
        if unlit {
            pinState.insert(.unlit)
        } else {
            pinState.remove(.unlit)
        }
        setModelForTransparentAndLit()
    }

    func setTransparent(_ transparent: Bool) {
        guard pinState.contains(.transparent) != transparent else { return }
        if transparent {
            pinState.insert(.transparent)
        } else {
            pinState.remove(.transparent)
        }
        setModelForTransparentAndLit()
    }

}

extension PinEntity: CustomStringConvertible {
    var description: String {
        return name + "-\(placementTeam)" + "-\(placementID)"
    }
}

extension PinEntity: UprightCoordinatorUpdateDelegate {

    func tickUprightStatus() -> UprightStatusTickResult {
        if !uprightStatus.isDone {
            let result = uprightStatus.tick(self, parameters: PinEntity.pinUprightDefaultParameters)
            // make pin lights go out when pin is "down" (for Cosmic Mode)
            if result == .updatedAndChanged {
                setLit(upright)
            }
            return result
        }
        return .notUpdated
    }

}
