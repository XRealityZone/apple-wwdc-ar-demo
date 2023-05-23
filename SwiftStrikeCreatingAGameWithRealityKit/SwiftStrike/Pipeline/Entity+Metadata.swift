/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Entity+Metadata
*/

import Foundation
import RealityKit

struct EntityMetadata {
    enum Kind: String {
        case physicsGroup = "physGrp"
        case physicsSphere = "physSphere"
        case physicsHull = "physHull"
        case physicsBox = "physBox"
        case occlusion = "occlusion"
        case shadow = "shadow"
        case glow = "glow"
        case billboard = "billboard"
    }
    let kind: Kind
    let localName: String
}

extension Entity {

    var pipelineMetadata: EntityMetadata? {
        return metadata(from: self.name)
    }

    var kind: EntityMetadata.Kind? {
        return pipelineMetadata?.kind
    }
}

private let pattern = #"^(?<localName>.+_(?<kind>.+))__(.+)$"#
private let expression = try! NSRegularExpression(pattern: pattern)

private func metadata(from name: String) -> EntityMetadata? {
    guard let match = expression.firstMatch(in: name, options: [], range: NSRange((name.startIndex..<name.endIndex), in: name)) else {
//        print("# \(name) doesn't match pattern")
        return nil
    }
    let kindString = String(name[Range(match.range(withName: "kind"), in: name)!])
    let skippedKindString = ["physics"]
    guard !skippedKindString.contains(kindString) else {
        return nil
    }

    guard var kind = EntityMetadata.Kind(rawValue: kindString) else {
        print("#### Unknown kind: \"\(kindString)\" in \(name)")
        return nil
    }
    let localName = String(name[Range(match.range(withName: "localName"), in: name)!])
    let glowKindString = "glow"
    if kindString == glowKindString {
        // Unfortunately the billboard names are inconsistent, and
        // not intended to be identified like a kind.  We need to
        // look at the part of the name just before the "_glow"
        // in order to identify this ModelEntity as a billboard.
        let underlineGlowCount = glowKindString.count + 1
        let glowIndex = localName.index(localName.endIndex, offsetBy: -underlineGlowCount)
        let nameBeforeGlow = localName[..<glowIndex]
        let billboardNames = [
            "floorcard",    // Ball
            "floorCard",    // Pins
            "outlinecard",  // Ball
            "billboard"     // Pins
        ]

        if billboardNames.first(where: { nameBeforeGlow.hasSuffix($0) }) != nil {
            kind = EntityMetadata.Kind.billboard
        } else {
            return nil
        }
    }
    return EntityMetadata(kind: kind, localName: localName)
}
