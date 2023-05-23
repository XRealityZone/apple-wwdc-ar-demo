/*
See LICENSE folder for this sample’s licensing information.

Abstract:
View controller for user settings.
*/

import os.log
import UIKit

enum SettingsSegueIdentifier: String {
    case showDeveloperSettings
    case showGameSettings
}

protocol UserSettingsNavigationControllerDelegate: AnyObject {
    func gameSettingsViewController() -> UIViewController
}

class UserSettingsNavigationController: UINavigationController {
    weak var gameSettingsViewControllerDelegate: UserSettingsNavigationControllerDelegate?

    static func createInstanceFromStoryboard(delegate: UserSettingsNavigationControllerDelegate) -> UserSettingsNavigationController? {
        let storyboard = UIStoryboard(name: "UserSettings", bundle: Bundle(for: self))
        let navigationController = storyboard.instantiateViewController(withIdentifier: "NavigationController")
            as? UserSettingsNavigationController
        navigationController?.gameSettingsViewControllerDelegate = delegate
        return navigationController
    }

}
