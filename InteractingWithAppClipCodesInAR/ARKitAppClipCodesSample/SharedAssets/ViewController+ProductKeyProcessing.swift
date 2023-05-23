/*
See LICENSE folder for this sample’s licensing information.

Abstract:
View Controller extensions that process App Clip Code URL-path-components
by initiating associated file loads.
*/

import UIKit
import RealityKit
import ARKit
import Combine

extension ViewController {
    func process(productKey: String, initializePreview: Bool = true) {
        if let imageURL = imageURLFor[productKey] {
            process(imageURL: imageURL, productKey: productKey, initializeImageAnchor: initializePreview)
        }
        if let modelURL = modelURLFor[productKey] {
            process(modelURL: modelURL, productKey: productKey, initializeModel: initializePreview)
        }
    }
    ///- Tag: ProcessImageURL
    func process(imageURL: URL, productKey: String, initializeImageAnchor: Bool) {
        if initializeImageAnchor {
            let imageLoader = CachingWebLoader.shared.cachedWebLoad(url: imageURL) { [weak self] url in
                DispatchQueue.global(qos: .userInitiated).async {
                    if
                        let dataProvider = CGDataProvider(url: url as CFURL),
                        let image = CGImage(
                            jpegDataProviderSource: dataProvider,
                            decode: nil,
                            shouldInterpolate: false,
                            intent: .absoluteColorimetric
                        )
                    {
                        let modelAnchorImage = ARReferenceImage(
                            image,
                            orientation: .up,
                            // Note: the width of the sample seed packet is about 8cm.
                            physicalWidth: 0.08
                        )
                        modelAnchorImage.validate { (error) in
                            if let error = error {
                                debugPrint("Reference image validation failed: \(error.localizedDescription)")
                            } else {
                                // The sample app associates image anchors with the correct product model by mapping product key to image name.
                                modelAnchorImage.name = productKey
                                let referenceImageSet = Set<ARReferenceImage>(arrayLiteral: modelAnchorImage)
                                self?.runARSession(withAdditionalReferenceImages: referenceImageSet)
                                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + DispatchTimeInterval.milliseconds(500)) {
                                    self?.appClipCodeCoachingOverlay.text = "View the seed packet."
                                    self?.appClipCodeCoachingOverlay.setCoachingViewHidden(false)
                                }
                            }
                        }
                    } else {
                        debugPrint("Reference image file initialization failed")
                    }
                }
            }
            imageLoader.start()
        } else {
            CachingWebLoader.shared.cachedWebLoad(url: imageURL).start()
        }
    }
    
    func process(modelURL: URL, productKey: String, initializeModel: Bool = true) {
        let contentLoad = CachingWebLoader.shared.cachedWebLoad(url: modelURL)
        if initializeModel {
            contentLoad.addSuccessHandler({ [weak self] url in
                initializeUSDZ(urlForUSDZ: url) {didSucceed, initializedEntity in
                    if didSucceed, self?.modelFor[productKey] == nil {
                        self?.modelFor[productKey] = initializedEntity!
                        // If the App Clip Code's image anchor exists, present the related model.
                        if let imageAnchorForModel = self?.imageAnchorFor[productKey], let self = self {
                            self.modelFor[productKey]!.present(on: imageAnchorForModel)
                        }
                    } else {
                        self?.showInformationLabel("Error initializing the model")
                    }
                }
            })
            contentLoad.addProgressHandler({ [weak self]
                (progress) -> Void in
                if progress < 1 {
                    self?.showInformationLabel("Loading your preview\n \(Int(progress * 100))%")
                } else {
                    self?.setInformationLabelHidden(true)
                }
            })
            contentLoad.addErrorHandler({  [weak self]
                (errorMessage) -> Void in
                    self?.showInformationLabel(errorMessage)
            })
        }
        contentLoad.start()
    }
}
