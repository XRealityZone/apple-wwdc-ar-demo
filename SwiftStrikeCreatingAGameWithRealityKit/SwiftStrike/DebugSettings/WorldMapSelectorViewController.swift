/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Popup for selecting a saved map
*/

import UIKit
import os.log

protocol WorldMapSelectorDelegate: AnyObject {
    func worldMapSelector(_ worldMapSelector: WorldMapSelectorViewController, selectedMap: URL)
}

// Allows the user to load a pre-saved map of the physical world for ARKit. The app then
// uses this to place the board in real space.
class WorldMapSelectorViewController: UITableViewController {
    weak var delegate: WorldMapSelectorDelegate?

    var maps: [URL] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        do {
            let docs = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let mapsDirectory = docs.appendingPathComponent("maps", isDirectory: true)
            self.maps = try FileManager.default.contentsOfDirectory(at: mapsDirectory, includingPropertiesForKeys: nil, options: [])
        } catch {
            os_log(.error, log: GameLog.general, "error loading world maps directory: %@", error as NSError)
            self.dismiss(animated: true, completion: nil)
        }
    }

    // MARK: - UITableViewDataSource
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return maps.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MapCell", for: indexPath)
        cell.textLabel?.text = maps[indexPath.row].deletingPathExtension().lastPathComponent
        return cell
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Map selection triggers delegate method when present, otherwise tries the presenting
        // view controller (for convenience)
        if let delegate = delegate {
            delegate.worldMapSelector(self, selectedMap: maps[indexPath.row])
        } else if let viewController = presentingViewController as? WorldMapSelectorDelegate {
            viewController.worldMapSelector(self, selectedMap: maps[indexPath.row])
        }

        self.dismiss(animated: true)
    }
}
