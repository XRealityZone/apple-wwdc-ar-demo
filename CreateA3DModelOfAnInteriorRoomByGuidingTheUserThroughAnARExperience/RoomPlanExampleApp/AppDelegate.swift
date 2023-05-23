/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The sample app's main entry point.
*/

import UIKit
import RoomPlan

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }

    // MARK: UISceneSession life cycle

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        var configurationName = "Default Configuration"
        if !RoomCaptureSession.isSupported {
            configurationName = "Unsupported Device"
        }
        return UISceneConfiguration(name: configurationName, sessionRole: connectingSceneSession.role)
    }
}

