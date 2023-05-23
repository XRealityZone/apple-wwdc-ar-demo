/*
See LICENSE folder for this sample’s licensing information.

Abstract:
An object that responds to scene life cycle events.
*/

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    // The URL of the App Clip Code that launched the app or App Clip.
    var appClipCodeURL: URL? = nil

    ///- Tag: SceneWillConnectToSession
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        for activity in connectionOptions.userActivities where activity.activityType == NSUserActivityTypeBrowsingWeb {
            appClipCodeURL = activity.webpageURL
        }
        
        guard let windowScene = (scene as? UIWindowScene) else { return }
        window = UIWindow(frame: windowScene.coordinateSpace.bounds)
        window?.windowScene = windowScene
        window?.rootViewController = ViewController()
        window?.makeKeyAndVisible()
    }
}

