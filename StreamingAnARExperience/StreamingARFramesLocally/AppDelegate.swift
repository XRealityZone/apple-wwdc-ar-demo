/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The app delegate.
*/
import UIKit
import ARKit

///- Tag: AppDelegate
@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var overlayWindow: UIWindow!

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        guard ARWorldTrackingConfiguration.isSupported else {
                    fatalError("""
                        ARKit is not available on this device. For apps that require ARKit
                        for core functionality, use the `arkit` key in the key in the
                        `UIRequiredDeviceCapabilities` section of the Info.plist to prevent
                        the app from installing. (If the app can't be installed, this error
                        can't be triggered in a production scenario.)
                        In apps where AR is an additive feature, use `isSupported` to
                        determine whether to show UI for launching AR experiences.
                    """) // For details, see https://developer.apple.com/documentation/arkit
                }
        guard let window = window,
              let windowScene = window.windowScene else { fatalError() }
        
        // Create a window for the overlay.
        overlayWindow = UIWindow(windowScene: windowScene)
        
        let storyBoard = UIStoryboard(name: "Main", bundle: nil)
        let overlayViewController = storyBoard.instantiateViewController(
            identifier: "OverlayViewController")
        overlayWindow.rootViewController = overlayViewController
        overlayWindow.makeKeyAndVisible()
        
        // Make sure the overlayWindow is always above the main window.
        overlayWindow.windowLevel = window.windowLevel + 1
        
        // Make the overlayWindow transparent so that the main window remains visible underneath.
        overlayWindow.backgroundColor = .clear
        
        return true
    }
}

