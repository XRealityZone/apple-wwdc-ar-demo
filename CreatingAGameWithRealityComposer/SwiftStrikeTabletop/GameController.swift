/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Ths sample app's game logic.
*/

import Foundation
import RealityKit
import simd

protocol GameControllerObserver: AnyObject {
    /// Called when the game controller's gameAnchor content finishes loading.
    func gameControllerContentDidLoad(_ gameController: Experience.GameController)
    
    /// Called when the game controller is ready for the player to interact with the game (e.g. when it is time to show a menu).
    func gameControllerReadyForPlayer(_ gameController: Experience.GameController)
    
    /// Called when the game controller is ready for the player to locate a suitable real-world surface on which to play.
    func gameControllerReadyForContentPlacement(_ gameController: Experience.GameController)
    
    /// Called when the game controller is ready for the player to attempt a bowling frame (i.e. main game play).
    func gameController(_ gameController: Experience.GameController, readyForPlayerToBowlGame gameNumber: Int)
    
    /// Called when the game controller detects that the player has completed a bowling frame.
    func gameController(_ gameController: Experience.GameController, completedBowlingFrameWithStruckPins struckPinCount: Int)
}

extension Experience {

    public struct AnchorPlacement {

        /// The identifier of the anchor the game is placed on. Used to re-localized the game between levels.
        var arAnchorIdentifier: UUID?

        /// The transform of the anchor the game is placed on . Used to re-localize the game between levels.
        var placementTransform: Transform?

    }

    class GameController {
        indirect enum State: Equatable {
            /// The initial state, which immediately transitions to appStart.
            case begin
            
            /// The app has started but has not yet displayed the game menu.
            case appStart
            
            /// The app is displaying the game menu.
            case menu
            
            /// The player is attempting to locate a playable real-world surface.
            case placingContent
            
            /// Game content is loading and the app is waiting for the load to complete before transitioning to the next state.
            case waitingForContent(nextState: State)
            
            /// The game is ready for the player to attempt a bowling frame.
            case readyToBowl
            
            /// The player has bowled and the ball is moving.
            case ballInMotion
            
            /// The ball has come to a stop.
            case ballAtRest
            
            /// The frame has completed with the given number of pins struck by the ball.
            case frameComplete(struckPinCount: Int)
        }

        /// A series of constants that control aspects of game behavior.
        let settings = GameSettings()
        
        /// The app's Reality File anchored scene (from Reality Composer).
        var gameAnchor: Experience.Game!
        
        /// An array of the level's pins.
        var pinsInPlay = [Entity]()
        
        /// The number of the level the user is currently playing.
        var currentLevel = 0
        
        /// A flag tracking whether the game has presented basic instruction to the player.
        var presentedInstructions = false

        var anchorPlacement: Experience.AnchorPlacement?
        
        /// The ball, cast as a physics entity.
        var ball: (Entity & HasPhysics)? {
            gameAnchor?.ball as? Entity & HasPhysics
        }
        
        /// The current state of the game.
        private var currentState: State
        
        /// The current game number (monotonically increases with each frame).
        private var gameNumber = 0
        
        /// The object that observes our events.
        private weak var observer: GameControllerObserver?
        
        init(observer: GameControllerObserver) {
            currentState = .begin
            self.observer = observer
        }
        
        /// Begins the game from application launch.
        func begin() {
            transition(to: .appStart)
        }
        
        /// Informs the game controller that the player is ready to play the game.
        func playerReadyToBeginPlay() {
            transition(to: .placingContent)
        }
        
        /// Informs the game controller that the player is ready to bowl a frame.
        func playerReadyToBowlFrame() {
            transition(to: .readyToBowl)
        }
        
        /// Informs the game controller that the player has moved the ball.
        func playerBowled() {
            let currentGame = gameNumber
            DispatchQueue.main.asyncAfter(deadline: .now() + settings.stuckFrameDelay) {
                guard currentGame == self.gameNumber else { return }
                
                // Assume we lost the ball and end the frame right now
                self.completeBowlingFrame()
            }

            transition(to: .ballInMotion)
        }
        
        /// Shows the appropriate obstables for the current game level.
        func setupDisplayLevelObstacles() {
            gameAnchor.actions.displayLevelObstacles.onAction = { _ in
                let notification = self.gameAnchor.notifications.allNotifications.first {
                    $0.identifier.hasPrefix("Reveal Level \(self.currentLevel + 1)")
                }
                notification?.post()
            }
        }
        
        /// Informs the game controller that a physics collision or update has occurred between two entities in the scene.
        func collisionChange(first entityA: Entity, second entityB: Entity) {
            guard currentState.activeBowlingFrame else { return }
            
            /// Checks if any pins have fallen over.
            func entityIsInPlayAndHasFallenOver(_ entity: Entity) -> Bool {
                
                // Count a pin that's nearly fallen over as tipped to account for situations where a
                // fallen isn't quite horizontal because it's resting on another pin.
                if pinsInPlay.contains(entity), entity.convert(normal: [0, 1, 0], to: nil).y < settings.pinTipThreshold {
                    pinsInPlay.removeAll { $0 == entity }
                    return true
                } else {
                    return false
                }
            }
            
            let aPinFellOver = entityIsInPlayAndHasFallenOver(entityA) || entityIsInPlayAndHasFallenOver(entityB)
            
            if aPinFellOver && playerStruckSufficientPins(striking: gameAnchor.allPins.count - pinsInPlay.count) {
                completeBowlingFrame()
            } else if currentState == .ballInMotion {
                let velocity = ball?.physicsMotion?.linearVelocity ?? [0, 0, 0]
                if simd_norm_inf(velocity) < 0.01 {
                    transition(to: .ballAtRest)
                }
            }
        }
        
        /// Moves the player to the next level and begins another frame.
        func advancePlayerLevel() {
            currentLevel += 1
            if currentLevel < settings.numberOfLevels {
                playerReadyToBowlFrame()
            }
        }
        
        /// Determines whether the player has knocked over enough pins
        func playerStruckSufficientPins(striking struckPins: Int) -> Bool {
            return struckPins >= settings.goodFrameThreshold
        }
        
        /// Completes a frame and determines struck pins.
        private func completeBowlingFrame() {
            guard currentState.activeBowlingFrame else { return }
            
            let struckPins = gameAnchor.allPins.count - pinsInPlay.count
            if playerStruckSufficientPins(striking: struckPins) {
                playerWillAdvanceToNextLevel(playerBowledStrike: struckPins == gameAnchor.allPins.count)
            }
            
            self.transition(to: .frameComplete(struckPinCount: struckPins))
        }
        
        /// Called when the game level will advance.
        private func playerWillAdvanceToNextLevel(playerBowledStrike: Bool) {
            func levelCompletionNotification(for level: Int) -> NotificationTrigger? {
                switch level + 1 {
                case 4: return gameAnchor.notifications.winnerDisplay
                default:
                    return nil
                }
            }
            
            levelCompletionNotification(for: currentLevel)?.post()

            // Show the winner animation on the last level
            if currentLevel == settings.numberOfLevels - 1 {
                gameAnchor.notifications.playWinnerAnim.post()
            }
        }
        /// Causes a state transition.
        private func transition(to state: State) {
            guard state != currentState else { return }
            
            func transitionToAppStart() {
                Experience.loadGameAsync { [weak self] result in
                    switch result {
                    case .success(let game):
                        guard let self = self else { return }
                        
                        if self.gameAnchor == nil {
                            self.gameAnchor = game
                            self.observer?.gameControllerContentDidLoad(self)
                        }
                        
                        if case let .waitingForContent(nextState) = self.currentState {
                            self.transition(to: nextState)
                        }
                    case .failure(let error):
                        print("Unable to load the game with error: \(error.localizedDescription)")
                    }
                }
                
                transition(to: .menu)
            }
            
            func transitionToMenu() {
                observer?.gameControllerReadyForPlayer(self)
            }
            
            func transitionToPlacingContent() {
                observer?.gameControllerReadyForContentPlacement(self)
            }
            
            func transitionToReadyToBowl() {
                gameNumber += 1
                if gameAnchor == nil {
                    transition(to: .waitingForContent(nextState: .readyToBowl))
                } else {
                    observer?.gameController(self, readyForPlayerToBowlGame: gameNumber)
                }
            }
            
            func transitionToBallAtRest() {
                let currentGame = gameNumber
                DispatchQueue.main.asyncAfter(deadline: .now() + settings.frameSettleDelay) {
                    guard currentGame == self.gameNumber else { return }
                    
                    // It's been a while and we're still on this game. Assume we have a stuck bowling frame.
                    self.completeBowlingFrame()
                }
            }
            
            func transitionToFrameComplete(striking struckPinCount: Int) {
                observer?.gameController(self, completedBowlingFrameWithStruckPins: struckPinCount)
            }
            
            func transitionToWaitingForContent(for nextState: State) {
                if gameAnchor != nil {
                    transition(to: nextState)
                }
            }

            currentState = state
            switch state {
            case .begin: break
            case .appStart: transitionToAppStart()
            case .menu: transitionToMenu()
            case .placingContent: transitionToPlacingContent()
            case .readyToBowl: transitionToReadyToBowl()
            case .ballInMotion: break
            case .ballAtRest: transitionToBallAtRest()
            case let .frameComplete(struckPinCount): transitionToFrameComplete(striking: struckPinCount)
            case let .waitingForContent(nextState): transitionToWaitingForContent(for: nextState)
            }
        }
    }
}

extension Experience.Game {
    var allPins: [Entity?] {
        return [pin1,
                pin2,
                pin3,
                pin4,
                pin5,
                pin6,
                pin7,
                pin8,
                pin9,
                pin10]
    }
    
    var allObstactles: [Entity?] {
        return [level2Obstacles,
                level3Obstacles,
                level4Obstacles1,
                level4Obstacles2,
                level4Obstacles3,
                level4Obstacles4]
    }
    
    var toHideOnStart: [Entity?] {
        return allObstactles + [winnerAward]
    }
}

fileprivate extension Experience.GameController.State {
    var activeBowlingFrame: Bool {
        self == .ballInMotion ||
        self == .ballAtRest
    }
}
