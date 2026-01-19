/**
 * BilliardDodge State - Data Models
 *
 * Contains all state structures and configuration for the Billiard Dodge game.
 * Players are billiard balls trying to survive CPU shots. They must predict
 * and dodge the cue ball trajectory each round.
 */

import Foundation
import SwiftUI

// MARK: - Configuration

struct BilliardDodgeConfig {
    let tableWidth: CGFloat         // 400 (2:1 ratio)
    let tableHeight: CGFloat        // 200
    let ballRadius: CGFloat         // 10
    let pocketRadius: CGFloat       // 18
    let maxForce: CGFloat           // Maximum ball velocity
    let friction: CGFloat           // Velocity multiplier per frame (0.98)
    let countdownDuration: Double   // 5.0 seconds
    let railBounce: CGFloat         // Coefficient of restitution for rails
    let ballBounce: CGFloat         // Coefficient of restitution for ball-ball collisions

    static let `default` = BilliardDodgeConfig(
        tableWidth: 400,
        tableHeight: 200,
        ballRadius: 10,
        pocketRadius: 18,
        maxForce: 12.0,
        friction: 0.985,
        countdownDuration: 5.0,
        railBounce: 0.85,
        ballBounce: 0.95
    )

    /// Returns number of rounds needed to win based on player count
    func roundsToWin(playerCount: Int) -> Int {
        switch playerCount {
        case 1: return 8
        case 2: return 10
        case 3: return 12
        default: return 15
        }
    }

    /// Returns pocket positions (4 corners + 2 sides)
    func pocketPositions() -> [CGPoint] {
        let inset: CGFloat = pocketRadius * 0.3
        return [
            // Corners
            CGPoint(x: inset, y: inset),                                    // Top-left
            CGPoint(x: tableWidth - inset, y: inset),                       // Top-right
            CGPoint(x: inset, y: tableHeight - inset),                      // Bottom-left
            CGPoint(x: tableWidth - inset, y: tableHeight - inset),         // Bottom-right
            // Sides
            CGPoint(x: tableWidth / 2, y: inset),                           // Top-center
            CGPoint(x: tableWidth / 2, y: tableHeight - inset)              // Bottom-center
        ]
    }
}

// MARK: - Billiard Ball

struct BilliardBall: Identifiable, Equatable {
    let id: String
    var position: CGPoint
    var velocity: CGVector
    var color: Color
    var playerId: String?           // nil for cue ball
    var isPocketed: Bool
    var isEliminated: Bool          // Stays true once pocketed (for players)
    var playerIndex: Int            // For display purposes (0-3)

    var displayLabel: String {
        if playerId == nil {
            return "CUE"
        }
        return "P\(playerIndex + 1)"
    }

    static func playerBall(id: String, playerId: String, position: CGPoint, playerIndex: Int) -> BilliardBall {
        let colors: [Color] = [.cyan, .pink, .green, .orange]
        return BilliardBall(
            id: id,
            position: position,
            velocity: .zero,
            color: colors[playerIndex % colors.count],
            playerId: playerId,
            isPocketed: false,
            isEliminated: false,
            playerIndex: playerIndex
        )
    }

    static func cueBall(position: CGPoint) -> BilliardBall {
        BilliardBall(
            id: "cue_ball",
            position: position,
            velocity: .zero,
            color: .white,
            playerId: nil,
            isPocketed: false,
            isEliminated: false,
            playerIndex: -1
        )
    }
}

// MARK: - Player Move

struct PlayerMove: Equatable {
    var angle: CGFloat              // Radians, 0 = right
    var force: CGFloat              // 0.0 to 1.0
    var isLocked: Bool

    static let empty = PlayerMove(angle: 0, force: 0, isLocked: false)
}

// MARK: - CPU Shot

struct CPUShot: Equatable {
    let angle: CGFloat              // Direction cue ball will go
    let power: CGFloat              // 0.0 to 1.0
    let targetBallId: String?       // For AI logic tracking

    static let empty = CPUShot(angle: 0, power: 0, targetBallId: nil)
}

// MARK: - CPU Difficulty

enum CPUDifficulty: Int {
    case easy = 1       // Rounds 1-3
    case medium = 2     // Rounds 4-6
    case hard = 3       // Rounds 7-10
    case expert = 4     // Rounds 11+

    var accuracy: CGFloat {
        switch self {
        case .easy: return 0.70
        case .medium: return 0.85
        case .hard: return 0.95
        case .expert: return 0.98
        }
    }

    var shotPower: ClosedRange<CGFloat> {
        switch self {
        case .easy: return 0.3...0.5
        case .medium: return 0.4...0.7
        case .hard: return 0.5...0.85
        case .expert: return 0.6...1.0
        }
    }

    static func forRound(_ round: Int) -> CPUDifficulty {
        switch round {
        case 1...3: return .easy
        case 4...6: return .medium
        case 7...10: return .hard
        default: return .expert
        }
    }
}

// MARK: - Game Phase

enum BilliardDodgePhase: Equatable {
    case starting                       // Initial setup, about to start
    case countdown(remaining: Double)   // Aiming phase with countdown
    case executing                      // Physics running
    case roundResult(message: String)   // Brief pause showing what happened
    case gameOver(won: Bool)            // Game finished

    var isAimingPhase: Bool {
        switch self {
        case .countdown: return true
        default: return false
        }
    }

    var isActive: Bool {
        switch self {
        case .executing: return true
        default: return false
        }
    }
}

// MARK: - Player Status

enum PlayerStatus: String {
    case aiming = "AIMING..."
    case ready = "READY"
    case eliminated = "OUT"
    case waiting = "WAITING"
}

// MARK: - Main Game State

@Observable
final class BilliardDodgeState {
    var config: BilliardDodgeConfig
    var balls: [BilliardBall]           // Player balls
    var cueBall: BilliardBall
    var currentRound: Int
    var totalRounds: Int
    var phase: BilliardDodgePhase
    var cpuShot: CPUShot
    var playerMoves: [String: PlayerMove]   // playerId -> move
    var eliminatedPlayers: Set<String>
    var countdownValue: Double              // For display

    // Pockets for reference
    var pockets: [CGPoint] {
        config.pocketPositions()
    }

    init(config: BilliardDodgeConfig = .default, playerCount: Int = 1) {
        self.config = config
        self.balls = []
        self.cueBall = .cueBall(position: CGPoint(x: config.tableWidth * 0.25, y: config.tableHeight / 2))
        self.currentRound = 1
        self.totalRounds = config.roundsToWin(playerCount: playerCount)
        self.phase = .starting
        self.cpuShot = .empty
        self.playerMoves = [:]
        self.eliminatedPlayers = []
        self.countdownValue = config.countdownDuration
    }

    // MARK: - Setup

    func setupPlayers(count: Int) {
        let clampedCount = max(1, min(4, count))
        totalRounds = config.roundsToWin(playerCount: clampedCount)

        balls = []
        playerMoves = [:]
        eliminatedPlayers = []

        // Position player balls in a cluster on the right side
        let startPositions = generateStartPositions(count: clampedCount)

        for i in 0..<clampedCount {
            let playerId = "player_\(i)"
            let ball = BilliardBall.playerBall(
                id: "ball_\(i)",
                playerId: playerId,
                position: startPositions[i],
                playerIndex: i
            )
            balls.append(ball)
            playerMoves[playerId] = .empty
        }

        // Reset cue ball position
        cueBall = .cueBall(position: CGPoint(x: config.tableWidth * 0.25, y: config.tableHeight / 2))
    }

    private func generateStartPositions(count: Int) -> [CGPoint] {
        // Cluster players on the right side of the table
        let centerX = config.tableWidth * 0.7
        let centerY = config.tableHeight / 2
        let spacing = config.ballRadius * 3

        switch count {
        case 1:
            return [CGPoint(x: centerX, y: centerY)]
        case 2:
            return [
                CGPoint(x: centerX, y: centerY - spacing / 2),
                CGPoint(x: centerX, y: centerY + spacing / 2)
            ]
        case 3:
            return [
                CGPoint(x: centerX - spacing / 2, y: centerY - spacing / 2),
                CGPoint(x: centerX + spacing / 2, y: centerY - spacing / 2),
                CGPoint(x: centerX, y: centerY + spacing / 2)
            ]
        default: // 4
            return [
                CGPoint(x: centerX - spacing / 2, y: centerY - spacing / 2),
                CGPoint(x: centerX + spacing / 2, y: centerY - spacing / 2),
                CGPoint(x: centerX - spacing / 2, y: centerY + spacing / 2),
                CGPoint(x: centerX + spacing / 2, y: centerY + spacing / 2)
            ]
        }
    }

    // MARK: - Game Flow

    func startRound() {
        countdownValue = config.countdownDuration
        phase = .countdown(remaining: countdownValue)

        // Reset player moves for this round
        for playerId in playerMoves.keys {
            playerMoves[playerId] = .empty
        }

        // Reset ball velocities
        for i in balls.indices {
            balls[i].velocity = .zero
        }
        cueBall.velocity = .zero

        // If cue ball was pocketed (scratch), respawn it
        if cueBall.isPocketed {
            cueBall.position = CGPoint(x: config.tableWidth * 0.25, y: config.tableHeight / 2)
            cueBall.isPocketed = false
        }
    }

    func executeRound() {
        phase = .executing

        // Apply CPU shot to cue ball
        let velocity = CGVector(
            dx: cos(cpuShot.angle) * cpuShot.power * config.maxForce,
            dy: sin(cpuShot.angle) * cpuShot.power * config.maxForce
        )
        cueBall.velocity = velocity

        // Apply player moves to their balls
        for ball in balls where !ball.isEliminated {
            if let playerId = ball.playerId,
               let move = playerMoves[playerId],
               move.force > 0 {
                if let index = balls.firstIndex(where: { $0.id == ball.id }) {
                    let playerVelocity = CGVector(
                        dx: cos(move.angle) * move.force * config.maxForce * 0.7, // Players move slightly slower
                        dy: sin(move.angle) * move.force * config.maxForce * 0.7
                    )
                    balls[index].velocity = playerVelocity
                }
            }
        }
    }

    func showRoundResult(message: String) {
        phase = .roundResult(message: message)
    }

    func endGame(won: Bool) {
        phase = .gameOver(won: won)
    }

    // MARK: - Player Input

    func setPlayerMove(playerId: String, angle: CGFloat, force: CGFloat) {
        guard phase.isAimingPhase else { return }
        playerMoves[playerId] = PlayerMove(angle: angle, force: force, isLocked: false)
    }

    func lockPlayerMove(playerId: String) {
        guard phase.isAimingPhase else { return }
        if var move = playerMoves[playerId] {
            move.isLocked = true
            playerMoves[playerId] = move
        }
    }

    func unlockPlayerMove(playerId: String) {
        guard phase.isAimingPhase else { return }
        if var move = playerMoves[playerId] {
            move.isLocked = false
            playerMoves[playerId] = move
        }
    }

    // MARK: - State Queries

    func statusForPlayer(_ playerId: String) -> PlayerStatus {
        if eliminatedPlayers.contains(playerId) {
            return .eliminated
        }
        guard let move = playerMoves[playerId] else {
            return .waiting
        }
        if move.isLocked {
            return .ready
        }
        return .aiming
    }

    var activeBalls: [BilliardBall] {
        balls.filter { !$0.isEliminated }
    }

    var activePlayerCount: Int {
        balls.filter { !$0.isEliminated }.count
    }

    var allPlayersEliminated: Bool {
        balls.allSatisfy { $0.isEliminated }
    }

    var allBallsStopped: Bool {
        let threshold: CGFloat = 0.1
        let cueStopped = cueBall.velocity.magnitude < threshold || cueBall.isPocketed
        let playersStopped = balls.allSatisfy { $0.velocity.magnitude < threshold || $0.isPocketed || $0.isEliminated }
        return cueStopped && playersStopped
    }

    func playerBall(for playerId: String) -> BilliardBall? {
        balls.first { $0.playerId == playerId }
    }
}

// MARK: - CGVector Extension (if not already defined)

extension CGVector {
    var magnitude: CGFloat {
        sqrt(dx * dx + dy * dy)
    }

    var normalized: CGVector {
        let mag = magnitude
        guard mag > 0 else { return .zero }
        return CGVector(dx: dx / mag, dy: dy / mag)
    }

    func scaled(by factor: CGFloat) -> CGVector {
        CGVector(dx: dx * factor, dy: dy * factor)
    }
}
