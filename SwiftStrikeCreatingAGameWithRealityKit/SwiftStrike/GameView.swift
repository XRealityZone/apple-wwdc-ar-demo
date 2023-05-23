/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Main game view
*/

import RealityKit
import UIKit

class GameView: ARView {
    @IBOutlet weak var quitButton: UIButton!
    @IBOutlet weak var debugButton: UIButton!
    @IBOutlet weak var topBanner: BannerView!
    @IBOutlet weak var bottomBanner: BannerView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var countdownTimerView: CountdownTimerView!
    @IBOutlet weak var pinStatusView: PinStatusView!
    @IBOutlet weak var rightPinStatusView: PinStatusView!
    @IBOutlet weak var leftPinStatusView: PinStatusView!
}
