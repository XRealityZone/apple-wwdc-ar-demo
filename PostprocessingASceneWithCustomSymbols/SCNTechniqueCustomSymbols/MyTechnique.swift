/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Definition of the SCNTechnique.
*/

import Foundation

/// - Tag: MyTechnique

enum MyTechnique {
    static let techniqueDictionary: [String: Any] = [
        
        /// - Tag: Symbols Key
        
        "symbols": [
            "color_weights_symbol": [
                "type": "vec3"
            ],
            "time_symbol": [
                "type": "float"
            ]
        ],
        
        "passes": [
            "a_pass": [
                "draw": "DRAW_QUAD",
                "metalVertexShader": "myVertexShader",
                "metalFragmentShader": "myFragmentShader",
                /// - Tag: Inputs Key
                "inputs": [
                    "color": "COLOR",
                    "color_weights": "color_weights_symbol",
                    "time": "time_symbol"
                ],
                "outputs": [
                    "color": "COLOR"
                ]
            ]
        ],
        
        "sequence": [
            "a_pass"
        ]
    ]
}
