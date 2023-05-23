/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Audio addons for RealityKit
*/

import Foundation
import os.log
import RealityKit

extension AudioPlaybackController {
    /// This is a convenience to fade out a sound and then stop it after the fade out completes.
    func fadeOutAndStop(duration: TimeInterval) {
        self.fade(to: .off, duration: duration)
        DispatchQueue.main.asyncAfter(wallDeadline: .now() + duration + 0.05) { [weak self] in
            guard let self = self, self.entity != nil else { return }
            self.stop()
        }
    }
}

extension AudioPlaybackController.Decibel {
    /// This is a convenience for a decibel level where the signal is off, which is represented by -infinifty in a log scale.
    static var off: Self {
        return -Self.infinity
    }
}
