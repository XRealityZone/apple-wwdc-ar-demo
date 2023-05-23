/*
See LICENSE folder for this sample’s licensing information.

Abstract:
UIView helper functions.
*/

import UIKit

extension UIView {
    
    // Fades a view in linearly with a given duration
    func fadeIn(duration: TimeInterval) {
        UIViewPropertyAnimator(duration: duration, curve: .linear) {
            self.alpha = 1
        }.startAnimation()
    }
    
    // Fades a view out linearly with a given duration
    func fadeOut(duration: TimeInterval) {
        UIViewPropertyAnimator(duration: duration, curve: .linear) {
            self.alpha = 0
        }.startAnimation()
    }
    
    // Traverses a UIView's superviews until a superview of the specified type is found
    func firstSuperViewOfType<T: UIView>(_ type: T.Type) -> T? {
        var view = self
        while let superview = view.superview {
            if let viewOfType = superview as? T {
                return viewOfType
            } else {
                view = superview
            }
        }
        return nil
    }
    
}
