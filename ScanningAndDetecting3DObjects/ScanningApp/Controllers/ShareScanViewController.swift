/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Customized share sheet for exporting scanned AR reference objects.
*/

import UIKit

class ShareScanViewController: UIActivityViewController {
    
    init(sourceView: UIView, sharedObject: Any) {
        super.init(activityItems: [sharedObject], applicationActivities: nil)
        
        // Set up popover presentation style
        modalPresentationStyle = .popover
        popoverPresentationController?.sourceView = sourceView
        popoverPresentationController?.sourceRect = sourceView.bounds
        
        self.excludedActivityTypes = [.markupAsPDF, .openInIBooks, .message, .print,
                                      .addToReadingList, .saveToCameraRoll, .assignToContact,
                                      .copyToPasteboard, .postToTencentWeibo, .postToWeibo,
                                      .postToVimeo, .postToFlickr, .postToTwitter, .postToFacebook]
    }
    
    deinit {
        // Restart the session in case it was interrupted by the share sheet
        if let configuration = ViewController.instance?.sceneView.session.configuration,
            ViewController.instance?.state == .testing {
            ViewController.instance?.sceneView.session.run(configuration)
        }
    }
}
