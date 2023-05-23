/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Helpers for CGRect
*/

import UIKit

extension CGRect {
    var center: CGPoint { return CGPoint(x: origin.x + (size.width * 0.5), y: origin.y + (size.height * 0.5)) }
}
