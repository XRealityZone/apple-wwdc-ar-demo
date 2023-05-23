/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Performance debugging markers for use with os_signpost.
*/

import os.signpost

extension StaticString {
    // Signpost names for signposts related loading/starting a game
    static let setupLevel = "SetupLevel" as StaticString

    static let logicUpdate = "GameLogicUpdate" as StaticString

    // Signpost names for signposts related to networking
    static let networkActionSent = "NetworkActionSent" as StaticString
    static let networkActionReceived = "NetworkActionReceived" as StaticString
}

extension GameLog {
    // Custom log objects to use to classify signposts
    static let preloadAssets = OSLog(subsystem: "SwiftShot", category: "Preload")
    static let setupLevel = OSLog(subsystem: "SwiftShot", category: "LevelSetup")
    static let renderLoop = OSLog(subsystem: "SwiftShot", category: "RenderLoop")
    static let networkDataSent = OSLog(subsystem: "SwiftShot", category: "NetworkDataSent")
    static let networkDataReceived = OSLog(subsystem: "SwiftShot", category: "NetworkDataReceived")
}

extension OSSignpostID {
    // Custom signpost ids for signposts. Same id can be used for signposts that aren't concurrent with each other
    // Signpost ids for signposts related loading/starting a game
    static let setupLevel = OSSignpostID(log: GameLog.setupLevel)

    // Signpost ids for signposts related to scenekit render loop
    static let renderLoop = OSSignpostID(log: GameLog.renderLoop)

    // Signpost ids for signposts related to networking
    static let networkDataSent = OSSignpostID(log: GameLog.networkDataSent)
    static let networkDataReceived = OSSignpostID(log: GameLog.networkDataReceived)
}
