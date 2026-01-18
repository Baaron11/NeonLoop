/**
 * TiltTable State - Data Models for the Deciding Game
 *
 * Contains all state structures and configuration for the Tilt Table game.
 * Players position themselves around a ring to collectively tilt the table,
 * guiding a ball into holes to select the next game or modifier.
 */

import Foundation
import SwiftUI

// MARK: - Configuration

struct TiltTableConfig {
    let tableRadius: CGFloat        // Size of the playable table
    let ballRadius: CGFloat         // Size of the metal ball
    let playerAvatarRadius: CGFloat // Size of player markers
    let holeRadius: CGFloat         // Capture radius for holes
    let holeCaptureRadius: CGFloat  // Distance at which ball gets pulled in
    let gravity: CGFloat            // How fast ball accelerates
    let friction: CGFloat           // How fast ball slows (0-1, closer to 1 = less friction)
    let maxTilt: CGFloat            // Maximum table tilt angle
    let maxBallSpeed: CGFloat       // Speed cap for the ball
    let playerMoveSpeed: CGFloat    // How fast players move around the ring
    let ringRadius: CGFloat         // Distance from center where players sit

    static let `default` = TiltTableConfig(
        tableRadius: 180,
        ballRadius: 12,
        playerAvatarRadius: 20,
        holeRadius: 22,
        holeCaptureRadius: 35,
        gravity: 0.15,
        friction: 0.985,
        maxTilt: 0.4,
        maxBallSpeed: 8,
        playerMoveSpeed: 3.0,
        ringRadius: 160
    )
}

// MARK: - Hole Types

enum HoleType: String, Codable {
    case game           // Selects a game to play
    case goodModifier   // Positive effect
    case badModifier    // Negative effect

    var color: Color {
        switch self {
        case .game: return .cyan
        case .goodModifier: return .green
        case .badModifier: return .orange
        }
    }
}

// MARK: - Hole Definition

struct TiltTableHole: Identifiable, Equatable {
    let id: String
    let label: String              // "Air Hockey", "Speed Boost", etc.
    let angle: CGFloat             // Position on the ring (radians, 0 = right, pi/2 = top)
    var isPlugged: Bool            // Already used?
    let holeType: HoleType         // .game, .goodModifier, .badModifier

    // Computed position based on angle and config
    func position(config: TiltTableConfig) -> CGPoint {
        let x = cos(angle) * config.ringRadius
        let y = sin(angle) * config.ringRadius
        return CGPoint(x: x, y: y)
    }

    static func == (lhs: TiltTableHole, rhs: TiltTableHole) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Game Phase

enum TiltTablePhase: Equatable {
    case countdown(Int)         // Showing countdown (3, 2, 1)
    case playing                // Active gameplay
    case ballFalling(String)    // Ball entering hole (hole ID)
    case complete               // Game finished

    var isActive: Bool {
        switch self {
        case .playing: return true
        default: return false
        }
    }
}

// MARK: - Player Avatar

struct TiltTablePlayer: Identifiable, Equatable {
    let id: String
    let name: String
    let playerIndex: Int        // 0-3 for color assignment
    var angle: CGFloat          // Current position on the ring (radians)
    var targetAngle: CGFloat    // Target angle (for smooth movement)

    var color: Color {
        switch playerIndex % 4 {
        case 0: return .cyan
        case 1: return .pink
        case 2: return .green
        default: return .orange
        }
    }

    var displayNumber: Int { playerIndex + 1 }

    func position(config: TiltTableConfig) -> CGPoint {
        let x = cos(angle) * config.ringRadius
        let y = sin(angle) * config.ringRadius
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Ball State

struct TiltTableBall: Equatable {
    var position: CGPoint
    var velocity: CGVector

    static let initial = TiltTableBall(
        position: .zero,
        velocity: .zero
    )
}

// MARK: - Main Game State

@Observable
final class TiltTableState {
    var ball: TiltTableBall
    var players: [TiltTablePlayer]
    var holes: [TiltTableHole]
    var tableTilt: CGVector          // Current tilt direction + magnitude
    var phase: TiltTablePhase
    var result: TiltTableHole?       // Set when ball falls in
    var config: TiltTableConfig

    // For countdown animation
    var countdownValue: Int = 3

    init(config: TiltTableConfig = .default, holes: [TiltTableHole]? = nil) {
        self.config = config
        self.ball = .initial
        self.players = []
        self.holes = holes ?? TiltTableState.defaultHoles()
        self.tableTilt = .zero
        self.phase = .countdown(3)
        self.result = nil
    }

    // MARK: - Default Holes Setup

    static func defaultHoles() -> [TiltTableHole] {
        // Create 6 holes evenly distributed around the ring
        let holeData: [(String, String, HoleType)] = [
            ("polygon_hockey", "Polygon Hockey", .game),
            ("speed_boost", "Speed Boost", .goodModifier),
            ("horde_defense", "Horde Defense", .game),
            ("slow_mode", "Slow Mode", .badModifier),
            ("billiard_dodge", "Billiard Dodge", .game),
            ("extra_life", "Extra Life", .goodModifier)
        ]

        return holeData.enumerated().map { index, data in
            let angle = CGFloat(index) * (.pi * 2 / CGFloat(holeData.count)) - .pi / 2  // Start from top
            return TiltTableHole(
                id: data.0,
                label: data.1,
                angle: angle,
                isPlugged: false,
                holeType: data.2
            )
        }
    }

    // MARK: - Game Setup

    func setupPlayers(count: Int) {
        players = (0..<count).map { index in
            // Distribute players evenly around the ring
            let startAngle = CGFloat(index) * (.pi * 2 / CGFloat(count))
            return TiltTablePlayer(
                id: "player_\(index)",
                name: "Player \(index + 1)",
                playerIndex: index,
                angle: startAngle,
                targetAngle: startAngle
            )
        }
    }

    func addPlayer(id: String, name: String) {
        let index = players.count
        let startAngle = CGFloat(index) * (.pi * 2 / CGFloat(max(index + 1, 2)))
        players.append(TiltTablePlayer(
            id: id,
            name: name,
            playerIndex: index,
            angle: startAngle,
            targetAngle: startAngle
        ))
    }

    // MARK: - Game Control

    func startCountdown() {
        countdownValue = 3
        phase = .countdown(3)
        ball = .initial
        result = nil
    }

    func startPlaying() {
        phase = .playing
        // Give ball a small random nudge to start
        let nudgeAngle = CGFloat.random(in: 0..<(.pi * 2))
        let nudgeSpeed: CGFloat = 0.5
        ball.velocity = CGVector(
            dx: cos(nudgeAngle) * nudgeSpeed,
            dy: sin(nudgeAngle) * nudgeSpeed
        )
    }

    func ballFellInHole(_ hole: TiltTableHole) {
        phase = .ballFalling(hole.id)
        result = hole

        // Mark hole as plugged for future rounds
        if let index = holes.firstIndex(where: { $0.id == hole.id }) {
            holes[index].isPlugged = true
        }
    }

    func complete() {
        phase = .complete
    }

    // MARK: - Player Input

    func movePlayer(id: String, deltaAngle: CGFloat) {
        guard let index = players.firstIndex(where: { $0.id == id }) else { return }
        players[index].targetAngle += deltaAngle
    }

    func setPlayerAngle(id: String, angle: CGFloat) {
        guard let index = players.firstIndex(where: { $0.id == id }) else { return }
        players[index].targetAngle = angle
    }

    // MARK: - Computed Properties

    var activeHoles: [TiltTableHole] {
        holes.filter { !$0.isPlugged }
    }

    var playerCount: Int { players.count }

    var isGameOver: Bool {
        switch phase {
        case .complete: return true
        default: return false
        }
    }
}

// MARK: - CGVector Extensions

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

    static func + (lhs: CGVector, rhs: CGVector) -> CGVector {
        CGVector(dx: lhs.dx + rhs.dx, dy: lhs.dy + rhs.dy)
    }
}

extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        sqrt(pow(x - other.x, 2) + pow(y - other.y, 2))
    }

    static func + (lhs: CGPoint, rhs: CGVector) -> CGPoint {
        CGPoint(x: lhs.x + rhs.dx, y: lhs.y + rhs.dy)
    }
}
