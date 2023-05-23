/*
See LICENSE folder for this sample’s licensing information.

Abstract:
An object that displays a status message.
*/

import UIKit

class OverlayLabel: UILabel {
    
    let extraInset: CGFloat = 80
    
    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        bounds = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width / 2, height: UIScreen.main.bounds.height / 8)
        font = .boldSystemFont(ofSize: 16)
        textAlignment = .center
        numberOfLines = 2
        textColor = UIColor.white
        alpha = 0
        backgroundColor = UIColor.black.withAlphaComponent(0.5)
        isOpaque = true
        clipsToBounds = true
        layer.cornerRadius = 12
    }

    required init?(coder: NSCoder) {
        super.init(frame: .zero)
    }
        
    override func drawText(in rect: CGRect) {
        let insets = UIEdgeInsets(top: extraInset, left: extraInset, bottom: extraInset, right: extraInset)
        super.drawText(in: rect.inset(by: insets))
    }
    
    override var intrinsicContentSize: CGSize {
        var superSize = super.intrinsicContentSize
        superSize.width += (extraInset * 2)
        superSize.height += (extraInset)
        return superSize
    }
}
