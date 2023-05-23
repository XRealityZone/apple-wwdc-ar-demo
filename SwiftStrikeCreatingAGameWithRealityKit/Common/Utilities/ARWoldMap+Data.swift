/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Helpers for converting ARWorldMap to and from compressed Data
*/

import ARKit
import Foundation
import os.log

struct WorldMapExtractionFailedError: Error {}

extension ARWorldMap {
    static let worldMapExtension = "swiftstrikemap"
    static let defaultSaveMapName = "savedMap.swiftstrikemap"

    static func fromData(_ archivedData: Data) throws -> ARWorldMap {
        // Maps saved through the app are compressed, but we might want to read maps built with
        // other apps. If decompression fails we'll try to unarchive the Data as is.
        let uncompressedData = (try? archivedData.decompressed()) ?? archivedData

        guard let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: uncompressedData) else {
            os_log(.error, log: GameLog.general, "The WorldMap received couldn't be read")
            throw WorldMapExtractionFailedError()
        }

        return worldMap
    }

    static func urlForMap(_ name: String) throws -> URL {
        return Bundle.main.url(forResource: name, withExtension: worldMapExtension)!
    }

    static func data(for name: String) throws -> Data {
        let mapURL = try urlForMap(name)
        return try Data(contentsOf: mapURL, options: .mappedIfSafe)
    }

    func asCompressedData() throws -> Data {
        let data = try NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: true)
        let compressedData = data.compressed()
        return compressedData
    }
}
