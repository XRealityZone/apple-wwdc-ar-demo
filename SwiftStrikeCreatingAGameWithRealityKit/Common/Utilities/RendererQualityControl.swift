/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Renderer Quality Control
*/

import ARKit

private enum DeviceType {

    enum GPUClass {
        // Desktop:
        /// Weak, probably mobile chip
        case integratedGPU
        /// Entry-level GPU
        case discreteGPULevel1
        /// Powerful GPU by 2019 standards
        case discreteGPULevel2

        // Mobile:
        case a9_or_a10
        case a11
        case a12_and_up
        case unknown
    }

    static let isPhone = UIDevice.current.userInterfaceIdiom == .phone
    static let gpuClass: GPUClass = {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return .unknown
        }

        if device.supportsFeatureSet(.iOS_GPUFamily5_v1) {
            return .a12_and_up
        } else if device.supportsFeatureSet(.iOS_GPUFamily4_v1) {
            return .a11
        } else if device.supportsFeatureSet(.iOS_GPUFamily3_v1) {
            return .a9_or_a10
        } else {
            #if !targetEnvironment(simulator)
            assertionFailure("Encountered a device where the GPU could not be inferred")
            #endif
            return .unknown
        }
    }()
}

class RendererQualityControlTunable {
    /// boundsEnable
    /// enable or disable bounds
    static var powerManagementEnabled = TunableBool("Enable GPU PowerManagement", def: true)
}

class RendererQualityControl {

    /// A multiplier applied to the native resolution to reduce fragment shader work. Lower is worse. Max is 1.0.
    static func renderResolutionFactor() -> Float {
        if !RendererQualityControlTunable.powerManagementEnabled.value {
            return 1.0
        }

        /*
         The logic below is based on the following observation:
         1. iPhones have smaller screens with high DPI, so upsampling artifacts
         will be very small on screen. Additionally, rendering at a resolution higher than
         the camera feed is not an economical way to use resources when we are
         already required to continually refresh.

         2. On any iOS device, if we are outside of nominal thermal state, we should
         cut back on how much render work we are doing.

         3. Old devices do a lot better with just fewer pixels on screen (of course)
         */

        let maxForDevice: Float
        switch DeviceType.gpuClass {
        case .a9_or_a10:
            maxForDevice = 0.65
        case .a11:
            maxForDevice = 0.75
        case .a12_and_up:
            maxForDevice = 1.0
        default:
            maxForDevice = 1.0
        }

        let preferredFactor: Float
        if DeviceType.isPhone {
            // In AR for small screens, we use a low resolution so that we don't burn up battery.
            preferredFactor = 0.5
        } else if ProcessInfo.processInfo.thermalState != .nominal {
            // In thermal conditions for AR, we should cut back too. This is a bad place to be.
            // We wouldn't cut back resolution in VR mode because it doesn't render as often.
            preferredFactor = maxForDevice * 0.75
        } else {
            // Appears there is no reason to throttle
            preferredFactor = 1.0
        }

        return min(maxForDevice, preferredFactor)
    }

}
