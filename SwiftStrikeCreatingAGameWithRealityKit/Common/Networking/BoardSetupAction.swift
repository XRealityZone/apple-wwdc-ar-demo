/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Messages relating to shared localization and board location.
*/

import Foundation

struct GameBoardDescription {
    var scale: Float
    var location: GameBoardLocation
    init(scale: Float, location: GameBoardLocation) {
        self.scale = scale
        self.location = location
    }
}

extension GameBoardDescription: Codable {}

enum GameBoardLocation {
    case worldMapData(Data, UUID)
    case manual
    case collaborative(UUID)
}

extension GameBoardLocation: Codable {
    enum CodingKeys: Int, CodingKey {
        case `case`
        case data
        case uuid
    }

    enum CaseIdentifier: Int, Codable {
        case worldMapData
        case manual
        case collaborative
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .worldMapData(data, uuid):
            try container.encode(CaseIdentifier.worldMapData, forKey: .case)
            try container.encode(data, forKey: .data)
            try container.encode(uuid, forKey: .uuid)
        case .manual:
            try container.encode(CaseIdentifier.manual, forKey: .case)
        case let .collaborative(uuid):
            try container.encode(CaseIdentifier.collaborative, forKey: .case)
            try container.encode(uuid, forKey: .uuid)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let caseIdentifier = try container.decode(CaseIdentifier.self, forKey: .case)
        switch caseIdentifier {
        case .worldMapData:
            let data = try container.decode(Data.self, forKey: .data)
            let uuid = try container.decode(UUID.self, forKey: .uuid)
            self = .worldMapData(data, uuid)
        case .manual:
            self = .manual
        case .collaborative:
            let uuid = try container.decode(UUID.self, forKey: .uuid)
            self = .collaborative(uuid)
        }
    }
}

enum BoardSetupAction {
    case requestBoardLocation
    case boardLocation(GameBoardDescription, String)
}

extension BoardSetupAction: Codable {
    enum CodingKeys: Int, CodingKey {
        case `case`
        case description
        case levelInfo
    }

    enum CaseIdentifier: Int, Codable {
        case requestBoardLocation
        case boardLocation
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .requestBoardLocation:
            try container.encode(CaseIdentifier.requestBoardLocation, forKey: .case)
        case let .boardLocation(description, levelInfo):
            try container.encode(CaseIdentifier.boardLocation, forKey: .case)
            try container.encode(description, forKey: .description)
            try container.encode(levelInfo, forKey: .levelInfo)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let caseIdentifier = try container.decode(CaseIdentifier.self, forKey: .case)
        switch caseIdentifier {
        case .requestBoardLocation:
            self = .requestBoardLocation
        case .boardLocation:
            let description = try container.decode(GameBoardDescription.self, forKey: .description)
            let levelInfo = try container.decode(String.self, forKey: .levelInfo)
            self = .boardLocation(description, levelInfo)
        }
    }
}

extension BoardSetupAction: CustomStringConvertible {
    var description: String {
        switch self {
        case .requestBoardLocation:
            return "requestBoardLocation"
        case .boardLocation:
            return "boardLocation"
        }
    }
}
