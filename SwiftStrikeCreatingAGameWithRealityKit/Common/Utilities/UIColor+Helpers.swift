/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Helpers for UIColor
*/

import UIKit

extension UIColor {
    var rgbComponents: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var rValue: CGFloat = 0.0
        var gValue: CGFloat = 0.0
        var bValue: CGFloat = 0.0
        var aValue: CGFloat = 0.0
        if getRed(&rValue, green: &gValue, blue: &bValue, alpha: &aValue) {
            return (rValue, gValue, bValue, aValue)
        }
        return (0.0, 0.0, 0.0, 0.0)
    }
    func asRGBAString() -> String {
        let (rValue, gValue, bValue, aValue) = rgbComponents
        let output: String = "(\(Int(rValue * 255)), \(Int(gValue * 255)), \(Int(bValue * 255)), \(Int(aValue * 255)))"
        return output
    }
}
