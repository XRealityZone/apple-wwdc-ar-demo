/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Wrapper for loading level scenes.
*/

import os.log
import RealityKit
import UIKit

// defaults are for SwiftShot
private let defaultSize = CGSize(width: 15, height: 27)
private var defaultResizable = true
private let defaultMinimumScale: Float = 0.3
private let defaultMaximumScale: Float = 11.0
private let levelStrings = "levels"

struct ActiveLevel {
    var content: Entity
    // multiply uniform scale by this amount to make level appear 1m wide
    var scaleFactor: Float
    
    init(content: Entity, scaleFactor: Float = 1.0) {
        self.content = content
        self.scaleFactor = scaleFactor
    }
}

// Wraps an available level of the game to be loaded
class GameLevel {
    struct Definition: Codable, Hashable {
        let key: String
        let identifier: String
        init(key: String, identifier: String) {
            self.key = key
            self.identifier = identifier
        }
        var name: String {
            return NSLocalizedString(self.key,
                                     tableName: levelStrings,
                                     bundle: Bundle.main,
                                     value: self.key,
                                     comment: "Please make sure all strings from levels.strings are translated")
        }
    }
    
    let definition: Definition
    var key: String { return definition.key }
    var name: String { return definition.name }
    // used to find the assets/etc in the bundle
    private var identifier: String { return definition.identifier }

    // Size of the level in meters
    var targetSize: CGSize
    var isResizable: Bool
    var defaultScale: Float
    var minimumScale: Float
    var maximumScale: Float

    init(definition: Definition) {
        self.definition = definition
        self.targetSize = defaultSize
        self.isResizable = defaultResizable
        self.defaultScale = 1
        self.minimumScale = defaultMinimumScale
        self.maximumScale = defaultMaximumScale
    }
}
