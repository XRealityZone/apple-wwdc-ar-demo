/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Extensions of UIView
*/

import UIKit

extension UIView {

    //autoFillParentView() adds constraints to self in order to make self auto fill its superview
    //NOTE:  you must add self to the superview prior to calling this on self
    func autoFillParentView() {
        guard let parentView = self.superview else {
            assertionFailure("Error! no superview, call `addSubview(view: UIView)` on parent before calling 'autoFillParentView()'.")
            return
        }

        translatesAutoresizingMaskIntoConstraints = false
        topAnchor.constraint(equalTo: parentView.topAnchor, constant: 0).isActive = true
        bottomAnchor.constraint(equalTo: parentView.bottomAnchor, constant: 0).isActive = true
        leadingAnchor.constraint(equalTo: parentView.leadingAnchor, constant: 0).isActive = true
        trailingAnchor.constraint(equalTo: parentView.trailingAnchor, constant: 0).isActive = true
    }

}

