/*
See LICENSE folder for this sample’s licensing information.

Abstract:
SplashView
*/

import UIKit

struct AnimationStill {
    let image: String
    let duration: Double
}

class SplashView: UIView {

    var stopped = false

    @IBOutlet var imageView: UIImageView!

    func startAnimating() {
        imageView.contentMode = .scaleAspectFill
        stopped = false
        animate(0)
    }

    func stopAnimating() {
        stopped = true
    }

    func animate(_ currentIndex: Int) {
        guard !stopped else { return }
        let index = currentIndex >= VisualMode.count ? 0 : currentIndex
        let still = UserSettings.visualMode.still(at: index)
        set(still: still)
        let when = DispatchTime.now() + still.duration
        DispatchQueue.main.asyncAfter(deadline: when) { [weak self] in
            self?.animate(index + 1)
        }
    }

    func set(still: AnimationStill) {
        imageView.image = UIImage(named: still.image)
    }

}

extension VisualMode {
    static let count = 9
    static let cosmicStills: [AnimationStill] = [
        AnimationStill(image: "splashScreen_cosmic_crop_0001", duration: 77.0 / 60.0),
        AnimationStill(image: "splashScreen_cosmic_crop_0078", duration: 20.0 / 60.0),
        AnimationStill(image: "splashScreen_cosmic_crop_0098", duration: 20.0 / 60.0),
        AnimationStill(image: "splashScreen_cosmic_crop_0118", duration: 22.0 / 60.0),
        AnimationStill(image: "splashScreen_cosmic_crop_0140", duration: 46.0 / 60.0),
        AnimationStill(image: "splashScreen_cosmic_crop_0186", duration: 14.0 / 60.0),
        AnimationStill(image: "splashScreen_cosmic_crop_0200", duration: 10.0 / 60.0),
        AnimationStill(image: "splashScreen_cosmic_crop_0210", duration: 20.0 / 60.0),
        AnimationStill(image: "splashScreen_cosmic_crop_0230", duration: 20.0 / 60.0),
        AnimationStill(image: "splashScreen_cosmic_crop_0250", duration: 30.0 / 60.0)
    ]
    func still(at index: Int) -> AnimationStill {
        // This is a quick hack to make sure we always use the cosmic stills.
        return VisualMode.cosmicStills[index]
    }
}
