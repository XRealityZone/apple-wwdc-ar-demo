/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A view used to house the AR screen space annotation.
*/

import UIKit

/// A subclass of UIView that will be inserted into the scene in "Screen Space", that composes the sticky note's visual appearance.
class StickyNoteView: UIView {
    var textView: UITextView!
    // ...
    
    /// Convenience accessor to the StickyNoteView's parent StickyNoteEntity.
    weak var stickyNote: StickyNoteEntity!
    
    /// Subviews which are used to construct the StickyNoteView.
    var blurView: UIVisualEffectView!
    
    /// Indicates whether the sticky note is currently inside of the trash zone.
    var isInTrashZone = false
    
    /// Indicates whether the placeholder text has been removed.
    var placeHolderWasRemoved = false
    
    /// States to indicate the current offset between the panning finger and the StickNoteView's origin, used for smooth panning.
    var xOffset: CGFloat = 0
    var yOffset: CGFloat = 0
    
    /// Stores the most recent non-editing frame of the StickyNoteView
    var lastFrame: CGRect!
    
    /// Creates a StickyNoteView given the specified frame and its associated StickyNoteEntity.
    init(frame: CGRect, note: StickyNoteEntity) {
        super.init(frame: frame)
        
        stickyNote = note
        
        setupBlurViewContainer()
        setupTextView()
        
        lastFrame = frame
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    fileprivate func setupBlurViewContainer() {
        blurView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        blurView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(blurView)
        blurView.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        blurView.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true
        blurView.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true
        blurView.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        blurView.layer.cornerRadius = 20
        blurView.layer.masksToBounds = true
    }
    
    fileprivate func setupTextView() {
        let paddingSpace: CGFloat = 30
        
        textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        blurView.contentView.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: blurView.contentView.topAnchor, constant: paddingSpace),
            textView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: paddingSpace),
            textView.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -paddingSpace),
            textView.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor, constant: -paddingSpace)
        ])
        textView.backgroundColor = .clear
        textView.font = UIFont(name: "Helvetica", size: 22)
        textView.textAlignment = .left
        textView.addDismissButton()
        textView.text = "New Note..."
        textView.textColor = .darkGray
    }
    
}
