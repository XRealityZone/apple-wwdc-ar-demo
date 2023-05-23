/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Main View Controller
*/

import UIKit
import RealityKit
import Accessibility
import Combine

class ViewController: UIViewController, UIGestureRecognizerDelegate {
    
    // MARK: - Outlets & Actions -
    
    @IBOutlet var arView: ARView!
    
    /// Resets the scene to starting positions without reloading the scene.
    @IBAction func tappedResetButton(_ sender: Any) {
        // Disable each physics entity before setting transform to avoid
        // physics simulation instability, re-enabling after transforms have been.
        
        // Because movableEntities is an array of arrays, this uses a flatmap to
        // iterate through all the individual entities
        movableEntities.flatMap { $0 }.forEach { $0.isEnabled = false }
        setInitialTransforms()
        movableEntities.flatMap { $0 }.forEach { $0.isEnabled = true }
    }
    
    /// Allow user to toggle RealityKit debug drawing of physics-related invisible objects.
    @IBAction func toggleDebugDrawing(_ sender: UIButton) {
        if arView.debugOptions.contains(.showPhysics) {
            sender.setTitle("Enable Debug", for: .normal)
            arView.debugOptions.remove(.showPhysics)
        } else {
            sender.setTitle("Disable Debug", for: .normal)
            arView.debugOptions.insert(.showPhysics)
        }
    }
    
    // MARK: - Properties -

    let cube1 = BoxEntity(size: 0.05, color: .green, roughness: 0.0)
    let cube2 = BoxEntity(size: 0.05, color: .green, roughness: 0.0)
    let cube3 = BoxEntity(size: 0.05, color: .green, roughness: 0.0)
    
    let sphere1 = SphereEntity(size: 0.05, color: .orange, roughness: 1.0)
    let sphere2 = SphereEntity(size: 0.05, color: .orange, roughness: 1.0)
    let sphere3 = SphereEntity(size: 0.05, color: .orange, roughness: 1.0)
    
    let beveledCube1 = BeveledBoxEntity(size: 0.05, color: .blue, roughness: 0.5)
    let beveledCube2 = BeveledBoxEntity(size: 0.05, color: .blue, roughness: 0.5)
    let beveledCube3 = BeveledBoxEntity(size: 0.05, color: .blue, roughness: 0.5)
    
    let plane = PlaneEntity()
    
    // This array of arrays controls both which movable entities are shown
    // in the scene as well as their relative layout. Each sub-array represents
    // one row of objects
    var movableEntities: [[MovableEntity]]!
    
    // Used to hold Combine subscriptions used for detecting collisions
    var collisionSubscriptions: [Cancellable] = []
    
    // MARK: - UIViewController Overrides -
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Define the layout of the movable entities.
        //  - 1 row of 3 cubes
        //  - 1 row of 3 beveled cubes
        //  - 1 row of 3 spheres
        movableEntities = [ [cube1, cube2, cube3],
                            [beveledCube1, beveledCube2, beveledCube3],
                            [sphere1, sphere2, sphere3] ]
        configureEntityAccessibility()
        
        setInitialTransforms()
        setCollisionFilters()
        setScene()
        setGestures()
        subscribeToCollisions()
    }
    
    // MARK: - Scene Setup -
    
    /// Moves all entities to their starting positions. Uses the array of arrays to guide layout placement.
    fileprivate func setInitialTransforms() {

        setPhysicsModeAll(mode: .static)
        for (groupIndex, entityGroup) in movableEntities.enumerated() {
            for (entityIndex, entity) in entityGroup.enumerated() {
                let transform = Transform(scale: .one,
                                          rotation: .init(),
                                          translation: SIMD3<Float>(Float(entityIndex) * entity.size * 3,
                                                                    entity.size,
                                                                    Float(groupIndex) * entity.size * 3) )
                
                entity.move(to: transform, relativeTo: entity.parent)
            }
        }
        setPhysicsModeAll(mode: .dynamic)
        
    }
    
    /// Loops through all movable entities in the scene and changes their physcs mode to specified value
    fileprivate func setPhysicsModeAll(mode: PhysicsBodyMode) {
        for entity in movableEntities.flatMap({ $0 }) {
            entity.setPhysicsBodyMode(to: mode)
        }
    }
    
    /// Sets up the collision filters for the movable entities
    fileprivate func setCollisionFilters() {
        // Define four CollsionGroups using different bitmask values
        // - Tag: CreateCollisionGroups
        let planeGroup = CollisionGroup(rawValue: 1 << 0)
        let cubeGroup = CollisionGroup(rawValue: 1 << 1)
        let beveledCubeGroup = CollisionGroup(rawValue: 1 << 2)
        let sphereGroup = CollisionGroup(rawValue: 1 << 3)
        
        // Entities that have this filter will be able to collide with any
        // object that's not a cube (unbeveled). The `.all` property has all
        // flags set, so using `.all.subtracting` gives a filter that collides
        // with everything except the subtracted group
        // - Tag: CreateCollisionFilter
        let cubeMask = CollisionGroup.all.subtracting(cubeGroup)
        let cubeFilter = CollisionFilter(group: cubeGroup,
                                         mask: cubeMask)
        
        // Entities that have this filter will belong to the planeGroup, and
        // will be able to collide with any other group.
        let planeFilter = CollisionFilter(group: planeGroup, mask: .all)
        
        // Entities that have this filter will be able to collide with any
        // entity except a beveled cube
        let beveledCubeMask = CollisionGroup.all.subtracting(beveledCubeGroup)
        let beveledCubeFilter = CollisionFilter(group: beveledCubeGroup,
                                                mask: beveledCubeMask)
        
        // Entities that have this filter will be able to collide with any
        // entity except a sphere
        let sphereFilter = CollisionFilter(group: sphereGroup,
                                           mask: CollisionGroup.all.subtracting(sphereGroup))
        
        // Cubes ignore other cubes, but collide with beveled cubes and spheres
        // - Tag: AssignCollisionFilters
        cube1.collision?.filter = cubeFilter
        cube2.collision?.filter = cubeFilter
        cube3.collision?.filter = cubeFilter
        
        // Beveled cubes ignore other beveled cubes, but collide with cubes
        // and spheres
        beveledCube1.collision?.filter = beveledCubeFilter
        beveledCube2.collision?.filter = beveledCubeFilter
        beveledCube3.collision?.filter = beveledCubeFilter
        
        // Spheres ignore other spheres, but collide with cubes and beveled cubes
        sphere1.collision?.filter = sphereFilter
        sphere2.collision?.filter = sphereFilter
        sphere3.collision?.filter = sphereFilter
        
        // The ground plane collides with everything
        plane.collision?.filter = planeFilter
    }
    
    /// Configure entities so they work with assistive technologies like VoiceOver
    fileprivate func configureEntityAccessibility() {
        
        // The properties `accessibilityLabel` and `accessibilityDescription`
        // are not available prior to iOS 14, so only set them when running on
        // that release or later.  In addition to setting the label
        // and description, the `isAccessibilityElement` property needs to be
        // `true` in order for the entity to be available in VoiceOver.
        if #available(iOS 14.0, *) {
            let cubeLabel = "green cube"
            let cubeDescription = "A green metallic cube that can be moved."
            cube1.isAccessibilityElement = true
            cube1.accessibilityLabel = cubeLabel
            cube1.accessibilityDescription = cubeDescription
            
            cube2.isAccessibilityElement = true
            cube2.accessibilityLabel = cubeLabel
            cube2.accessibilityDescription = cubeDescription
            cube3.isAccessibilityElement = true
            cube3.accessibilityLabel = cubeLabel
            cube3.accessibilityDescription = cubeDescription
            
            let beveledCubeLabel = "blue beveled cube"
            let beveledCubeDescription = "A blue cube with beveled corners that can be moved."
            beveledCube1.isAccessibilityElement = true
            beveledCube1.accessibilityLabel = beveledCubeLabel
            beveledCube1.accessibilityDescription = beveledCubeDescription
            beveledCube2.isAccessibilityElement = true
            beveledCube2.accessibilityLabel = beveledCubeLabel
            beveledCube2.accessibilityDescription = beveledCubeDescription
            beveledCube3.isAccessibilityElement = true
            beveledCube3.accessibilityLabel = beveledCubeLabel
            beveledCube3.accessibilityDescription = beveledCubeDescription
            
            let sphereLabel = "red sphere"
            let sphereDescription = "A red sphere that can be moved"
            sphere1.isAccessibilityElement = true
            sphere1.accessibilityLabel = sphereLabel
            sphere1.accessibilityDescription = sphereDescription
            sphere2.isAccessibilityElement = true
            sphere2.accessibilityLabel = sphereLabel
            sphere2.accessibilityDescription = sphereDescription
            sphere3.isAccessibilityElement = true
            sphere3.accessibilityLabel = sphereLabel
            sphere3.accessibilityDescription = sphereDescription
        }
    }
    
    /// Add Entities to the scene
    fileprivate func setScene() {
        
        let planeAnchor = AnchorEntity(plane: .horizontal)
        planeAnchor.addChild(plane)
        
        movableEntities.flatMap({ $0 }).forEach {
            plane.addChild($0)
            let entityGestures = arView.installGestures(for: $0)
            entityGestures.forEach { $0.delegate = self }
        }
        
        arView.scene.addAnchor(planeAnchor)
    }
    
    /// Subscribe to collision events for all of the movable entities
    fileprivate func subscribeToCollisions() {
        if #available(iOS 14.0, *) {
            
            movableEntities.flatMap({ $0 }).forEach {
                collisionSubscriptions.append(arView.scene.subscribe(to: CollisionEvents.Began.self, on: $0) { event in
                    guard let entity = event.entityA as? MovableEntity, let otherEntity = event.entityB as? MovableEntity else {
                        return
                    }
                    // If a movable entity collided with another movable entity,
                    // RealityKit won't automatically announce that, so
                    // manually generate a VoiceOver notification.
                    let announce = ("\(entity.accessibilityLabel ?? "Entity") collided with \(otherEntity.accessibilityLabel ?? "Entity")")
                    UIAccessibility.post(notification: .announcement, argument: announce)
                })
            }
        }
    }
    
    // MARK: - Gestures -
    
    /// Sets up the pan gesture recognizer used to move entities
    fileprivate func setGestures() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))
        panGesture.delegate = self
        arView.addGestureRecognizer(panGesture)
    }
    
    /// Delegate method called by the pan gesture recognizer
    @objc
    func panned(_ sender: UIPanGestureRecognizer) {

        switch sender.state {
            case .ended, .cancelled, .failed:
                // When a pan gesture ends for any reason, all entities will
                // return to being dynamic physics bodies
                movableEntities.flatMap { $0 }.forEach { $0.setPhysicsBodyMode(to: .dynamic) }
                
                // Have VoiceOver announce when dragging has ended.
                if #available(iOS 14.0, *) {
                    let announce = "Dragging ended."
                    UIAccessibility.post(notification: .announcement, argument: announce)
                }
            default:
                return
        }
    }
    
    /// Needed for the sample project’s custom pan gesture recognizer to work. RealityKit installs its own
    /// gesture recognizer (EntityGestureRecognizers.) behind the scenes. This project’s gesture recognizer
    /// needs to co-exist and run simultaneously with that one. Returning true allows them to both run together.

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {

        true
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Turn the gesture recognizer's associated entity into a kinematic
        //physics body, which allows the user to manipulate its position.
        guard let translationGesture = gestureRecognizer as? EntityTranslationGestureRecognizer,
            let entity = translationGesture.entity as? MovableEntity else { return true }
        entity.physicsBody?.mode = .kinematic
        
        // RealityKit automatically generate some VoiceOver events for
        // accessibility entities. This code supplements those with custom
        // VoiceOver notifications to give the user more feedback. This
        // notification tells the user when they've started dragging an element.
        //
        // Because this is only available on iOS 14 and later, the code uses
        // an availability check
        if #available(iOS 14.0, *) {
            if UIAccessibility.isVoiceOverRunning {
                let announce = "Dragging \(entity.accessibilityLabel ?? "entity")"
                UIAccessibility.post(notification: .announcement, argument: announce)
            }
        }

        return true
    }
}
