/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The sample app's current level indicator.
*/

import UIKit

class OverlayView: UIView {

    @IBOutlet var imageView: UIImageView!

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        layer.cornerRadius = 14
        layer.masksToBounds = true
    }
    
}
