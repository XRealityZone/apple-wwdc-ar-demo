/*
See LICENSE folder for this sample’s licensing information.

Abstract:
UIView subclass for providing banners
*/

import os
import UIKit

class RoundedBackgroundView: UIView {
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        layer.cornerRadius = 8
        layer.masksToBounds = true
    }
}

// MARK: -

class BannerView: RoundedBackgroundView {
    @IBOutlet var label: UILabel!
    var text: String? {
        didSet {
            label.text = text
        }
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        isHidden = true
    }

    func setText(_ text: String?, animated: Bool) {
        let oldValue = self.text
        guard oldValue != text else {
            return
        }
        if animated == false {
            self.text = text
            self.isHidden = text == nil
        } else {
            switch (oldValue != nil, text != nil) {
            case (false, true):
                // Fade in
                alpha = 0.0
                isHidden = false
                UIView.animate(withDuration: 0.2, animations: {
                    self.alpha = 1.0
                }, completion: { _ in
                    self.text = text
                })
            case (true, false):
                // Fade out
                UIView.animate(withDuration: 0.2, animations: {
                    self.alpha = 0.0
                }, completion: { _ in
                    self.isHidden = true
                    self.alpha = 1.0
                    self.text = text
                })
            default:
                self.text = text
                self.isHidden = text == nil
            }
        }
    }

}
