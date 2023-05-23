/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Debugging output for Entity
*/

import Foundation
import os.log
import RealityKit

extension Entity {

    static var customComponents = [Component.Type]()
    private static let beginLineSpace = String(repeating: " ", count: 3)
    private static let tabSpace = String(repeating: " ", count: 3)
    private func knownComponentNames(types: [Component.Type]) -> [String] {
        return types.compactMap { components[$0].map { String(describing: $0) } }
    }
    @discardableResult
    func dump(log: OSLog? = nil, depth: Int = 0, depthLimit: Int = Int.max, short: Bool = false) -> String {
        //
        // using OSLog as a parameter is bad production practice because
        // it breaks optimization of string memory and removes the ability
        // to get the location of the log statement (since it is always in
        // this method, not the callsite)
        // So, this code is wrapped with DEBUG
        //
        #if DEBUG
        guard depth <= depthLimit else { return "" }

        let knownComponentTypes: [Component.Type] = [
            PhysicsBodyComponent.self,
            ModelComponent.self,
            CollisionComponent.self,
            PhysicsMotionComponent.self
        ] + Entity.customComponents

        let absolutePosition = position(relativeTo: nil)

        let shortAttributes: [(String, String?)?] = [
            (String(describing: type(of: self)), nil),
            (name.isEmpty ? "<noname>" : "\"\(name)\"", nil),
            (isOwner ? "owwner" : "net", nil),
            (isEnabled ? "enabled" : "disabled", nil)
        ]
        let fullAttributes: [(String, String?)?] = [
            (String(describing: type(of: self)), nil),
            name.isEmpty ? nil : ("name", "\"\(name)\""),
            position.isAlmostZero ? nil : ("position (abs)", "\(absolutePosition.terseDescription)"),
            transform.isAlmostIdentity ? nil : ("transform", "\(self.transform.terseDescription)"),
            isActive ? nil : ("inactive", nil),
            isEnabled ? nil : ("disabled", nil),
            knownComponentNames(types: knownComponentTypes).isEmpty ? nil
                : ("components", "[" + knownComponentNames(types: knownComponentTypes).joined(separator: ", ") + "]")
        ]
        let whichAttributes = short ? shortAttributes : fullAttributes
        let body = whichAttributes
            .compactMap { $0 }
            .map { (key, value) in
                if let value = value {
                    return "\(key): \(value)"
                } else {
                    return key
                }
            }
            .joined(separator: ", ")

        let indent = String(repeating: Entity.tabSpace, count: depth)
        var dumpLog = ""
        if let log = log {
            os_log(.default, log: log, "%s", "\(Entity.beginLineSpace)\(indent)\(body)")
        } else {
            dumpLog = "\(Entity.beginLineSpace)\(indent)\(body)\n"
        }

        for child in children {
            dumpLog += child.dump(log: log, depth: depth + 1, depthLimit: depthLimit, short: short)
        }

        return dumpLog
        #else
        return ""
        #endif
    }
}

private let formatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.minimumIntegerDigits = 1
    formatter.maximumFractionDigits = 3
    return formatter
}()

private func f <T>(_ value: T) -> String where T: FloatingPoint {
    return formatter.string(for: value)!
}

private extension Float {
    func isAlmost(_ value: Float) -> Bool {
        let delta = Float.ulpOfOne
        return self >= value - delta && self <= value + delta
    }
}

private extension SIMD3 where Scalar == Float {

    var isAlmostZero: Bool {
        return x.isAlmost(0.0) && y.isAlmost(0.0) && z.isAlmost(0.0)
    }

    var isAlmostIdentity: Bool {
        return x.isAlmost(1.0) && y.isAlmost(1.0) && z.isAlmost(1.0)
    }
}

extension SIMD2 where Scalar == Float {
    var terseDescription: String { "\(x), \(y)" }
}

extension SIMD3 where Scalar == Float {
    var terseDescription: String { "\(x), \(y), \(z)" }
}

extension SIMD3 where Scalar == Float {
    var xzDescription: String { "\(x), \(z)" }
}

private extension simd_quatf {

    var isAlmostIdentity: Bool {
        return vector.x.isAlmost(0.0) && vector.y.isAlmost(0.0) && vector.z.isAlmost(0.0) && vector.w.isAlmost(1.0)
    }
}

extension simd_quatf {

    var terseDescription: String {
        return String(describing: self)
    }
}

private extension Transform {

    var isAlmostIdentity: Bool {
        return scale.isAlmostIdentity && rotation.isAlmostIdentity && translation.isAlmostZero
    }

    var terseDescription: String {
        if isAlmostIdentity {
            return "identity"
        }
        var components: [String] = []
        if !scale.isAlmostIdentity {
            components.append("scale: \(scale.terseDescription)")
        }
        if !rotation.isAlmostIdentity {
            components.append("rotation: \(rotation.terseDescription)")
        }
        if !translation.isAlmostZero {
            components.append("translation: \(translation.terseDescription)")
        }
        return components.joined(separator: ", ")
    }
}
