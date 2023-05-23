/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Managemenent of session information communication to the user.
*/

import UIKit
import ARKit

extension ViewController {
    
    func updateSessionInfoLabel(for trackingState: ARCamera.TrackingState) {
        // Update the UI to provide feedback on the state of the AR experience.
        var message: String = ""
        let stateString = state == .testing ? "Detecting" : "Scanning"
        
        switch trackingState {
            
        case .notAvailable:
            message = "\(stateString) not possible: \(trackingState.presentationString)"
            startTimeOfLastMessage = Date().timeIntervalSince1970
            expirationTimeOfLastMessage = 3.0
            
        case .limited:
            message = "\(stateString) might not work: \(trackingState.presentationString)"
            startTimeOfLastMessage = Date().timeIntervalSince1970
            expirationTimeOfLastMessage = 3.0
            
        default:
            // No feedback needed when tracking is normal.
            // Defer clearing the info label if the last message hasn't reached its expiration time.
            let now = Date().timeIntervalSince1970
            if let startTimeOfLastMessage = startTimeOfLastMessage,
                let expirationTimeOfLastMessage = expirationTimeOfLastMessage,
                now - startTimeOfLastMessage < expirationTimeOfLastMessage {
                let timeToKeepLastMessageOnScreen = expirationTimeOfLastMessage - (now - startTimeOfLastMessage)
                startMessageExpirationTimer(duration: timeToKeepLastMessageOnScreen)
            } else {
                // Otherwise hide the info label immediately.
                self.sessionInfoLabel.text = ""
                self.sessionInfoView.isHidden = true
            }
            return
        }
        
        sessionInfoLabel.text = message
        sessionInfoView.isHidden = false
    }
    
    func displayMessage(_ message: String, expirationTime: TimeInterval) {
        startTimeOfLastMessage = Date().timeIntervalSince1970
        expirationTimeOfLastMessage = expirationTime
        DispatchQueue.main.async {
            self.sessionInfoLabel.text = message
            self.sessionInfoView.isHidden = false
            self.startMessageExpirationTimer(duration: expirationTime)
        }
    }
    
    func startMessageExpirationTimer(duration: TimeInterval) {
        cancelMessageExpirationTimer()
        
        messageExpirationTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { (timer) in
            self.cancelMessageExpirationTimer()
            self.sessionInfoLabel.text = ""
            self.sessionInfoView.isHidden = true
            
            self.startTimeOfLastMessage = nil
            self.expirationTimeOfLastMessage = nil
        }
    }
    
    func cancelMessageExpirationTimer() {
        messageExpirationTimer?.invalidate()
        messageExpirationTimer = nil
    }
}
