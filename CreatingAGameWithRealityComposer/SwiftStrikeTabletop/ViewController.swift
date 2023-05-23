/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The sample app's main view controller.
*/

import UIKit
import ARKit
import RealityKit
import simd
import Combine

class ViewController: UIViewController {
    
    /// The app's root view.
    @IBOutlet var arView: ARView!
    
    /// A button that enables the user to step through different game states.
    @IBOutlet weak var gameActionButton: GameActionButton!
    
    /// A view that instructs the user's movement during session initialization.
    @IBOutlet weak var coachingOverlay: ARCoachingOverlayView!
    
    /// An image view displayed when the user is not playing the game.
    @IBOutlet weak var menuImageView: UIImageView!
    
    /// The app's main view.
    @IBOutlet var overlayView: OverlayView!

    /// The game controller, which manages game state.
    var gameController: Experience.GameController!
    
    /// An entity gesture recognizer that translates swipe movements to ball velocity.
    var gestureRecognizer: EntityTranslationGestureRecognizer?
    
    /// The world location at which the current translate gesture began.
    var gestureStartLocation: SIMD3<Float>?

    /// Storage for collision event streams
    var collisionEventStreams = [AnyCancellable]()

    deinit {
        collisionEventStreams.removeAll()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Configure the AR session for horizontal plane tracking.
        let arConfiguration = ARWorldTrackingConfiguration()
        arConfiguration.planeDetection = .horizontal
        arView.session.run(arConfiguration)
        
        // Initialize the game controller, which begins the game.
        gameController = Experience.GameController(observer: self)
        gameController.begin()
    }

    /// Displays the end-level graphics.
    func showWinState() {
        if gameController.currentLevel == gameController.settings.numberOfLevels - 1 {
            gameActionButton.gameAction = .tapToPlay
            menuImageView.isHidden = false
        } else {
            gameActionButton.gameAction = .nextLevel
        }
    }
    
    /// Begins the coaching process that instructs the user's movement during
    /// ARKit's session initialization.
    func presentCoachingOverlay() {
        coachingOverlay.session = arView.session
        coachingOverlay.delegate = self
        coachingOverlay.goal = .horizontalPlane
        coachingOverlay.activatesAutomatically = false
        self.coachingOverlay.setActive(true, animated: true)
    }

    /// Updates the game state when the user taps the game state button.
    @IBAction func gameActionButtonPressed(_ gameActionButton: GameActionButton) {

        switch gameActionButton.gameAction {

        case .tapToPlay:

            menuImageView.isHidden = true
            gameActionButton.isHidden = true
            gameActionButton.gameAction = .retry
            
            if gameController.currentLevel == 0 {
                gameController.playerReadyToBeginPlay()
            } else {
                gameController.currentLevel = 0
                gameController.playerReadyToBowlFrame()
            }

        case .retry:

            gameActionButton.isHidden = true
            gameActionButton.gameAction = .retry

            // If we have loaded the game and we transitioning to a new level or trying again, then save the anchor identifier.
            if gameController.gameAnchor != nil {
                let anchorEntity = gameController.gameAnchor.children.first as? AnchorEntity
                let anchorPlacement = Experience.AnchorPlacement(arAnchorIdentifier: anchorEntity?.anchorIdentifier,
                                                                 placementTransform: anchorEntity?.transform)
                gameController.anchorPlacement = anchorPlacement
            }

            gameController.playerReadyToBowlFrame()

        case .nextLevel:
            
            gameActionButton.isHidden = true
            gameActionButton.gameAction = .retry

            gameController.advancePlayerLevel()
        }
    }

    func restart(_ game: Experience.Game) {
        self.displayCurrentLevelOverlay()
        
        gestureRecognizer?.isEnabled = true
        game.toHideOnStart.forEach { $0?.isEnabled = false }

        self.gameController.setupDisplayLevelObstacles()
        self.gameController.pinsInPlay = game.allPins.compactMap { $0 }

        game.backGuard?.isEnabled = false
    }

    /// Restarts the game at the current game level.
    func resetCurrentGameLevel() {
        guard let game = gameController.gameAnchor else { return }
        
        restart(game)
        game.notifications.restart.post()
    }

    /// Displays an overlay with an image showing the current level with a subsequent  instruction overlay for the first game.
    func displayCurrentLevelOverlay() {
        overlayView.isHidden = false
        overlayView.alpha = 0.0
        
        let levelImageName = "Level" + String(gameController.currentLevel + 1)
        if gameController.currentLevel == 0 && !gameController.presentedInstructions {
            gameController.presentedInstructions = true
            displayOverlay(imageName: levelImageName) {
                self.displayOverlay(imageName: "SwipeUp")
            }
        } else {
            displayOverlay(imageName: levelImageName)
        }
    }

    /// Displays an overlay with the given image with options for a completion to be called when the overlay disappears.
    func displayOverlay(imageName: String, delay: TimeInterval = 0.5, completion: @escaping () -> Void = { }) {

        self.overlayView.imageView.image = UIImage(named: imageName)

        UIView.animate(withDuration: gameController.settings.uiAnimationDuration) {
            self.overlayView.alpha = 1.0
            
            UIView.animate(withDuration: self.gameController.settings.uiAnimationDuration, delay: delay, options: [], animations: {
                self.overlayView.alpha = 0.0
            }, completion: { _ in
                completion()
            })
        }
    }
    
    @objc
    func handleTranslation(_ recognizer: EntityTranslationGestureRecognizer) {
        
        guard let ball = gameController.ball else { return }
        let settings = gameController.settings
        
        if recognizer.state == .ended || recognizer.state == .cancelled {
            
            // Disable the gesture recognizer and return to dynamic physics so that any in-motion physics movements continue to play.
            recognizer.isEnabled = false
            gestureStartLocation = nil
            ball.physicsBody?.mode = .dynamic
            gameController.gameAnchor.backGuard?.isEnabled = true
            gameController.playerBowled()
            
            return
        }
        
        // Store the touch location and don't process velocity if this is the first touch.
        guard let gestureCurrentLocation = recognizer.translation(in: nil) else { return }
        guard let gestureStartLocation = self.gestureStartLocation else {
            self.gestureStartLocation = gestureCurrentLocation
            return
        }
        
        // Calculate the gesture's current distance from its physical start location in the real world.
        let delta = gestureStartLocation - gestureCurrentLocation
        let distance = ((delta.x * delta.x) + (delta.y * delta.y) + (delta.z * delta.z)).squareRoot()
        
        // If the current gesture location has moved more than 0.5m from where the gesture started, ignore any
        // further translation from this gesture, and return to dynamic physics to play out the remaining motion.
        if distance > settings.ballPlayDistanceThreshold {
            self.gestureStartLocation = nil
            ball.physicsBody?.mode = .dynamic
            return
        }
        
        // Set the current physics body movement mode to kinetic since the gesture is still active, and
        // update the ball's velocity to match the velocity of the gesture in the real world.
        ball.physicsBody?.mode = .kinematic
        let realVelocity = recognizer.velocity(in: nil)
        let ballParentVelocity = ball.parent!.convert(direction: realVelocity, from: nil)
        var clampedX = ballParentVelocity.x
        var clampedZ = ballParentVelocity.z
        
        // Clamp the x velocity to not move the ball too far to the left or right.
        if clampedX > settings.ballVelocityMaxX {
            clampedX = settings.ballVelocityMaxX
        } else if clampedX < settings.ballVelocityMinX {
            clampedX = settings.ballVelocityMinX
        }
        
        // Clamp the z velocity towards the pins in the negative z direction only.
        if clampedZ > settings.ballVelocityMaxZ {
            clampedZ = settings.ballVelocityMaxZ
        } else if clampedZ < settings.ballVelocityMinZ {
            clampedZ = settings.ballVelocityMinZ
        }
        let clampedVelocity: SIMD3<Float> = [clampedX, 0.0, clampedZ]
        ball.physicsMotion?.linearVelocity = clampedVelocity
    }

}

/// An extension that observes GameController changes, and updates the ViewController state.
extension ViewController: GameControllerObserver {
    func gameControllerContentDidLoad(_ gameController: Experience.GameController) {
        gameController.pinsInPlay.removeAll()
        arView.scene.anchors.removeAll()
        
        guard let game = gameController.gameAnchor else { return }

        // Disabling the synchronization of entities to reduce the memory
        // consumption (since this is a single-player experience).
        game.visit {
            $0.synchronization = nil
        }
                
        // Disable physics until RealityKit places the scene on a horizontal plane.
        var originalPhysicsModes: [Entity: PhysicsBodyMode] = [:]
        game.visit { entity in
            if let physicsEntity = entity as? Entity & HasPhysics {
                originalPhysicsModes[entity] = physicsEntity.physicsBody?.mode
                physicsEntity.physicsBody?.mode = .static
            }
        }
        
        // Reenable physics after RealityKit places the scene on a horizontal plane.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            game.visit { entity in
                if let physicsEntity = entity as? Entity & HasPhysics,
                    let originalMode = originalPhysicsModes[entity] {
                    physicsEntity.physicsBody?.mode = originalMode
                }
            }
        }
        
        // Remove the mesh component on the game's guards to keep collision shapes, but not render anything.
        game.guards?.visit { entity in
            entity.components[ModelComponent.self] = nil
        }
        
        game.backGuard?.visit { entity in
            entity.components[ModelComponent.self] = nil
        }
        
        // Apply the previous anchor placement properties
        if let anchorPlacement = self.gameController.anchorPlacement {
            
            if let anchorIdentifier = anchorPlacement.arAnchorIdentifier {
                game.anchoring = AnchoringComponent(.anchor(identifier: anchorIdentifier))
            }
            
            if let transform = anchorPlacement.placementTransform {
                game.transform = transform
            }
        } else {
            game.anchoring = AnchoringComponent(.plane(.horizontal, classification: .any, minimumBounds: SIMD2<Float>(0, 0)))
        }
        
        if let ball = game.ball as? Entity & HasCollision {
            let gestureRecognizers = self.arView.installGestures([.translation], for: ball)
            if let gestureRecognizer = gestureRecognizers.first as? EntityTranslationGestureRecognizer {
                
                self.gestureRecognizer = gestureRecognizer
                
                // Disable default translation.
                gestureRecognizer.removeTarget(nil, action: nil)
                
                // Add an alternative gesture handler that applies a linear velocity to the ball.
                gestureRecognizer.addTarget(self, action: #selector(self.handleTranslation))
            }
        }
    }
    
    func gameControllerReadyForPlayer(_ gameController: Experience.GameController) {
        menuImageView.isHidden = false
        gameActionButton.gameAction = .tapToPlay
        gameActionButton.isHidden = false
    }

    func gameControllerReadyForContentPlacement(_ gameController: Experience.GameController) {
        // Prevent power idle during coaching (coaching phase may take a while and typically expects no touch events)
        UIApplication.shared.isIdleTimerDisabled = true

        presentCoachingOverlay()
    }
    
    func gameController(_ gameController: Experience.GameController, readyForPlayerToBowlGame gameNumber: Int) {
        guard let game = gameController.gameAnchor else { return }
        
        // Prevent power idle during active gameplay
        UIApplication.shared.isIdleTimerDisabled = true
        
        gameActionButton.isHidden = true
        if gameNumber == 1 {
            arView.scene.addAnchor(game)
            
            // Subscribe to collision events and send them to the GameController
            arView.scene.subscribe(to: CollisionEvents.Began.self) { event in
                gameController.collisionChange(first: event.entityA, second: event.entityB)
            }.store(in: &collisionEventStreams)
            arView.scene.subscribe(to: CollisionEvents.Updated.self) { event in
                gameController.collisionChange(first: event.entityA, second: event.entityB)
            }.store(in: &collisionEventStreams)
            arView.scene.subscribe(to: CollisionEvents.Ended.self) { event in
                gameController.collisionChange(first: event.entityA, second: event.entityB)
            }.store(in: &collisionEventStreams)
        }
        
        resetCurrentGameLevel()
    }
    
    func gameController(_ gameController: Experience.GameController, completedBowlingFrameWithStruckPins struckPinCount: Int) {
        if gameController.playerStruckSufficientPins(striking: struckPinCount) {
            showWinState()
        }
        gameActionButton.isHidden = false
        
        // Resume idle while waiting for next action from player
        UIApplication.shared.isIdleTimerDisabled = false
    }
}

extension Entity {
    func visit(using block: (Entity) -> Void) {
        block(self)

        for child in children {
            child.visit(using: block)
        }
    }
}
