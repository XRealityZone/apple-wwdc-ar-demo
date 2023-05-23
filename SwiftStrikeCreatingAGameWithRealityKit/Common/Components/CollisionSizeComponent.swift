/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Collision Size Component
*/

import RealityKit

enum CollisionSizeShape: Codable {
    case capsule(totalHeight: Float, radius: Float, mass: Float)
    case sphere(radius: Float, mass: Float)

    var totalHeight: Float {
        switch self {
        case .capsule(let totalHeight, _, _): return totalHeight
        case .sphere(let radius, _): return radius
        }
    }

    var cylinderHeight: Float {
        switch self {
        case .capsule(let totalHeight, let radius, _): return totalHeight - (2.0 * radius)
        case .sphere(let radius, _): return radius
        }
    }

    var radius: Float {
        switch self {
        case .capsule(_, let radius, _): return radius
        case .sphere(let radius, _): return radius
        }
    }

    var mass: Float {
        switch self {
        case .capsule(_, _, let mass): return mass
        case .sphere(_, let mass): return mass
        }
    }

    enum CaseIdentifier: Int, Codable {
        case capsule
        case sphere
    }

    enum CodingKeys: Int, CodingKey {
        case shape
        case totalHeight
        case radius
        case mass
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let caseIdentifier = try container.decode(CaseIdentifier.self, forKey: .shape)
        switch caseIdentifier {
        case .capsule:
            let totalHeight = try container.decode(Float.self, forKey: .totalHeight)
            let radius = try container.decode(Float.self, forKey: .radius)
            let mass = try container.decode(Float.self, forKey: .mass)
            self = .capsule(totalHeight: totalHeight, radius: radius, mass: mass)
        case .sphere:
            let radius = try container.decode(Float.self, forKey: .radius)
            let mass = try container.decode(Float.self, forKey: .mass)
            self = .sphere(radius: radius, mass: mass)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .capsule(let height, let radius, let mass):
            try container.encode(CaseIdentifier.capsule, forKey: .shape)
            try container.encode(height, forKey: .totalHeight)
            try container.encode(radius, forKey: .radius)
            try container.encode(mass, forKey: .mass)
        case .sphere(let radius, let mass):
            try container.encode(CaseIdentifier.sphere, forKey: .shape)
            try container.encode(radius, forKey: .radius)
            try container.encode(mass, forKey: .mass)
        }
    }
}

struct CollisionSizeComponent: Component {
    var shape: CollisionSizeShape = .sphere(radius: 1.0, mass: 1.0)
}

extension CollisionSizeComponent: Codable {}

protocol HasCollisionSize where Self: Entity {}

extension HasCollisionSize {
    var collisionSize: CollisionSizeComponent {
        get { return components[CollisionSizeComponent.self] ?? CollisionSizeComponent() }
        set { components[CollisionSizeComponent.self] = newValue }
    }
    var totalHeight: Float { return collisionSize.shape.totalHeight }
    var cylinderHeight: Float { return collisionSize.shape.totalHeight - (2.0 * collisionSize.shape.radius) }
    var radius: Float { return collisionSize.shape.radius }
    var mass: Float { return collisionSize.shape.mass }
}
