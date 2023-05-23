/*
See LICENSE folder for this sample’s licensing information.

Abstract:
View controller for finding network games.
*/

import os.log
import UIKit

protocol NetworkGameBrowserDelegate: AnyObject {
    func networkGameBrowser(_ networkGameBrowser: NetworkGameBrowserViewController, didSelectSession networkSession: NetworkSession)
}

class NetworkGameBrowserNavigationController: UINavigationController {
    var gameBrowser: GameBrowser!
    weak var networkGameBrowserDelegate: NetworkGameBrowserDelegate?

    override init(navigationBarClass: AnyClass?, toolbarClass: AnyClass?) {
        super.init(navigationBarClass: navigationBarClass, toolbarClass: toolbarClass)
        delegate = self
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        delegate = self
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        delegate = self
    }
}

extension NetworkGameBrowserNavigationController: UINavigationControllerDelegate {
    func navigationController(_ controller: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        if let networkGameBrowserViewController = viewController as? NetworkGameBrowserViewController {
            // move ownership of delegate, game browser from navigator view controller to network game browser
            networkGameBrowserViewController.delegate = networkGameBrowserDelegate
            networkGameBrowserDelegate = nil
            networkGameBrowserViewController.browser = gameBrowser
            gameBrowser = nil
        }
    }
}

class NetworkGameBrowserViewController: UITableViewController {

    @IBAction func doneButtonAction(_ sender: UIBarButtonItem) {
        dismiss(animated: true)
    }

    weak var delegate: NetworkGameBrowserDelegate?

    var games: [NetworkGame] = []

    var browser: GameBrowser! {
        didSet {
            oldValue?.stop()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.dataSource = self
        tableView.delegate = self
        tableView.layer.cornerRadius = 10
        tableView.clipsToBounds = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startBrowser()
    }

    func startBrowser() {
        browser.delegate = self
        browser.start()
        tableView.reloadData()
    }

    func joinGame(_ game: NetworkGame) {
        guard let session = browser?.join(game: game) else {
            os_log(.error, log: GameLog.general, "could not join game")
            return
        }

        delegate?.networkGameBrowser(self, didSelectSession: session)
    }
}

// MARK: - GameBrowserDelegate
extension NetworkGameBrowserViewController: GameBrowserDelegate {
    func gameBrowser(_ browser: GameBrowser, sawGames games: [NetworkGame]) {
        os_log(.default, log: GameLog.general, "saw %d games!", games.count)

        self.games = games

        tableView.reloadData()
    }

    func gameBrowser(_ browser: GameBrowser, presentDialog dialog: ErrorsAlertViewController, animated: Bool, completion: (() -> Void)?) {
        present(dialog, animated: animated, completion: completion)
    }
}

// MARK: - UITableViewDataSource
extension NetworkGameBrowserViewController {
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "GameCell", for: indexPath)
        let game = games[indexPath.row]
        cell.textLabel?.text = game.name
        let enabled = game.settingsValid
        cell.textLabel?.isEnabled = enabled
        cell.detailTextLabel?.isEnabled = enabled
        return cell
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return games.count
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
}

// MARK: - UITableViewDelegate
extension NetworkGameBrowserViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let otherPlayer = games[indexPath.row]
        joinGame(otherPlayer)
    }
}
