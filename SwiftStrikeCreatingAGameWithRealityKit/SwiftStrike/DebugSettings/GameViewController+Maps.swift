/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Maps saving and loading methods for the Game Scene View Controller.
*/

import ARKit
import os.log
import UIKit

private let gameBoardName = "GameBoard"
extension GameSessionManager.State {
    var shouldShowMappingState: Bool {
        switch self {
        case .setup, .gameInProgress:
            return false
        default:
            return true
        }
    }
}
extension GameViewController {

    func updateMappingUI() {
        let showMappingState = shouldShowMappingState && UserSettings.showARMappingState
        mappingStateLabel.isHidden = !showMappingState || UserSettings.disableInGameUI
    }

    // MARK: Saving and Loading Maps
    func configureMappingUI(_ state: GameSessionManager.State) {
        shouldShowMappingState = state.shouldShowMappingState
        updateMappingUI()
    }
    
    func updateMappingStatus() {
        // Check the mapping status of the worldmap to be able to save the worldmap when in a good state
        os_log(.default, log: GameLog.general, "Mapping status: %s", String(describing: mappingStatus))
        mappingStateLabel.text = "Mapping: \(mappingStatus)"
        switch mappingStatus {
        case .mapped:
            mappingStateLabel.textColor = .green
        default:
            mappingStateLabel.textColor = .red
        }
    }

    func savePressed() {
        os_log(.default, log: GameLog.navigation, "Save pressed")
        gameSessionManager?.requestCurrentWorldMap { (result) in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error as NSError):
                    let title = error.localizedDescription
                    let message = error.localizedFailureReason
                    self.showAlert(title: title, message: message)
                case .success(let data):
                    self.showSaveDialog(for: data)
                }
            }
        }
    }
    
    private func showSaveDialog(for data: Data) {
        let dialog = UIAlertController(title: "Save World Map", message: nil, preferredStyle: .alert)
        dialog.addTextField(configurationHandler: nil)
        // change save map to save to a specific filename
        let saveAction = UIAlertAction(title: "Save", style: .default) { _ in
            guard let fileName = dialog.textFields?.first?.text else {
                os_log(.error, log: GameLog.general, "no filename"); return
            }
            DispatchQueue.global(qos: .background).async {
                do {
                    let docs = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                    let maps = docs.appendingPathComponent("maps", isDirectory: true)
                    try FileManager.default.createDirectory(at: maps, withIntermediateDirectories: true, attributes: nil)
                    let targetURL = maps.appendingPathComponent(fileName).appendingPathExtension(ARWorldMap.worldMapExtension)
                    try data.write(to: targetURL, options: [.atomic])
                    DispatchQueue.main.async {
                        self.showAlert(title: "Saved")
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.showAlert(title: error.localizedDescription, message: nil)
                    }
                }
            }
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        dialog.addAction(saveAction)
        dialog.addAction(cancelAction)
        
        present(dialog, animated: true, completion: nil)
    }
    
    /// Get the archived data from a URL Path
    private func fetchArchivedWorldMap(from url: URL, _ closure: @escaping (Result<Data, Error>) -> Void) {
        DispatchQueue.global().async {
            do {
                _ = url.startAccessingSecurityScopedResource()
                defer { url.stopAccessingSecurityScopedResource() }
                let data = try Data(contentsOf: url)
                closure(.success(data))
                
            } catch {
                DispatchQueue.main.async {
                    self.showAlert(title: error.localizedDescription)
                }
                closure(.failure(error))
            }
        }
    }
    
    private func compressMap(map: ARWorldMap, _ closure: @escaping (Result<Data, Error>) -> Void) {
        DispatchQueue.global().async {
            do {
                let data = try NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
                os_log(.default, log: GameLog.general, "data size is %d", data.count)
                let compressedData = data.compressed()
                os_log(.default, log: GameLog.general, "compressed size is %d", compressedData.count)
                closure(.success(compressedData))
            } catch {
                os_log(.error, log: GameLog.general, "archiving failed %s", "\(error)")
                closure(.failure(error))
            }
        }
    }
}

extension GameViewController: WorldMapSelectorDelegate {
    func worldMapSelector(_ worldMapSelector: WorldMapSelectorViewController, selectedMap: URL) {
        DispatchQueue.global(qos: .background).async {
            do {
                let data = try Data(contentsOf: selectedMap)
                self.gameSessionManager?.localizeToSavedMapData(data)
                DispatchQueue.main.async {
                    self.showAlert(title: "Loaded")
                }
            } catch {
                DispatchQueue.main.async {
                    self.showAlert(title: error.localizedDescription, message: nil)
                }
            }
        }
    }
}
