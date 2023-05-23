/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The sample app's primary action button.
*/

import UIKit

class GameActionButton: UIButton {
    
    enum GameAction {
        case tapToPlay
        case retry
        case nextLevel
    }

    var gameAction: GameAction {
        didSet {
            updateImage()
        }
    }
    
    required init?(coder: NSCoder) {
        self.gameAction = .tapToPlay
        super.init(coder: coder)
    }
    
    private func updateImage() {
        switch gameAction {
        case .tapToPlay:
            setImage(UIImage(named: "TapToPlay"), for: .normal)
            setImage(UIImage(named: "TapToPlay-pressed"), for: .highlighted)
        case .retry:
            setImage(UIImage(named: "Retry"), for: .normal)
            setImage(UIImage(named: "Retry-pressed"), for: .highlighted)
        case .nextLevel:
            setImage(UIImage(named: "NextLevel"), for: .normal)
            setImage(UIImage(named: "NextLevel-pressed"), for: .highlighted)
        }
    }

}
