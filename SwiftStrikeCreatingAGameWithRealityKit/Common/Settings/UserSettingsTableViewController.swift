/*
See LICENSE folder for this sample’s licensing information.

Abstract:
View controller for user settings.
*/

import UIKit

class UserSettingsTableViewController: UITableViewController {
    @IBOutlet var appVersionLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        appVersionLabel.text = "\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? 0)"
            + " (\(Bundle.main.infoDictionary?["CFBundleVersion"] ?? 0))"
    }

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        // refuse segue if not one of mine
        guard let segueIdentifier = SettingsSegueIdentifier(rawValue: identifier) else { return false }
        // for segues that are not game settings, go ahead and segue
        if segueIdentifier == .showGameSettings {
            let conditionalNavigationController = navigationController as? UserSettingsNavigationController
            if let navigationController = conditionalNavigationController {
                let conditionalViewController = navigationController.gameSettingsViewControllerDelegate?.gameSettingsViewController()
                if let viewController = conditionalViewController {
                    self.navigationController?.show(viewController, sender: self)
                }
            }
            return false
        }
        return true
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // undo the highlight of the "selected" cell
        tableView.deselectRow(at: indexPath, animated: true)
    }

    @IBAction func doneTapped(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }

}
