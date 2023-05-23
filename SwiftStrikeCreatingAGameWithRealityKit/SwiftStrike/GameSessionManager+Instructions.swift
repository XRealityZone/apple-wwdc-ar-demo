/*
See LICENSE folder for this sample’s licensing information.

Abstract:
User guidance during game setup
*/

import Foundation

extension GameSessionManager.State {
    var localizedInstruction: String? {
        guard !UserSettings.disableInGameUI else { return nil }
        switch self {
        case .lookingForSurface:
            return NSLocalizedString("Find a flat surface and/or Floor Decal to place the game.", comment: "")
        case .placingBoard:
            return NSLocalizedString("Rotate or move the board. Tap ✕ to place on a different surface.", comment: "")
        case .adjustingBoard:
            return NSLocalizedString("Make adjustments and tap to continue.", comment: "")
        case .gameInProgress:
            return nil
        case .waitingForBoard:
            return NSLocalizedString("Waiting for board location.", comment: "")
        case .localizingToWorldMap, .localizingCollaboratively:
            return NSLocalizedString("Point the camera towards the game floor to join.", comment: "")
        case .exitGame:
            return NSLocalizedString("Exiting to main menu...", comment: "")
        case .setup:
            return nil
        }
    }
}
