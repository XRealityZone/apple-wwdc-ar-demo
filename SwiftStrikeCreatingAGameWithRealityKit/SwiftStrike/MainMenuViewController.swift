/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Landing view controller
*/

import Combine
import os.log
import UIKit

class MainMenuViewController: UIViewController {
    private var gameBrowser: GameBrowser?
    @IBOutlet var splashView: SplashView!

    @IBOutlet weak var settingsButton: UIButton!
    
    @IBOutlet weak var soloGameButton: UIButton!
    @IBOutlet weak var start2pGameButton: UIButton!
    @IBOutlet weak var join2pGameButton: UIButton!
    @IBOutlet weak var levelLoaderActivityIndicator: UIActivityIndicatorView!
 
    override var prefersStatusBarHidden: Bool {
        return true
    }

    let sfxCoordinator = SFXCoordinator()
    let musicCoordinator = MusicCoordinator()
    let levelLoader = LevelLoader()
    var audioLoaded = false
    var cancellables = [AnyCancellable]()

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        musicCoordinator.playMusic(name: "music_menu_swift_strike", fadeIn: 0.025)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        settingsButton.isHidden = !UserSettings.debugEnabled
        
        splashView.startAnimating()
        
        disableGameStart()
        levelLoader.load(levelLoader.reckoning) { result in
            switch result {
            case .failure(let error):
                os_log(.default, log: GameLog.preloading, "Level load failed: %s", "\(error)")
                fatalError("Level load failed: \(error)")
            case .success:
                os_log(.default, log: GameLog.preloading, "Level successfully loaded!")
                if self.preloadingComplete() {
                    self.enableGameStart()
                }
            }
        }?
        .store(in: &cancellables)

        SFXCoordinator.loadAudioFiles {
            os_log(.default, log: GameLog.preloading, "audio successfully loaded!")
            self.audioLoaded = true
            if self.preloadingComplete() {
                self.enableGameStart()
            }
        }
    }
    
    func preloadingComplete() -> Bool {
        return levelLoader.activeLevel != nil && audioLoaded
    }
    
    func disableGameStart() {
        soloGameButton.isHidden = true
        start2pGameButton.isHidden = true
        join2pGameButton.isHidden = true
        levelLoaderActivityIndicator.startAnimating()
    }
    
    func enableGameStart() {
        soloGameButton.isHidden = false
        start2pGameButton.isHidden = false
        join2pGameButton.isHidden = false
        levelLoaderActivityIndicator.stopAnimating()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        splashView.stopAnimating()
        musicCoordinator.stopMusic(name: "music_menu_swift_strike", fadeOut: 1.0)
    }
    
    @IBAction func unwindToMainMenu(_ unwindSegue: UIStoryboardSegue) {
    
    }

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        return GameSegue(rawValue: identifier) != nil
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch GameSegue(segue: segue) {
        case .startMultiPlayer:
            guard let destination = segue.destination as? GameViewController else {
                return
            }
            let myself = UserDefaults.standard.myself
            let networkSession = NetworkSession(myself: myself, asServer: true, host: myself, serviceBrowser: nil)
            destination.networkSession = networkSession
            destination.sfxCoordinator = sfxCoordinator
            destination.musicCoordinator = musicCoordinator
            destination.levelLoader = levelLoader
        case .joinMultiPlayer:
            guard let destination = segue.destination as? GameViewController,
                let networkSession = sender as? NetworkSession else {
                return
            }
            destination.networkSession = networkSession
            destination.sfxCoordinator = sfxCoordinator
            destination.musicCoordinator = musicCoordinator
            destination.levelLoader = levelLoader
        case .selectMultiPlayerNavigator:
            guard let networkGameBrowserNavigation = segue.destination as? NetworkGameBrowserNavigationController else {
                return
            }

            networkGameBrowserNavigation.networkGameBrowserDelegate = self
            let myself = UserDefaults.standard.myself
            gameBrowser = GameBrowser(myself: myself)
            networkGameBrowserNavigation.gameBrowser = gameBrowser
        default:
            if let destination = segue.destination as? GameViewController {
                destination.sfxCoordinator = sfxCoordinator
                destination.musicCoordinator = musicCoordinator
                destination.levelLoader = levelLoader
            }
            return
        }
    }

    @IBAction func settingsPressed(_ sender: Any) {
        let conditionalUserSettingsViewController = UserSettingsNavigationController.createInstanceFromStoryboard(delegate: self)
        if let userSettingsViewController = conditionalUserSettingsViewController {
            self.present(userSettingsViewController, animated: true, completion: nil)
        }
    }
}

extension MainMenuViewController: UserSettingsNavigationControllerDelegate {
    func gameSettingsViewController() -> UIViewController {
        let storyboard = UIStoryboard(name: "GameSettings", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "GameSettingsTableViewController")
        return viewController
    }
}

extension MainMenuViewController: NetworkGameBrowserDelegate {
    func networkGameBrowser(_ networkGameBrowser: NetworkGameBrowserViewController, didSelectSession networkSession: NetworkSession) {
        dismiss(animated: true) {
            self.performSegue(withIdentifier: GameSegue.joinMultiPlayer.rawValue, sender: networkSession)
        }
    }
}

