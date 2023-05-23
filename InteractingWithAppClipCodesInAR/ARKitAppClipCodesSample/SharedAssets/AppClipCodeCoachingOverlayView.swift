/*
See LICENSE folder for this sample’s licensing information.

Abstract:
An object that presents the user with textual instructions to guide them through the App Clip Code scanning process.
*/

import UIKit
import ARKit
import RealityKit

///- Tag: AppClipCodeCoachingOverlayView
class AppClipCodeCoachingOverlayView: UILabel {
    init(parentView: UIView) {
        super.init(frame: .zero)
        text = "Scan code to start"
        textColor = .white
        textAlignment = .center
        numberOfLines = 2
        font = .boldSystemFont(ofSize: 16)
        backgroundColor = UIColor.black.withAlphaComponent(0.5)
        adjustsFontSizeToFitWidth = true
        isHidden = false
        alpha = 1
        
        translatesAutoresizingMaskIntoConstraints = false
        parentView.addSubview(self)
        self.fillParentView()
    }
    
    func setCoachingViewHidden(_ hide: Bool) {
        DispatchQueue.main.async { [weak self] in
            UIView.animate(withDuration: 0.25, delay: 0, options: [.beginFromCurrentState], animations: { [weak self] in
                self?.alpha = hide ? 0 : 1
            })
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(frame: .zero)
    }
}
