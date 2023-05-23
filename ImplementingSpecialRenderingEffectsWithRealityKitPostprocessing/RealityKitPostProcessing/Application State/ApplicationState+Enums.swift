/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Enumerations used to maintain application state.
*/

import Foundation
extension ApplicationState {
    
    struct CategoryEntry: Identifiable, Hashable {
        let id = UUID()
        let category: Category
        var modes: [ModeEntry] {
            return category.modes.map { mode in
                return ModeEntry(mode: mode)
            }
        }
    }
    
    struct ModeEntry: Identifiable, Hashable {
        let id = UUID()
        let mode: Mode
    }
    
    enum Category: UInt8, CaseIterable, CustomStringConvertible, Hashable {
        case metal
        case metalPerformanceShader
        case coreImage
        case spriteKit
        case metalPlusCoreImage
        
        var description: String {
            switch self {
                    
                case .metal:
                    return "Metal"
                case .metalPerformanceShader:
                    return "Metal Performance Shaders"
                case .coreImage:
                    return "Core Image"
                case .spriteKit:
                    return "SpriteKit"
                case .metalPlusCoreImage:
                    return "Metal with Core Image"
            }
        }
        
        var modes: [Mode] {
            switch self {
                    
                case .metal:
                    return [
                        .metalPixelate,
                        .metalGreyscale,
                        .metalNightVision,
                        .metalInvert,
                        .metalPosterize,
                        .metalVignette,
                        .metalScanlines
                        ]
                case .metalPerformanceShader:
                    return [
                        .mpsGaussianBlur,
                        .mpsSobel,
                        .mpsBloom,
                        .mpsLaplacian
                    ]
                case .coreImage:
                    return [
                        .ciComicEffect,
                        .ciVintageTransfer,
                        .ciGlassDistortion,
                        .ciDotScreen,
                        .ciLineScreen,
                        .ciCrystallize,
                        .ciZoomBlur,
                        .ciHueAdjust,
                        .ciVibrance,
                        .ciFalseColor,
                        .ciNoir,
                        .ciDrost,
                        .ciHoleDistortion
                    ]
                case .spriteKit:
                    return [.spriteKit]
                case .metalPlusCoreImage:
                    return [.mPointillize]
            }
        }
    }
    
    enum Mode: UInt8, CaseIterable, CustomStringConvertible, Hashable {
        
        case noPostProcessing = 0
        
        // Custom Metal Shaders
        case metalPixelate
        case metalGreyscale
        case metalInvert
        case metalPosterize
        case metalVignette
        case metalScanlines
        case metalNightVision
        
        // Metal Performance Shaders
        case mpsGaussianBlur
        case mpsSobel
        case mpsBloom
        case mpsLaplacian
        
        // CoreImage
        case ciComicEffect
        case ciVintageTransfer
        case ciGlassDistortion
        case ciDotScreen
        case ciLineScreen
        case ciCrystallize
        case ciZoomBlur
        case ciHueAdjust
        case ciVibrance
        case ciFalseColor
        case ciNoir
        case ciDrost
        case ciHoleDistortion
        
        // SpriteKit
        case spriteKit
        
        // Multiple Postprocessing Technologies
        case mPointillize
        
        /// Returns a string that describes the current postprocessing mode.
        var description: String {
            switch self {
                case .noPostProcessing:
                    return "Postprocessing Off"
                    
                case .metalPixelate:
                    return "Pixelate"
                case .metalGreyscale:
                    return "Greyscale"
                case .metalInvert:
                    return "Color Invert"
                case .metalPosterize:
                    return "Posterize"
                case .metalVignette:
                    return "Vignette"
                case .metalScanlines:
                    return "Scan Lines"
                case .metalNightVision:
                    return "Night Vision"
                    
                case .mpsGaussianBlur:
                    return "Blur"
                case .mpsSobel:
                    return "Sobel"
                case .mpsBloom:
                    return "Bloom"
                case .mpsLaplacian:
                    return "Laplacian"
                    
                case .ciComicEffect:
                    return "Comic"
                case .ciVintageTransfer:
                    return "Vintage"
                case .ciGlassDistortion:
                    return "Glass Distortion"
                case .ciDotScreen:
                    return "Dot Screen"
                case .ciLineScreen:
                    return "Line Screen"
                case .ciCrystallize:
                    return "Crystallize"
                case .ciZoomBlur:
                    return "Zoom Blur"
                case .ciHueAdjust:
                    return "Hue Adjust"
                case .ciVibrance:
                    return "Vibrance"
                case .ciFalseColor:
                    return "False Color"
                case .ciNoir:
                    return "Noir (B&W Film)"
                case .ciDrost:
                    return "Drost"
                case .ciHoleDistortion:
                    return "Hole Distortion"
                    
                case .spriteKit:
                    return "SpriteKit Render"
                    
                case .mPointillize:
                    return "Depth Masked Pointillize"
            }
        }
    }
}
