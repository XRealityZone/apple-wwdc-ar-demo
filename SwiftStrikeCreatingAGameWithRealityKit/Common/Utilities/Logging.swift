/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Logging Categories
*/

import os.log

enum GameLog {
    static let subsystem = "com.apple.SwiftStrike"
    static let arFlags = OSLog(subsystem: subsystem, category: "ARFlags")
    static let audio = OSLog(subsystem: subsystem, category: "audio")
    static let collision = OSLog(subsystem: subsystem, category: "collision")
    static let gameboard = OSLog(subsystem: subsystem, category: "gameboard")
    static let general = OSLog(subsystem: subsystem, category: "general")
    static let memory = OSLog(subsystem: subsystem, category: "memory")
    static let networkConnect = OSLog(subsystem: subsystem, category: "networkConnect")
    static let levelLifeCycle = OSLog(subsystem: subsystem, category: "levelLifeCycle")
    static let preloading = OSLog(subsystem: subsystem, category: "preloading")
    static let player = OSLog(subsystem: subsystem, category: "player")
    static let levelConfiguration = OSLog(subsystem: subsystem, category: "levelConfiguration")
    static let navigation = OSLog(subsystem: subsystem, category: "navigation")
    static let networkPackets = OSLog(subsystem: subsystem, category: "packets")
    static let gameState = OSLog(subsystem: subsystem, category: "gameState")
}
