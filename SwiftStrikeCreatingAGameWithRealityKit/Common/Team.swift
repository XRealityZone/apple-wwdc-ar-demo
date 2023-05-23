/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Team abstraction, will probably have to tie it to TeamIdentifier better
*/

import UIKit

let noneString = "none"
let teamAString = "Team A"
let teamBString = "Team B"

enum Team {
    case none
    case teamA
    case teamB
}

extension Team: RawRepresentable, Codable, CaseIterable {
    typealias RawValue = String

    init?(rawValue: RawValue) {
        switch rawValue {
        case noneString: self = .none
        case teamAString: self = .teamA
        case teamBString: self = .teamB
        default: return nil
        }
    }

    init?(rawValue: Int) {
        let newValue: Team
        switch rawValue {
        case 0: newValue = .none
        case 1: newValue = .teamA
        case 2: newValue = .teamB
        default: return nil
        }
        self = newValue
    }

    var rawValue: RawValue {
        switch self {
        case .none: return noneString
        case .teamA: return teamAString
        case .teamB: return teamBString
        }
    }

    var intValue: Int {
        switch self {
        case .none: return 0
        case .teamA: return 1
        case .teamB: return 2
        }
    }

    var description: String {
        switch self {
        case .none: return NSLocalizedString("none", comment: "Team name")
        case .teamA: return NSLocalizedString("TeamA-Blue", comment: "Team name")
        case .teamB: return NSLocalizedString("TeamB-Yellow", comment: "Team name")
        }
    }

    var color: UIColor {
        switch self {
        case .none: return .white
        case .teamA: return UIColor(hexRed: 45, green: 128, blue: 208) // srgb
        case .teamB: return UIColor(hexRed: 239, green: 153, blue: 55)
        }
    }

    var opponent: Team {
        switch self {
        case .none: return .none
        case .teamA: return .teamB
        case .teamB: return .teamA
        }
    }

    static func defaultTeam(for zValue: Float) -> Team {
        return zValue < 0.0 ? .teamB : .teamA
    }

    var zSign: Float { return self == .teamA ? 1.0 : -1.0 }
}

extension UIColor {
    convenience init(hexRed: UInt8, green: UInt8, blue: UInt8) {
        let fred = CGFloat(hexRed) / CGFloat(255)
        let fgreen = CGFloat(green) / CGFloat(255)
        let fblue = CGFloat(blue) / CGFloat(255)

        self.init(red: fred, green: fgreen, blue: fblue, alpha: 1.0)
    }
}
