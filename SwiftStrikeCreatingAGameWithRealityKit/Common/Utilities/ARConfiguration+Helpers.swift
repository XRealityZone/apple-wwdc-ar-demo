/*
See LICENSE folder for this sample’s licensing information.

Abstract:
ARConfiguration helpers
*/

import ARKit
import os.log

enum ARConfigurationConstants {
    // this variable is used to shadow the currently intended state
    // of the people occlusion flag in the ARView ARConfiguration
    // UserSettingConstants.peopleOcclusion is used to filter this
    // value before it is actually set into the ARConfiguration
    fileprivate(set) static var peopleOcclusion: Bool = false
}

extension ARConfiguration {
    func updatePeopleOcclusion() {
        guard ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) else { return }

        // filter setting based on debug setting
        let value = ARConfigurationConstants.peopleOcclusion && UserSettingsTunables.peopleOcclusion.value

        os_log(.default, log: GameLog.arFlags, "updatePeopleOccusion() Updating framSemantics peopleOccusion to %s", "\(value)")

        switch value {
        case true: frameSemantics.insert(.personSegmentationWithDepth)
        case false: frameSemantics.remove(.personSegmentationWithDepth)
        }
    }

    func setPeopleOcclusion(_ newValue: Bool) {
        os_log(.default, log: GameLog.arFlags, "setPeopleOcclusion() intended peopleOccusion set to %s", "\(newValue)")
        ARConfigurationConstants.peopleOcclusion = newValue
        updatePeopleOcclusion()
    }

    var peopleOcclusion: Bool { frameSemantics.contains(.personSegmentationWithDepth) }
}
