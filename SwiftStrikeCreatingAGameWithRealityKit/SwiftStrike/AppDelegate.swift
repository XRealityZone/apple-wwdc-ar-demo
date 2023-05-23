/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Swiftstrike application delegate
*/

import os.log
import RealityKit
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        let imageCount = _dyld_image_count()
        for index in 0...imageCount - 1 {
            NSLog("%3d - %s", index, _dyld_get_image_name(index))
        }

        UserSettings.registerDefaults()

        ComponentCollection.registerComponents([
            MatchStateComponent.self,
            PaddleComponent.self,
            SpectatorListenerComponent.self,
            SyncSoundComponent.self
        ])

        // check to see if device name changed, update identifier used for MPC
        let deviceName = UIDevice.current.name
        let myself = UserDefaults.standard.myself
        if myself.username != deviceName {
            UserDefaults.standard.myself = Player(username: deviceName)
        }
        UserSettings.forwardSettingsToSystems()

        // Prevent the screen from sleeping while the game is running
        application.isIdleTimerDisabled = true

        return true
    }
}

