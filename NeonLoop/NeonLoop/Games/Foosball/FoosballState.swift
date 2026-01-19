/**
 * Foosball State - Data Models for the Foosball Game
 *
 * Contains all state structures and configuration for the Foosball game.
 * Players control one side (4 rods), AI controls the other side (4 rods).
 * Players cooperate to beat the AI.
 */

import Foundation
import SwiftUI

// MARK: - Configuration

struct FoosballConfig {
    let tableWidth: CGFloat           // 280
    let tableHeight: CGFloat          // 450 (taller than wide)
    let goalWidth: CGFloat            // 90
    let goalDepth: CGFloat            // 15
    let rodSlideRange: CGFloat        // How far rods can slide (-1 to 1 normalized)
    let manWidth: CGFloat             // 10
    let manHeight: CGFloat            // 25
    let ballRadius: CGFloat           // 8
    let kickDuration: TimeInterval    // 0.15 for forward, 0.25 for pull
    let kickPowerMin: CGFloat         // Minimum impulse
    let kickPowerMax: CGFloat         // Maximum impulse
    let ballFriction: CGFloat         // 0.98
    let kickCooldown: CGFloat         // Cooldown after kick
    let rodBarHeight: CGFloat         // Height of the rod bar for collision

    static let `default` = FoosballConfig(
        tableWidth: 280,
        tableHeight: 450,
        goalWidth: 90,
        goalDepth: 15,
        rodSlideRange: 1.0,
        manWidth: 10,
        manHeight: 25,
        ballRadius: 8,
        kickDuration: 0.15,
        kickPowerMin: 4.0,
        kickPowerMax: 12.0,
        ballFriction: 0.98,
        kickCooldown: 0.3,
        rodBarHeight: 3
    )
}

// MARK: - Match Format

enum MatchFormat: Equatable {
    case firstTo(Int)                 // First to X goals
    case timed(TimeInterval)          // Play for X seconds

    var displayName: String {
        switch self {
        case .firstTo(let goals):
            return "First to \(goals)"
        case .timed(let seconds):
            let minutes = Int(seconds) / 60
            return "\(minutes) min"
        }
    }
}

// MARK: - Rod Type

enum RodType: String, CaseIterable, Identifiable {
    case goalie
    case defense
    case midfield
    case attack

    var id: String { rawValue }

    var menCount: Int {
        switch self {
        case .goalie: return 1
        case .defense: return 2
        case .midfield: return 5
        case .attack: return 3
        }
    }

    var menSpacing: CGFloat {
        switch self {
        case .goalie: return 0        // Only 1 man
        case .defense: return 80      // 2 men spread wide
        case .midfield: return 45     // 5 men across
        case .attack: return 60       // 3 men spread
        }
    }

    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Kick State

enum KickType: Equatable {
    case forward      // Swipe up - quick forward rotation
    case pullShot     // Swipe down - pull back then snap forward

    var duration: TimeInterval {
        switch self {
        case .forward: return 0.15
        case .pullShot: return 0.25
        }
    }

    var powerMultiplier: CGFloat {
        switch self {
        case .forward: return 1.0
        case .pullShot: return 1.4    // Pull shots are more powerful
        }
    }
}

enum KickState: Equatable {
    case idle
    case kicking(type: KickType, progress: CGFloat)  // progress 0-1
    case cooldown(remaining: CGFloat)

    var isKicking: Bool {
        if case .kicking = self { return true }
        return false
    }

    var currentRotation: CGFloat {
        switch self {
        case .idle:
            return 0
        case .kicking(let type, let progress):
            switch type {
            case .forward:
                // Rotate forward 180 degrees (pi radians)
                return progress * .pi
            case .pullShot:
                // Pull back first (0-0.3), then snap forward (0.3-1.0)
                if progress < 0.3 {
                    // Pull back 45 degrees
                    return -(progress / 0.3) * (.pi / 4)
                } else {
                    // Snap forward 180 degrees + the 45 we pulled back
                    let forwardProgress = (progress - 0.3) / 0.7
                    return -(.pi / 4) + forwardProgress * ((.pi / 4) + .pi)
                }
            }
        case .cooldown:
            return .pi  // Stay rotated after kick
        }
    }
}

// MARK: - Foosball Rod

struct FoosballRod: Identifiable, Equatable {
    let id: String
    let rodType: RodType
    let isPlayerSide: Bool            // true = human team, false = AI
    let yPosition: CGFloat            // Fixed Y on table
    var xOffset: CGFloat              // -1 to 1, current slide position
    var kickState: KickState
    var controlledBy: String?         // Player ID, nil for AI
    var linkedWith: [String]          // IDs of other rods this moves with

    // Computed: positions of each foosman on this rod
    func foosmenPositions(config: FoosballConfig) -> [CGPoint] {
        let count = rodType.menCount
        let spacing = rodType.menSpacing
        let maxSlide = (config.tableWidth / 2) - (CGFloat(count - 1) * spacing / 2) - config.manWidth / 2 - 10
        let centerX = xOffset * maxSlide

        return (0..<count).map { index in
            let offsetFromCenter = CGFloat(index) - CGFloat(count - 1) / 2
            let x = centerX + offsetFromCenter * spacing
            return CGPoint(x: x, y: yPosition)
        }
    }

    // Get the slide bounds for this rod
    func slideBounds(config: FoosballConfig) -> ClosedRange<CGFloat> {
        return -1.0...1.0
    }

    static func == (lhs: FoosballRod, rhs: FoosballRod) -> Bool {
        lhs.id == rhs.id &&
        lhs.xOffset == rhs.xOffset &&
        lhs.kickState == rhs.kickState &&
        lhs.controlledBy == rhs.controlledBy
    }
}

// MARK: - Foosman

struct Foosman: Identifiable {
    let id: String
    let rodId: String
    let index: Int                    // 0, 1, 2... position on rod
    var rotation: CGFloat             // Current rotation angle (radians)

    func hitbox(rod: FoosballRod, config: FoosballConfig) -> CGRect {
        let positions = rod.foosmenPositions(config: config)
        guard index < positions.count else { return .zero }
        let pos = positions[index]

        // Adjust hitbox based on rotation
        let rotatedWidth = abs(cos(rotation)) * config.manWidth + abs(sin(rotation)) * config.manHeight
        let rotatedHeight = abs(sin(rotation)) * config.manWidth + abs(cos(rotation)) * config.manHeight

        return CGRect(
            x: pos.x - rotatedWidth / 2,
            y: pos.y - rotatedHeight / 2,
            width: rotatedWidth,
            height: rotatedHeight
        )
    }
}

// MARK: - Foosball Ball

struct FoosballBall: Equatable {
    var position: CGPoint
    var velocity: CGVector
    var lastHitBy: String?            // Rod ID, for preventing double-hits
    var lastHitTime: TimeInterval     // Time of last hit

    static let initial = FoosballBall(
        position: .zero,
        velocity: .zero,
        lastHitBy: nil,
        lastHitTime: 0
    )
}

// MARK: - Game Phase

enum FoosballPhase: Equatable {
    case settings                     // Pre-game config
    case countdown(Int)               // Showing countdown (3, 2, 1)
    case playing
    case goalScored(playerScored: Bool)
    case gameOver(playerWon: Bool)

    var isActive: Bool {
        switch self {
        case .playing: return true
        default: return false
        }
    }
}

// MARK: - Goal Result

enum FoosballGoalResult: Equatable {
    case playerScored  // Ball in AI goal
    case aiScored      // Ball in player goal
}

// MARK: - Difficulty

enum FoosballDifficulty: String, CaseIterable {
    case easy
    case medium
    case hard

    var reactionDelay: TimeInterval {
        switch self {
        case .easy: return 0.4
        case .medium: return 0.2
        case .hard: return 0.05
        }
    }

    var accuracy: CGFloat {
        switch self {
        case .easy: return 0.6
        case .medium: return 0.8
        case .hard: return 0.95
        }
    }

    var kickTiming: CGFloat {
        switch self {
        case .easy: return 0.5
        case .medium: return 0.75
        case .hard: return 0.95
        }
    }

    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Player Assignment

struct FoosballPlayerAssignment: Equatable {
    let playerId: String
    let playerIndex: Int
    let rodTypes: [RodType]           // Which rods this player controls

    var displayName: String {
        "Player \(playerIndex + 1)"
    }

    var rodNames: String {
        rodTypes.map { $0.displayName }.joined(separator: " + ")
    }
}

// MARK: - Main Game State

@Observable
final class FoosballState {
    var config: FoosballConfig
    var playerRods: [FoosballRod]     // Human team's 4 rods
    var aiRods: [FoosballRod]         // AI team's 4 rods
    var ball: FoosballBall
    var playerScore: Int
    var aiScore: Int
    var timeRemaining: TimeInterval?  // For timed matches
    var phase: FoosballPhase
    var playerCount: Int
    var matchFormat: MatchFormat
    var difficulty: FoosballDifficulty
    var playerAssignments: [FoosballPlayerAssignment]

    // For countdown animation
    var countdownValue: Int = 3

    var allRods: [FoosballRod] { playerRods + aiRods }

    init(config: FoosballConfig = .default) {
        self.config = config
        self.playerRods = []
        self.aiRods = []
        self.ball = .initial
        self.playerScore = 0
        self.aiScore = 0
        self.timeRemaining = nil
        self.phase = .settings
        self.playerCount = 1
        self.matchFormat = .firstTo(5)
        self.difficulty = .medium
        self.playerAssignments = []

        setupRods()
    }

    // MARK: - Rod Setup

    private func setupRods() {
        let halfHeight = config.tableHeight / 2

        // Player rods (bottom half, defending bottom goal)
        // From closest to player goal to furthest
        playerRods = [
            FoosballRod(
                id: "player_goalie",
                rodType: .goalie,
                isPlayerSide: true,
                yPosition: halfHeight - 30,
                xOffset: 0,
                kickState: .idle,
                controlledBy: nil,
                linkedWith: []
            ),
            FoosballRod(
                id: "player_defense",
                rodType: .defense,
                isPlayerSide: true,
                yPosition: halfHeight - 80,
                xOffset: 0,
                kickState: .idle,
                controlledBy: nil,
                linkedWith: []
            ),
            FoosballRod(
                id: "player_midfield",
                rodType: .midfield,
                isPlayerSide: true,
                yPosition: halfHeight - 150,
                xOffset: 0,
                kickState: .idle,
                controlledBy: nil,
                linkedWith: []
            ),
            FoosballRod(
                id: "player_attack",
                rodType: .attack,
                isPlayerSide: true,
                yPosition: halfHeight - 220,
                xOffset: 0,
                kickState: .idle,
                controlledBy: nil,
                linkedWith: []
            )
        ]

        // AI rods (top half, defending top goal)
        // From closest to AI goal to furthest
        aiRods = [
            FoosballRod(
                id: "ai_goalie",
                rodType: .goalie,
                isPlayerSide: false,
                yPosition: -halfHeight + 30,
                xOffset: 0,
                kickState: .idle,
                controlledBy: nil,
                linkedWith: []
            ),
            FoosballRod(
                id: "ai_defense",
                rodType: .defense,
                isPlayerSide: false,
                yPosition: -halfHeight + 80,
                xOffset: 0,
                kickState: .idle,
                controlledBy: nil,
                linkedWith: []
            ),
            FoosballRod(
                id: "ai_midfield",
                rodType: .midfield,
                isPlayerSide: false,
                yPosition: -halfHeight + 150,
                xOffset: 0,
                kickState: .idle,
                controlledBy: nil,
                linkedWith: []
            ),
            FoosballRod(
                id: "ai_attack",
                rodType: .attack,
                isPlayerSide: false,
                yPosition: -halfHeight + 220,
                xOffset: 0,
                kickState: .idle,
                controlledBy: nil,
                linkedWith: []
            )
        ]
    }

    // MARK: - Player Assignment

    func assignRodsToPlayers(playerCount: Int) {
        self.playerCount = playerCount
        playerAssignments = []

        // Reset all rod assignments
        for i in 0..<playerRods.count {
            playerRods[i].controlledBy = nil
            playerRods[i].linkedWith = []
        }

        switch playerCount {
        case 1:
            // P1: All 4 rods (linked)
            let playerId = "player_0"
            for i in 0..<playerRods.count {
                playerRods[i].controlledBy = playerId
                playerRods[i].linkedWith = playerRods.filter { $0.id != playerRods[i].id }.map { $0.id }
            }
            playerAssignments = [
                FoosballPlayerAssignment(playerId: playerId, playerIndex: 0, rodTypes: RodType.allCases)
            ]

        case 2:
            // P1: Goalie + Defense (linked), P2: Midfield + Attack (linked)
            let p1Id = "player_0"
            let p2Id = "player_1"

            playerRods[0].controlledBy = p1Id  // Goalie
            playerRods[1].controlledBy = p1Id  // Defense
            playerRods[0].linkedWith = ["player_defense"]
            playerRods[1].linkedWith = ["player_goalie"]

            playerRods[2].controlledBy = p2Id  // Midfield
            playerRods[3].controlledBy = p2Id  // Attack
            playerRods[2].linkedWith = ["player_attack"]
            playerRods[3].linkedWith = ["player_midfield"]

            playerAssignments = [
                FoosballPlayerAssignment(playerId: p1Id, playerIndex: 0, rodTypes: [.goalie, .defense]),
                FoosballPlayerAssignment(playerId: p2Id, playerIndex: 1, rodTypes: [.midfield, .attack])
            ]

        case 3:
            // P1: Goalie, P2: Defense + Midfield (linked), P3: Attack
            let p1Id = "player_0"
            let p2Id = "player_1"
            let p3Id = "player_2"

            playerRods[0].controlledBy = p1Id  // Goalie

            playerRods[1].controlledBy = p2Id  // Defense
            playerRods[2].controlledBy = p2Id  // Midfield
            playerRods[1].linkedWith = ["player_midfield"]
            playerRods[2].linkedWith = ["player_defense"]

            playerRods[3].controlledBy = p3Id  // Attack

            playerAssignments = [
                FoosballPlayerAssignment(playerId: p1Id, playerIndex: 0, rodTypes: [.goalie]),
                FoosballPlayerAssignment(playerId: p2Id, playerIndex: 1, rodTypes: [.defense, .midfield]),
                FoosballPlayerAssignment(playerId: p3Id, playerIndex: 2, rodTypes: [.attack])
            ]

        case 4:
            // P1: Goalie, P2: Defense, P3: Midfield, P4: Attack
            for i in 0..<4 {
                let playerId = "player_\(i)"
                playerRods[i].controlledBy = playerId
            }

            playerAssignments = [
                FoosballPlayerAssignment(playerId: "player_0", playerIndex: 0, rodTypes: [.goalie]),
                FoosballPlayerAssignment(playerId: "player_1", playerIndex: 1, rodTypes: [.defense]),
                FoosballPlayerAssignment(playerId: "player_2", playerIndex: 2, rodTypes: [.midfield]),
                FoosballPlayerAssignment(playerId: "player_3", playerIndex: 3, rodTypes: [.attack])
            ]

        default:
            break
        }
    }

    // MARK: - Game Control

    func startCountdown() {
        countdownValue = 3
        phase = .countdown(3)
        resetBall(towardPlayer: Bool.random())
    }

    func startPlaying() {
        phase = .playing
    }

    func resetBall(towardPlayer: Bool) {
        // Reset ball at center with slight velocity toward the team that was scored on
        ball.position = .zero
        let speed: CGFloat = 2.0
        let angle = CGFloat.random(in: -0.3...0.3)  // Slight random angle
        let direction: CGFloat = towardPlayer ? 1.0 : -1.0
        ball.velocity = CGVector(
            dx: sin(angle) * speed,
            dy: direction * cos(angle) * speed
        )
        ball.lastHitBy = nil
    }

    func goalScored(by result: FoosballGoalResult) {
        switch result {
        case .playerScored:
            playerScore += 1
            phase = .goalScored(playerScored: true)
        case .aiScored:
            aiScore += 1
            phase = .goalScored(playerScored: false)
        }

        // Check for game over
        if case .firstTo(let target) = matchFormat {
            if playerScore >= target {
                phase = .gameOver(playerWon: true)
            } else if aiScore >= target {
                phase = .gameOver(playerWon: false)
            }
        }
    }

    func checkTimedGameOver() {
        if case .timed = matchFormat, let time = timeRemaining, time <= 0 {
            let playerWon = playerScore > aiScore
            phase = .gameOver(playerWon: playerWon)
        }
    }

    func resetGame() {
        playerScore = 0
        aiScore = 0
        if case .timed(let duration) = matchFormat {
            timeRemaining = duration
        }
        setupRods()
        assignRodsToPlayers(playerCount: playerCount)
        phase = .settings
    }

    // MARK: - Rod Control

    func moveRod(rodId: String, xOffset: CGFloat) {
        // Find the rod
        if let index = playerRods.firstIndex(where: { $0.id == rodId }) {
            let clampedOffset = max(-1.0, min(1.0, xOffset))
            playerRods[index].xOffset = clampedOffset

            // Move linked rods
            for linkedId in playerRods[index].linkedWith {
                if let linkedIndex = playerRods.firstIndex(where: { $0.id == linkedId }) {
                    playerRods[linkedIndex].xOffset = clampedOffset
                }
            }
        }
    }

    func kickRod(rodId: String, type: KickType) {
        // Find the rod
        if let index = playerRods.firstIndex(where: { $0.id == rodId }) {
            guard case .idle = playerRods[index].kickState else { return }
            playerRods[index].kickState = .kicking(type: type, progress: 0)

            // Kick linked rods
            for linkedId in playerRods[index].linkedWith {
                if let linkedIndex = playerRods.firstIndex(where: { $0.id == linkedId }) {
                    if case .idle = playerRods[linkedIndex].kickState {
                        playerRods[linkedIndex].kickState = .kicking(type: type, progress: 0)
                    }
                }
            }
        }
    }

    // Get rods controlled by a specific player
    func rodsForPlayer(_ playerId: String) -> [FoosballRod] {
        playerRods.filter { $0.controlledBy == playerId }
    }

    // Get player assignment for a player ID
    func assignmentForPlayer(_ playerId: String) -> FoosballPlayerAssignment? {
        playerAssignments.first { $0.playerId == playerId }
    }

    // MARK: - Computed Properties

    var isGameOver: Bool {
        if case .gameOver = phase { return true }
        return false
    }

    var playerWon: Bool? {
        if case .gameOver(let won) = phase { return won }
        return nil
    }

    var scoreDisplay: String {
        "\(playerScore) - \(aiScore)"
    }

    var timeDisplay: String? {
        guard let time = timeRemaining else { return nil }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
