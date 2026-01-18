/**
 * Game Types - Core Data Models
 *
 * Swift translations of the TypeScript types from @neonloop/core.
 * These are the fundamental data structures for the air hockey game.
 */

import Foundation
import CoreGraphics

// MARK: - Basic Primitives

struct Position: Codable, Equatable {
    var x: CGFloat
    var y: CGFloat

    static let zero = Position(x: 0, y: 0)

    static func + (lhs: Position, rhs: Position) -> Position {
        Position(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    static func - (lhs: Position, rhs: Position) -> Position {
        Position(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }
}

struct Velocity: Codable, Equatable {
    var dx: CGFloat
    var dy: CGFloat

    static let zero = Velocity(dx: 0, dy: 0)

    var magnitude: CGFloat {
        sqrt(dx * dx + dy * dy)
    }

    var normalized: Velocity {
        let mag = magnitude
        guard mag > 0 else { return .zero }
        return Velocity(dx: dx / mag, dy: dy / mag)
    }

    func scaled(by factor: CGFloat) -> Velocity {
        Velocity(dx: dx * factor, dy: dy * factor)
    }
}

// MARK: - Player Identification

enum PlayerID: String, Codable, CaseIterable {
    case player
    case opponent
    case player2
    case opponent2
}

// MARK: - Puck State

struct PuckState: Codable, Equatable {
    var position: Position
    var velocity: Velocity
    var hitCount: Int
    var lastHitBy: PlayerID?
    var id: Int?
    var stuckTime: TimeInterval
    var isFlashing: Bool

    static func initial(config: GameConfig) -> PuckState {
        PuckState(
            position: Position(x: config.tableWidth / 2, y: config.tableHeight / 2),
            velocity: .zero,
            hitCount: 0,
            lastHitBy: nil,
            id: nil,
            stuckTime: 0,
            isFlashing: false
        )
    }
}

// MARK: - Game Configuration

struct GameConfig: Codable {
    var tableWidth: CGFloat
    var tableHeight: CGFloat
    var paddleRadius: CGFloat
    var puckRadius: CGFloat
    var goalWidth: CGFloat
    var maxScore: Int
    var puckSpeed: CGFloat
    var paddleSpeed: CGFloat
    var friction: CGFloat
    var speedIncreasePerHit: CGFloat
    var maxSpeedMultiplier: CGFloat

    static let `default` = GameConfig(
        tableWidth: 400,
        tableHeight: 600,
        paddleRadius: 30,
        puckRadius: 15,
        goalWidth: 100,
        maxScore: 7,
        puckSpeed: 8,
        paddleSpeed: 10,
        friction: 0.99,
        speedIncreasePerHit: 0.15,
        maxSpeedMultiplier: 3
    )

    static let doubles = GameConfig(
        tableWidth: 500,
        tableHeight: 700,
        paddleRadius: 25,
        puckRadius: 15,
        goalWidth: 120,
        maxScore: 7,
        puckSpeed: 8,
        paddleSpeed: 10,
        friction: 0.99,
        speedIncreasePerHit: 0.15,
        maxSpeedMultiplier: 3
    )
}

// MARK: - Difficulty & AI

enum Difficulty: String, Codable, CaseIterable {
    case easy
    case medium
    case hard

    var displayName: String {
        rawValue.capitalized
    }
}

struct AIConfig: Codable {
    var reactionDelay: TimeInterval  // seconds
    var accuracy: CGFloat            // 0-1
    var maxSpeed: CGFloat
    var predictionSkill: CGFloat     // 0-1

    static func config(for difficulty: Difficulty) -> AIConfig {
        switch difficulty {
        case .easy:
            return AIConfig(
                reactionDelay: 0.2,
                accuracy: 0.6,
                maxSpeed: 3,
                predictionSkill: 0.3
            )
        case .medium:
            return AIConfig(
                reactionDelay: 0.1,
                accuracy: 0.8,
                maxSpeed: 5,
                predictionSkill: 0.6
            )
        case .hard:
            return AIConfig(
                reactionDelay: 0.05,
                accuracy: 0.95,
                maxSpeed: 7,
                predictionSkill: 0.9
            )
        }
    }
}

// MARK: - Game Mode

enum GameMode: String, Codable, CaseIterable {
    case oneVsOne = "1v1"
    case twoVsTwo = "2v2"
    case defense

    var displayName: String {
        switch self {
        case .oneVsOne: return "1 vs 1"
        case .twoVsTwo: return "2 vs 2"
        case .defense: return "Defense"
        }
    }
}

// MARK: - Game State

struct GameState: Codable, Equatable {
    var puck: PuckState
    var puck2: PuckState?
    var playerPaddle: Position
    var opponentPaddle: Position
    var player2Paddle: Position?
    var opponent2Paddle: Position?
    var playerScore: Int
    var opponentScore: Int
    var isPlaying: Bool
    var isPaused: Bool
    var winner: PlayerID?
    var lastGoalScorer: PlayerID?
    var playAreaShift: CGFloat

    static func initial(config: GameConfig) -> GameState {
        GameState(
            puck: .initial(config: config),
            puck2: nil,
            playerPaddle: Position(x: config.tableWidth / 2, y: config.tableHeight - 50),
            opponentPaddle: Position(x: config.tableWidth / 2, y: 50),
            player2Paddle: nil,
            opponent2Paddle: nil,
            playerScore: 0,
            opponentScore: 0,
            isPlaying: false,
            isPaused: false,
            winner: nil,
            lastGoalScorer: nil,
            playAreaShift: 0
        )
    }
}

// MARK: - Game Events

enum GameEventType: String, Codable {
    case paddleHit
    case wallHit
    case goalScored
    case gameStarted
    case gamePaused
    case gameResumed
    case gameEnded
    case puckBoosted
}

struct GameEvent: Codable {
    let type: GameEventType
    var scorer: PlayerID?
    var winner: PlayerID?
    var intensity: CGFloat?
    var puckId: Int?
}

// MARK: - Input

struct InputState: Codable {
    var up: Bool = false
    var down: Bool = false
    var left: Bool = false
    var right: Bool = false

    var isActive: Bool {
        up || down || left || right
    }

    var direction: Position {
        var x: CGFloat = 0
        var y: CGFloat = 0
        if left { x -= 1 }
        if right { x += 1 }
        if up { y -= 1 }
        if down { y += 1 }
        return Position(x: x, y: y)
    }
}

// MARK: - Network Messages

enum NetMessageType: String, Codable {
    case input
    case stateSnapshot
    case playerJoined
    case playerLeft
    case gameStart
    case gameEnd
}

struct NetMessage: Codable {
    let type: NetMessageType
    let senderId: String
    let timestamp: TimeInterval
}

struct InputMessage: Codable {
    let type: NetMessageType = .input
    let senderId: String
    let timestamp: TimeInterval
    let position: Position?
    let direction: InputState?
}

struct StateSnapshotMessage: Codable {
    let type: NetMessageType = .stateSnapshot
    let senderId: String
    let timestamp: TimeInterval
    let state: GameState
}

// MARK: - Minimal Snapshot (for reduced bandwidth)

struct MinimalSnapshot: Codable {
    var px: CGFloat   // puck x
    var py: CGFloat   // puck y
    var pdx: CGFloat  // puck dx
    var pdy: CGFloat  // puck dy
    var ppx: CGFloat  // player paddle x
    var ppy: CGFloat  // player paddle y
    var opx: CGFloat  // opponent paddle x
    var opy: CGFloat  // opponent paddle y
    var ps: Int       // player score
    var os: Int       // opponent score
    var t: TimeInterval // timestamp

    init(state: GameState, timestamp: TimeInterval) {
        px = state.puck.position.x
        py = state.puck.position.y
        pdx = state.puck.velocity.dx
        pdy = state.puck.velocity.dy
        ppx = state.playerPaddle.x
        ppy = state.playerPaddle.y
        opx = state.opponentPaddle.x
        opy = state.opponentPaddle.y
        ps = state.playerScore
        os = state.opponentScore
        t = timestamp
    }

    func apply(to state: inout GameState) {
        state.puck.position = Position(x: px, y: py)
        state.puck.velocity = Velocity(dx: pdx, dy: pdy)
        state.playerPaddle = Position(x: ppx, y: ppy)
        state.opponentPaddle = Position(x: opx, y: opy)
        state.playerScore = ps
        state.opponentScore = os
    }
}
