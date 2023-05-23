# SwiftStrike: Creating a Game with RealityKit

Create a multiplayer game with ARKit, RealityKit, and Swift using the SwiftStrike app as a guide.

## Overview

SwiftStrike is an AR game in which one or two players move a ball to knock over their opponents' pins, and featured as an interactive floor demo at WWDC19. SwiftStrike requires two separate devices for a two-player game. It also supports additional spectators, who can view the game using additional devices. Use this sample code project to experience SwiftStrike on your own device, and build your own customized version of the game.

To start a single-player game, tap the Single Player button. If you want to start a new game with another nearby player on the same Wi-Fi network, tap the Host button. To join a game started by another player, tap the Join button. If you're hosting a multiplayer game or playing a single-player game, the app asks you to find a flat surface on which to place the game board. Tap the screen when you're ready to play and the play field appears.

- Important: In multiplayer games, players should stand near each other and point their cameras at the same area to allow their devices to sync locations.

SwiftStrike requires Xcode 12 or later and iOS 14 or later. The game runs on an iOS device with an A9 or later processor, and certain features, like people occlusion, require an A12 processor or later. The iOS Simulator does not support ARKit.

## Design Gameplay for AR

SwiftStrike embraces augmented reality as a medium for engaging gameplay.

**Encourage player movement to make gameplay more immersive.** In SwiftStrike, the player may find that they can't get a good shot at their opponent's pins because their opponent is in the way. By moving to a new location, the player can find the best angle for a winning shot or prevent their opponent from making a successful shot.

**Foster social engagement.** Multiplayer AR games bring players together in the same space, giving them exciting new ways to have fun together. Using AR to watch a game as a spectator provides a different perspective and an additional way to interact with the experience. 

## Choose the Game Scale

SwiftStrike plays on a table top by default. In this mode, each player controls a striker and tries to knock over the other player's pins by pushing the ball with that striker.

SwiftStrike can also play in "full court" mode, the way it was demonstrated at WWDC 2019. Full court mode places the board on the floor and uses a much larger play area, pins, and ball. In full court mode, instead of using a striker, the iPad itself acts as a "paddle" to push the ball. On devices with an A12 processors or later, full court mode incorporates people occlusion to create a truly engaging and immersive experience. For more on implementing people occlusion, see [Occluding Virtual Content with People][01].

To change the game scale, players can select SwiftStrike in the Settings app and choose either Full Court or Table Top. When selecting full court scale, users can also adjust the size of the board in the Settings App to suit the available space by changing the Full Court Scale setting.

- Note: Changes made in the Settings app won't take effect until the next time the app launches.

Players can print out a placement image called `Floor_Decal.png` from the project folder and put it on the floor to indicate where they want the field to be placed. The default size decal that SwiftStrike looks for is 47 inches (1.194 meters) square, but players can change the expected decal size to match the actual size of their print by tapping the Gear icon on SwiftStrike's menu page and changing the Floor Decal Diameter to the desired size in meters. When syncing in two-player games, both players should make sure the decal is visible on screen.

For multiplayer games, both devices must be set to use the same game scale and decal size.

## Begin a Game

Game play starts when all players have indicated readiness. In tabletop scale, each player indicates readiness by moving their striker over the blue glowing start column on their side of the board, keeping it there for a few seconds. In full court mode, each player must physically move to the blue glowing start area and remain there for several seconds.

Once all players have indicated readiness, a countdown begins and then the game starts.

## Enable Cosmic Mode

SwiftStrike has two visual modes. Normal mode is SwiftStrike's default, and shows a game board with realistic pins, strikers, play field, and ball. In cosmic mode, the pins, paddles, play field, and ball display animated neon effects. Cosmic mode takes advantage of [`cameraFeed(exposureCompensation:)`][11] to darken the camera view so the glowing cosmic effects are visible even when playing in a brightly-lit space. Users can turn on cosmic mode from the Settings app by selecting SwiftStrike and using the Visual Mode setting to switch between Normal and Cosmic. For multiplayer games, both devices must be set to the same mode.

## Conform to Entity Component System

The design of RealityKit follows a pattern called Entity Component System (ECS). In ECS, functionality for virtual objects, known as *entities*, exists on separate *components* that are added to entities to give them different abilities or behaviors. Components encapsulate logic in a generic way that can be utilized by any entity. This design keeps entities lightweight by including only the components they need. 

In RealityKit, add components to an entity by conforming it to a protocol. For example, the [`PhysicsBodyComponent`][08], which encapsulates the logic needed for an object to participate in RealityKit's physics simulation, has a corresponding protocol called [`HasPhysicsBody`][09]. Entities that conform to `HasPhysicsBody` automatically simulate physics without writing any additional code. To check if an entity has a particular component, cast it to the protocol. If the cast returns `nil`, the entity doesn't have that component. 

For example, code that should only be run against entities with a `PhysicsBodyComponent` can cast the entity to `HasPhysicsBody`. If the cast returns `nil`, then the entity does not have a physics body component, and the code shouldn't execute. If it returns a valid entity, then the code is safe to run.

```swift
    guard let entity = entity as? HasPhysicsBody else { return }
```
For more information on using Swift `guard` statements, see [Swift Guard Statements][13].

SwiftStrike follows the ECS design pattern also, adding new entity logic using components and a corresponding protocol.

[`UprightStatusComponent`](x-source-tag://UprightStatusComponent) and its corresponding protocol [`HasUprightStatus`](x-source-tag://HasStandUpright) show an example of SwiftStrike's use of ECS. This component implements an entity's ability to register if it has fallen down. The [`PinEntity`](x-source-tag://AddPinRootComponents) uses this component so pins can determine when they have been knocked over, creating a win condition.

Pin entities conform to `HasUprightStatus` and instantiate an `UprightStatusComponent` when SwiftStrike loads them.

```swift
    private func addPinRootComponents(_ childNames: [String]) {
        physicsMotion = PhysicsMotionComponent()
        childEntitySwitch.childEntityNamesList = childNames
        audio = GameAudioComponent.load(named: "pin-audio")
        uprightStatus = UprightStatusComponent()
    }
```

## Syncing with State Machines and Combine

SwiftStrike uses RealityKit's [MultipeerConnectivityService][02] to sync scenes across the network. SwiftStrike leverages this service to handle the syncing of virtual objects and physics simulations between connected devices automatically. Game-specific state data, however, must still be managed and synced manually. SwiftStrike syncs game data using several state machine classes, along with the [Combine framework][03] to communicate state changes between devices. The host app maintains and manages game state data classes, such as `MatchStates` and `PositionPlayers`, and communicates changes to the peers as needed.

SwiftStrike uses the `GameStates` class to implement state machines, and [`GameStates.State`](x-source-tag://GameStatesState) to represent individual states. Each state has two properties: a string property called `name` that uniquely identifies the state, and `transform`, a closure that evaluates whether it's time to transition to another state. If no state change is needed, `transform` returns `nil`.

SwiftStrike uses a number of methods to check for potential state machine transitions. [`MatchStates.waitForCourt()`](x-source-tag://waitForCourt), for example, takes a [`MatchInput`](x-source-tag://MatchInputListing) object and determines if a transition is needed by querying whether the game field has finished animating in. If it has, `waitForCourt()` indicates the next state (`.readyForBallDrop`), as well as the method to use to look for the next state change (`self.waitForBallDrop()`). If the animation hasn't finished, it returns `nil`, indicating that the state shouldn't change yet. `waitForCourt()` will be called periodically until a transition is indicated.

``` swift 
    func waitForCourt() -> GameStates<MatchInput, MatchOutput>.State {
        return .init("showCourt") { [weak self] input in
            guard let self = self else { return nil }
            if case MatchInput.animationEnded(.courtReady) = input {
                self.isFirstRun = false
                return GameStates<MatchInput, MatchOutput>.StateOutput(outputEvent: .readyForBallDrop,
                                                                       nextState: self.waitForBallDrop())
            }
            return nil
        }
    }
```
[View in Source](x-source-tag://waitForCourt)

## Add Billboards in Cosmic Mode

To achieve the glowing neon effects in Cosmic mode, SwiftStrike uses *billboards*, which are two-dimensional objects that continuously rotate on one or more axes to face the camera, creating the illusion of a 3D object. SwiftStrike uses three different types of billboard entities:

- **`YAxisBillboardEntity`**. Rotates on just the Y (up) axis and displays the glow effects on the pins.
- **`CameraBillboardEntity`**. Rotates on all axes and creates the glow effects on the ball.
- **`FloorBillboardComponent`**. Makes sure the entity lies flat on the ground and creates the surface glow under the pins and ball.

Because the rotation of each billboard depends on the position of the local camera, SwiftStrike doesn't sync billboard rotation over the network to other devices. The billboard entities change their transforms in a closure passed to [`.withUnsynchronized`][12]. When the entity's properties change inside `withUnsynchronized()`, the entity makes those changes locally and doesn't communicate them to the connected devices. `YAxisBillboardComponent`, which implements the rotation logic for `YAxisBillboardEntity`, shows the use of `withUnsynchronized()`:

```swift
    public func rotate(lookAt: Transform) {
        guard let parent = self.parent else { return }

        // Get camera world space position.
        let cameraPosition = lookAt.translation
        var newTransform = transform
        
        newTransform = newTransform.yAxisLookAtWorldSpacePoint(parentEntity: parent, worldSpaceAt: cameraPosition)

        // Since this transform change is local to this device, we
        // don't want it communicated to other devices.
        self.withUnsynchronized {
            self.transform = newTransform
        }
    }
```
[View in Source](x-source-tag://HasYAxisBillboardRotate)

## Enable Image-Based Lighting

SwiftStrike's debug menu, available in the upper-right corner of the screen when a game is in progress, provides options to visualize what's happening at runtime and to experiment with different rendering and gameplay options.

One option in this menu is image-based lighting (IBL). When enabled, SwiftStrike will choose from a few different possible images depending on the game mode and scale to generate the scene lighting. For example, if players are in cosmic mode, SwiftStrike chooses an environment image that includes glow effects. SwiftStrike loads the image as an [`EnvironmentResource`][10], which turns on IBL using the loaded image as the lighting source.

```swift
        if iblResource == nil {
            iblResource = try? EnvironmentResource.load(named: iblFileName())
        }
```

## Switch Objects from Kinetic to Dynamic

SwiftStrike switches entities between different physics modes during game play. For example, pins start set to [`.dynamic`][06] so the players can interact with them and knock them over. When animating the pins to their original positions during game reset, however, SwiftStrike switches them to [`.kinematic`][07], which prevents collisions from getting in the way of the pin reset animation. SwiftStrike switches the pins back to `.dynamic` after the reset animation completes.

```swift
    pins.forEach { pin in
        // Put the pin back to its original position.
        // We need to set the physicsBody.mode to .kinematic
        // so that physics simulation doesn't interfere
        // with the animation
        pin.physicsBody?.mode = .kinematic
        // Initial scale for animating pin "in" is 0
        pin.renderEntity.transform.scale = .zero
    }
```
[View in Source](x-source-tag://PinResetCode)


[00]: https://www.apple.com/apple-events/june-2019/
[01]: https://developer.apple.com/documentation/arkit/camera_lighting_and_effects/occluding_virtual_content_with_people
[02]: https://developer.apple.com/documentation/realitykit/multipeerconnectivityservice
[03]: https://developer.apple.com/documentation/combine
[04]: https://developer.apple.com/documentation/realitykit/environmentresource/3244139-load
[05]: https://developer.apple.com/documentation/realitykit/arview
[06]: https://developer.apple.com/documentation/realitykit/modelentity/3244500-physicsbody
[07]: https://developer.apple.com/documentation/realitykit/modelentity/3244500-physicsbody
[08]: https://developer.apple.com/documentation/realitykit/physicsbodycomponent
[09]: https://developer.apple.com/documentation/realitykit/hasphysicsbody
[10]: https://developer.apple.com/documentation/realitykit/environmentresource
[11]: https://developer.apple.com/documentation/realitykit/arview/environment/background/3282003-camerafeed
[12]: https://developer.apple.com/documentation/realitykit/entity/3366490-withunsynchronized
[13]: https://docs.swift.org/swift-book/ReferenceManual/Statements.html#grammar_guard-statement
