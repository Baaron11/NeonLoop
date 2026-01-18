/**
 * Network Messages - Protocol Definitions
 *
 * Defines the message types and structures used for
 * multiplayer communication between host and clients.
 */

import Foundation

// MARK: - Message Protocol

protocol NetMessageProtocol: Codable {
    var messageType: NetMessageType { get }
    var senderId: String { get }
    var timestamp: TimeInterval { get }
}

// MARK: - Player Joined Message

struct PlayerJoinedMessage: NetMessageProtocol {
    let messageType: NetMessageType = .playerJoined
    let senderId: String
    let timestamp: TimeInterval
    let playerName: String
    let playerId: PlayerID
}

// MARK: - Player Left Message

struct PlayerLeftMessage: NetMessageProtocol {
    let messageType: NetMessageType = .playerLeft
    let senderId: String
    let timestamp: TimeInterval
}

// MARK: - Game Start Message

struct GameStartMessage: NetMessageProtocol {
    let messageType: NetMessageType = .gameStart
    let senderId: String
    let timestamp: TimeInterval
    let config: GameConfig
    let initialState: GameState
}

// MARK: - Game End Message

struct GameEndMessage: NetMessageProtocol {
    let messageType: NetMessageType = .gameEnd
    let senderId: String
    let timestamp: TimeInterval
    let winner: PlayerID
    let finalScore: (player: Int, opponent: Int)

    enum CodingKeys: String, CodingKey {
        case messageType, senderId, timestamp, winner, playerScore, opponentScore
    }

    init(senderId: String, timestamp: TimeInterval, winner: PlayerID, finalScore: (player: Int, opponent: Int)) {
        self.senderId = senderId
        self.timestamp = timestamp
        self.winner = winner
        self.finalScore = finalScore
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        senderId = try container.decode(String.self, forKey: .senderId)
        timestamp = try container.decode(TimeInterval.self, forKey: .timestamp)
        winner = try container.decode(PlayerID.self, forKey: .winner)
        let playerScore = try container.decode(Int.self, forKey: .playerScore)
        let opponentScore = try container.decode(Int.self, forKey: .opponentScore)
        finalScore = (playerScore, opponentScore)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(messageType, forKey: .messageType)
        try container.encode(senderId, forKey: .senderId)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(winner, forKey: .winner)
        try container.encode(finalScore.player, forKey: .playerScore)
        try container.encode(finalScore.opponent, forKey: .opponentScore)
    }
}

// MARK: - Message Encoding/Decoding

struct MessageCoder {
    /// Encode any message to Data
    static func encode<T: NetMessageProtocol>(_ message: T) throws -> Data {
        try JSONEncoder().encode(message)
    }

    /// Decode message type from Data
    static func decodeType(from data: Data) -> NetMessageType? {
        struct TypeWrapper: Decodable {
            let messageType: NetMessageType?
            let type: NetMessageType?

            var resolvedType: NetMessageType? {
                messageType ?? type
            }
        }

        guard let wrapper = try? JSONDecoder().decode(TypeWrapper.self, from: data) else {
            return nil
        }
        return wrapper.resolvedType
    }

    /// Decode specific message type
    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }
}

// MARK: - Network Utilities

struct NetworkUtils {
    /// Generate a unique player ID
    static func generatePlayerId() -> String {
        UUID().uuidString
    }

    /// Generate a room code
    static func generateRoomCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in chars.randomElement()! })
    }

    /// Current timestamp
    static var currentTimestamp: TimeInterval {
        Date.timeIntervalSinceReferenceDate
    }
}
