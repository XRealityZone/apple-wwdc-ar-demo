/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Keyboard helper functions.
*/

import UIKit

// MARK: - Utilites for ViewController

extension ViewController {
    
    // MARK: - Keyboard Utilities
    
    // Gets the height of the keyboard every time it appears
    @objc
    func keyboardIsPoppingUp(notification: NSNotification) {
        
        if let keyboardFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            
            lastKeyboardHeight = keyboardFrame.height
            
            // Animates the selected sticky view based on the new keyboard height.
            if let selectedStickyView {
                animateStickyViewToEditingFrame(selectedStickyView,
                                                keyboardHeight: keyboardFrame.height)
            }
        }
    }
    
}

// MARK: - Utilites for UITextView

extension UITextView {
    
    // Adds a UIToolbar with a dismiss button as UITextView's inputAccesssoryView (which appears on top of the keyboard)
    func addDismissButton() {
        let dismissToolbar = UIToolbar(frame: CGRect(origin: .zero, size: CGSize(width: UIScreen.main.bounds.width, height: 44)))
        dismissToolbar.barStyle = .default
        let dismissButton = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(dismissKeyboard))
        dismissToolbar.items = [dismissButton]
        inputAccessoryView = dismissToolbar
    }
    
    @objc
    func dismissKeyboard() {
        endEditing(true)
    }
    
}
