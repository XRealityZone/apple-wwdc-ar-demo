/*
See LICENSE folder for this sample’s licensing information.

Abstract:
GameSegue
*/

import UIKit

enum GameSegue: String {
    case selectMultiPlayerNavigator
    case selectMultiPlayer
    case startMultiPlayer
    case startSinglePlayer
    case joinMultiPlayer
    case showUserSettings
    case unwindToMainMenu
    case unknown
    
    init(segue: UIStoryboardSegue) {
        guard let identifier = segue.identifier,
            let segue = GameSegue(rawValue: identifier) else {
            self = .unknown
                return
        }
        self = segue
    }
}

extension UIViewController {
    func perform(_ segue: GameSegue) {
        performSegue(withIdentifier: segue.rawValue, sender: self)
    }
}
