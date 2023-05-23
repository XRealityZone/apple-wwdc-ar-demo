/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Maintains application state.
*/

import Foundation
import UIKit

struct ApplicationState {
    
    /// Shared state instance.
    static var shared = ApplicationState()
    
    /// The selected postprocessing mode.
    var mode: Mode = .noPostProcessing
    
    /// Whether the coaching view is currently being shown.
    var isCoachingViewShowing: Bool = false
    
    /// Returns a list of categories that drives the UI.
    var availableCategories: [ApplicationState.CategoryEntry] {
        return ApplicationState.Category.allCases.map { category in
            return CategoryEntry(category: category)
        }
    }
    
    /// Static property that represents state when no postprocessing items are selected.
    var noProcessingEntry: ApplicationState.ModeEntry = ModeEntry(mode: .noPostProcessing)
    
    /// Convenience method to set the mode from a `ModeEntry`, which is used to represent a mode
    /// in the user interface.
    mutating func setModeFromEntry(_ entry: ModeEntry) {
        mode = entry.mode
    }
    
    /// Changes the current mode to the next mode. When the last mode is selected, resets to the first mode.
    mutating func nextMode() {
        var currentMode = mode.rawValue
        currentMode += 1
        if currentMode >= Mode.allCases.count {
            currentMode = 0
        }
        if let newMode = Mode(rawValue: currentMode) {
            mode = newMode
        }
    }
}
