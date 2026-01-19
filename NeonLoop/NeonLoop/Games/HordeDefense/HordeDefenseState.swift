/**
 * HordeDefense State - Data Models
 *
 * Contains all state structures and configuration for the Horde Defense game.
 * Players defend the center goal on a rail system while trying to score on
 * enemy goals at the outer edge.
 */

import Foundation
import SwiftUI

// MARK: - Configuration

struct HordeDefenseConfig {
    let arenaRadius: CGFloat          // Outer boundary (200)
    let centerGoalRadius: CGFloat     // Center goal size (25)
    let ringRadii: [CGFloat]          // Distance from center for each ring
    let spokeCount: Int               // Number of radial lines (6 or 8)
    let enemyGoalCount: Int           // Goals on outer edge (4-6)
    let enemyGoalArcWidth: CGFloat    // Width of each enemy goal in radians
    let paddleLength: CGFloat         // Paddle size (30)
    let paddleThickness: CGFloat      // Paddle thickness (8)
    let puckRadius: CGFloat           // Puck size (10)
    let puckSpeed: CGFloat            // Base puck speed
    let targetScore: Int              // First to this wins
    let defenderCount: Int            // Player paddles
    let attackerCount: Int            // AI paddles
    let puckCount: Int                // Pucks in play

    static let `default` = HordeDefenseConfig(
        arenaRadius: 200,
        centerGoalRadius: 25,
        ringRadii: [60, 120, 180],
        spokeCount: 8,
        enemyGoalCount: 6,
        enemyGoalArcWidth: .pi / 12, // 15 degrees
        paddleLength: 30,
        paddleThickness: 8,
        puckRadius: 10,
        puckSpeed: 4.0,
        targetScore: 5,
        defenderCount: 1,
        attackerCount: 2,
        puckCount: 1
    )

    /// Get the spoke angles (evenly distributed around the circle)
    var spokeAngles: [CGFloat] {
        (0..<spokeCount).map { CGFloat($0) * (2 * .pi / CGFloat(spokeCount)) }
    }

    /// Get the innermost ring radius
    var innerRingRadius: CGFloat {
        ringRadii.first ?? 60
    }

    /// Get the outermost ring radius
    var outerRingRadius: CGFloat {
        ringRadii.last ?? arenaRadius
    }
}

// MARK: - Rail Direction

enum RailDirection: Equatable {
    case clockwise
    case counterClockwise
    case inward              // Toward center (on spoke)
    case outward             // Away from center (on spoke)
}

// MARK: - Rail Position

/// Represents a point on the rail system
struct RailPosition: Equatable {
    var ringIndex: Int                // Which ring (0 = innermost)
    var angle: CGFloat                // Angle on the ring (0 to 2π)
    var isOnSpoke: Bool               // True if on radial line, false if on ring
    var spokeIndex: Int?              // Which spoke (if on a spoke)
    var spokeProgress: CGFloat?       // 0-1 progress along spoke (if on spoke)

    /// Convert to actual CGPoint for rendering
    func toPoint(config: HordeDefenseConfig) -> CGPoint {
        let center = CGPoint(x: config.arenaRadius, y: config.arenaRadius)

        if isOnSpoke, let spokeIdx = spokeIndex, let progress = spokeProgress {
            // On a spoke - interpolate between rings
            let spokeAngle = CGFloat(spokeIdx) * (2 * .pi / CGFloat(config.spokeCount))

            // Calculate radius based on progress between rings
            let innerRadius: CGFloat
            let outerRadius: CGFloat

            if ringIndex == 0 {
                innerRadius = config.centerGoalRadius + 10 // Start just outside center goal
                outerRadius = config.ringRadii[0]
            } else if ringIndex < config.ringRadii.count {
                innerRadius = config.ringRadii[ringIndex - 1]
                outerRadius = config.ringRadii[ringIndex]
            } else {
                innerRadius = config.ringRadii.last ?? config.arenaRadius
                outerRadius = config.arenaRadius
            }

            let radius = innerRadius + (outerRadius - innerRadius) * progress

            return CGPoint(
                x: center.x + cos(spokeAngle) * radius,
                y: center.y + sin(spokeAngle) * radius
            )
        } else {
            // On a ring
            let radius = ringIndex < config.ringRadii.count
                ? config.ringRadii[ringIndex]
                : config.arenaRadius

            return CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
        }
    }

    /// Get valid directions from this position
    func validDirections(config: HordeDefenseConfig) -> [RailDirection] {
        var directions: [RailDirection] = []

        if isOnSpoke {
            // On a spoke - can go inward/outward
            if ringIndex > 0 || (spokeProgress ?? 0) > 0 {
                directions.append(.inward)
            }
            if ringIndex < config.ringRadii.count - 1 || (spokeProgress ?? 1) < 1 {
                directions.append(.outward)
            }
        } else {
            // On a ring - can go clockwise/counterclockwise
            directions.append(.clockwise)
            directions.append(.counterClockwise)

            // Can switch to spoke at junctions
            let spokeAngles = config.spokeAngles
            for (idx, spokeAngle) in spokeAngles.enumerated() {
                if abs(normalizeAngle(angle - spokeAngle)) < 0.1 {
                    // At a junction - can go inward/outward
                    if ringIndex > 0 {
                        directions.append(.inward)
                    }
                    if ringIndex < config.ringRadii.count - 1 {
                        directions.append(.outward)
                    }
                    break
                }
            }
        }

        return directions
    }

    /// Check if at a junction (where spoke meets ring)
    func isAtJunction(config: HordeDefenseConfig) -> Bool {
        if isOnSpoke {
            // At junction if at start or end of spoke segment
            guard let progress = spokeProgress else { return false }
            return progress < 0.01 || progress > 0.99
        } else {
            // At junction if angle matches a spoke
            let spokeAngles = config.spokeAngles
            for spokeAngle in spokeAngles {
                if abs(normalizeAngle(angle - spokeAngle)) < 0.1 {
                    return true
                }
            }
            return false
        }
    }

    /// Create a position on a ring at a specific angle
    static func onRing(_ ringIndex: Int, angle: CGFloat) -> RailPosition {
        RailPosition(
            ringIndex: ringIndex,
            angle: normalizeAngle(angle),
            isOnSpoke: false,
            spokeIndex: nil,
            spokeProgress: nil
        )
    }

    /// Create a position on a spoke at a specific progress
    static func onSpoke(_ spokeIndex: Int, ringIndex: Int, progress: CGFloat, config: HordeDefenseConfig) -> RailPosition {
        RailPosition(
            ringIndex: ringIndex,
            angle: CGFloat(spokeIndex) * (2 * .pi / CGFloat(config.spokeCount)),
            isOnSpoke: true,
            spokeIndex: spokeIndex,
            spokeProgress: max(0, min(1, progress))
        )
    }
}

// MARK: - Horde Paddle

struct HordePaddle: Identifiable, Equatable {
    let id: String
    var position: RailPosition
    var color: Color
    var isPlayer: Bool                // true = human, false = AI
    var playerIndex: Int?             // For labeling (P1, P2, etc.)
    var targetGoalIndex: Int?         // For AI - which goal to defend

    var displayLabel: String {
        if isPlayer, let idx = playerIndex {
            return "P\(idx + 1)"
        }
        return "AI"
    }

    static func playerPaddle(id: String, position: RailPosition, playerIndex: Int) -> HordePaddle {
        let colors: [Color] = [.cyan, .green, .yellow]
        return HordePaddle(
            id: id,
            position: position,
            color: colors[playerIndex % colors.count],
            isPlayer: true,
            playerIndex: playerIndex,
            targetGoalIndex: nil
        )
    }

    static func aiPaddle(id: String, position: RailPosition, goalIndex: Int) -> HordePaddle {
        HordePaddle(
            id: id,
            position: position,
            color: .pink,
            isPlayer: false,
            playerIndex: nil,
            targetGoalIndex: goalIndex
        )
    }
}

// MARK: - Horde Puck

struct HordePuck: Identifiable, Equatable {
    let id: String
    var position: CGPoint             // Pucks move freely, not on rails
    var velocity: CGVector
    var isActive: Bool
    var lastHitBy: String?            // Paddle ID that last hit this puck

    static func spawn(id: String, position: CGPoint, velocity: CGVector) -> HordePuck {
        HordePuck(
            id: id,
            position: position,
            velocity: velocity,
            isActive: true,
            lastHitBy: nil
        )
    }
}

// MARK: - Enemy Goal

struct EnemyGoal: Identifiable, Equatable {
    let id: String
    let index: Int
    let centerAngle: CGFloat          // Center position on outer ring
    let arcWidth: CGFloat             // Width in radians
    var recentlyScored: Bool          // For flash animation

    /// Get the start angle of the goal
    var startAngle: CGFloat {
        normalizeAngle(centerAngle - arcWidth / 2)
    }

    /// Get the end angle of the goal
    var endAngle: CGFloat {
        normalizeAngle(centerAngle + arcWidth / 2)
    }

    /// Check if an angle is within this goal
    func containsAngle(_ angle: CGFloat) -> Bool {
        let normalizedAngle = normalizeAngle(angle)
        let start = normalizeAngle(centerAngle - arcWidth / 2)
        let end = normalizeAngle(centerAngle + arcWidth / 2)

        if start < end {
            return normalizedAngle >= start && normalizedAngle <= end
        } else {
            // Wraps around 0
            return normalizedAngle >= start || normalizedAngle <= end
        }
    }
}

// MARK: - Game Phase

enum HordePhase: Equatable {
    case settings                         // Pre-game settings
    case countdown(Int)                   // 3, 2, 1, GO!
    case playing                          // Active gameplay
    case goalScored(playerScored: Bool)   // Brief pause, show who scored
    case gameOver(playerWon: Bool)        // Game finished

    var isActive: Bool {
        switch self {
        case .playing: return true
        default: return false
        }
    }
}

// MARK: - Main Game State

@Observable
final class HordeDefenseState {
    var config: HordeDefenseConfig
    var playerPaddles: [HordePaddle]
    var aiPaddles: [HordePaddle]
    var pucks: [HordePuck]
    var enemyGoals: [EnemyGoal]
    var playerScore: Int
    var aiScore: Int
    var phase: HordePhase
    var countdownValue: Int
    var difficulty: Difficulty

    // Settings state
    var settingsDefenderCount: Int
    var settingsAttackerCount: Int
    var settingsPuckCount: Int
    var settingsTargetScore: Int
    var settingsDifficulty: Difficulty

    init(config: HordeDefenseConfig = .default) {
        self.config = config
        self.playerPaddles = []
        self.aiPaddles = []
        self.pucks = []
        self.enemyGoals = []
        self.playerScore = 0
        self.aiScore = 0
        self.phase = .settings
        self.countdownValue = 3
        self.difficulty = .medium

        // Initialize settings with defaults
        self.settingsDefenderCount = config.defenderCount
        self.settingsAttackerCount = config.attackerCount
        self.settingsPuckCount = config.puckCount
        self.settingsTargetScore = config.targetScore
        self.settingsDifficulty = .medium
    }

    // MARK: - Helper Properties

    var allPaddles: [HordePaddle] {
        playerPaddles + aiPaddles
    }

    var activePucks: [HordePuck] {
        pucks.filter { $0.isActive }
    }

    var arenaCenter: CGPoint {
        CGPoint(x: config.arenaRadius, y: config.arenaRadius)
    }

    // MARK: - Setup

    func applySettings() {
        // Create new config with settings
        config = HordeDefenseConfig(
            arenaRadius: config.arenaRadius,
            centerGoalRadius: config.centerGoalRadius,
            ringRadii: config.ringRadii,
            spokeCount: config.spokeCount,
            enemyGoalCount: config.enemyGoalCount,
            enemyGoalArcWidth: config.enemyGoalArcWidth,
            paddleLength: config.paddleLength,
            paddleThickness: config.paddleThickness,
            puckRadius: config.puckRadius,
            puckSpeed: config.puckSpeed,
            targetScore: settingsTargetScore,
            defenderCount: settingsDefenderCount,
            attackerCount: settingsAttackerCount,
            puckCount: settingsPuckCount
        )
        difficulty = settingsDifficulty
    }

    func setupGame() {
        applySettings()
        playerScore = 0
        aiScore = 0

        setupEnemyGoals()
        setupPlayerPaddles()
        setupAIPaddles()
        setupPucks()
    }

    private func setupEnemyGoals() {
        enemyGoals = []
        let goalCount = config.enemyGoalCount
        let angleStep = (2 * .pi) / CGFloat(goalCount)

        for i in 0..<goalCount {
            let centerAngle = CGFloat(i) * angleStep + angleStep / 2
            let goal = EnemyGoal(
                id: "enemy_goal_\(i)",
                index: i,
                centerAngle: centerAngle,
                arcWidth: config.enemyGoalArcWidth,
                recentlyScored: false
            )
            enemyGoals.append(goal)
        }
    }

    private func setupPlayerPaddles() {
        playerPaddles = []
        let count = config.defenderCount
        let middleRingIndex = config.ringRadii.count / 2
        let angleStep = (2 * .pi) / CGFloat(max(count, 1))

        for i in 0..<count {
            let angle = CGFloat(i) * angleStep
            let position = RailPosition.onRing(middleRingIndex, angle: angle)
            let paddle = HordePaddle.playerPaddle(
                id: "player_\(i)",
                position: position,
                playerIndex: i
            )
            playerPaddles.append(paddle)
        }
    }

    private func setupAIPaddles() {
        aiPaddles = []
        let count = config.attackerCount
        let outerRingIndex = config.ringRadii.count - 1

        // Distribute AI paddles among enemy goals
        for i in 0..<count {
            let goalIndex = i % enemyGoals.count
            let goal = enemyGoals[goalIndex]
            let position = RailPosition.onRing(outerRingIndex, angle: goal.centerAngle)
            let paddle = HordePaddle.aiPaddle(
                id: "ai_\(i)",
                position: position,
                goalIndex: goalIndex
            )
            aiPaddles.append(paddle)
        }
    }

    private func setupPucks() {
        pucks = []
        for i in 0..<config.puckCount {
            let puck = spawnNewPuck(index: i)
            pucks.append(puck)
        }
    }

    func spawnNewPuck(index: Int) -> HordePuck {
        // Spawn at random position in middle area
        let minRadius = config.ringRadii[0] + config.puckRadius * 2
        let maxRadius = config.ringRadii[1] - config.puckRadius * 2
        let radius = CGFloat.random(in: minRadius...maxRadius)
        let angle = CGFloat.random(in: 0...(2 * .pi))

        let center = arenaCenter
        let position = CGPoint(
            x: center.x + cos(angle) * radius,
            y: center.y + sin(angle) * radius
        )

        // Random initial velocity
        let velAngle = CGFloat.random(in: 0...(2 * .pi))
        let speed = config.puckSpeed * 0.5
        let velocity = CGVector(
            dx: cos(velAngle) * speed,
            dy: sin(velAngle) * speed
        )

        return HordePuck.spawn(
            id: "puck_\(index)",
            position: position,
            velocity: velocity
        )
    }

    // MARK: - Game Flow

    func startCountdown() {
        countdownValue = 3
        phase = .countdown(countdownValue)
    }

    func decrementCountdown() {
        countdownValue -= 1
        if countdownValue > 0 {
            phase = .countdown(countdownValue)
        } else {
            phase = .playing
        }
    }

    func handleGoalScored(playerScored: Bool, goalIndex: Int?) {
        if playerScored {
            playerScore += 1
            if let idx = goalIndex, idx < enemyGoals.count {
                enemyGoals[idx].recentlyScored = true
            }
        } else {
            aiScore += 1
        }

        phase = .goalScored(playerScored: playerScored)
    }

    func resumeAfterGoal() {
        // Check for game over
        if playerScore >= config.targetScore {
            phase = .gameOver(playerWon: true)
            return
        }
        if aiScore >= config.targetScore {
            phase = .gameOver(playerWon: false)
            return
        }

        // Reset goal scored flags
        for i in enemyGoals.indices {
            enemyGoals[i].recentlyScored = false
        }

        // Respawn any inactive pucks
        for i in pucks.indices {
            if !pucks[i].isActive {
                pucks[i] = spawnNewPuck(index: i)
            }
        }

        phase = .playing
    }

    // MARK: - Paddle Movement

    func movePaddle(paddleId: String, direction: RailDirection, distance: CGFloat) {
        // Find paddle in player paddles
        if let index = playerPaddles.firstIndex(where: { $0.id == paddleId }) {
            playerPaddles[index].position = moveAlongRail(
                from: playerPaddles[index].position,
                direction: direction,
                distance: distance
            )
        }

        // Find paddle in AI paddles
        if let index = aiPaddles.firstIndex(where: { $0.id == paddleId }) {
            aiPaddles[index].position = moveAlongRail(
                from: aiPaddles[index].position,
                direction: direction,
                distance: distance
            )
        }
    }

    private func moveAlongRail(from position: RailPosition, direction: RailDirection, distance: CGFloat) -> RailPosition {
        var newPosition = position

        if position.isOnSpoke {
            // Moving along a spoke
            guard let spokeIdx = position.spokeIndex,
                  var progress = position.spokeProgress else {
                return position
            }

            let ringRadius0 = position.ringIndex == 0
                ? config.centerGoalRadius + 10
                : config.ringRadii[max(0, position.ringIndex - 1)]
            let ringRadius1 = position.ringIndex < config.ringRadii.count
                ? config.ringRadii[position.ringIndex]
                : config.arenaRadius
            let spokeLength = ringRadius1 - ringRadius0
            let progressDelta = distance / spokeLength

            switch direction {
            case .inward:
                progress -= progressDelta
                if progress <= 0 {
                    // Transition to inner ring
                    let newRingIndex = max(0, position.ringIndex - 1)
                    let spokeAngle = CGFloat(spokeIdx) * (2 * .pi / CGFloat(config.spokeCount))
                    newPosition = RailPosition.onRing(newRingIndex, angle: spokeAngle)
                } else {
                    newPosition.spokeProgress = progress
                }

            case .outward:
                progress += progressDelta
                if progress >= 1 {
                    // Transition to outer ring
                    let newRingIndex = min(config.ringRadii.count - 1, position.ringIndex)
                    let spokeAngle = CGFloat(spokeIdx) * (2 * .pi / CGFloat(config.spokeCount))
                    newPosition = RailPosition.onRing(newRingIndex, angle: spokeAngle)
                } else {
                    newPosition.spokeProgress = progress
                }

            default:
                break
            }
        } else {
            // Moving along a ring
            let ringRadius = position.ringIndex < config.ringRadii.count
                ? config.ringRadii[position.ringIndex]
                : config.arenaRadius
            let circumference = 2 * .pi * ringRadius
            let angleDelta = (distance / circumference) * 2 * .pi

            switch direction {
            case .clockwise:
                newPosition.angle = normalizeAngle(position.angle + angleDelta)

            case .counterClockwise:
                newPosition.angle = normalizeAngle(position.angle - angleDelta)

            case .inward:
                // Switch to spoke going inward
                let nearestSpokeIndex = findNearestSpokeIndex(to: position.angle, config: config)
                let spokeAngle = CGFloat(nearestSpokeIndex) * (2 * .pi / CGFloat(config.spokeCount))
                if abs(normalizeAngle(position.angle - spokeAngle)) < 0.15 && position.ringIndex > 0 {
                    newPosition = RailPosition.onSpoke(
                        nearestSpokeIndex,
                        ringIndex: position.ringIndex,
                        progress: 1.0,
                        config: config
                    )
                }

            case .outward:
                // Switch to spoke going outward
                let nearestSpokeIndex = findNearestSpokeIndex(to: position.angle, config: config)
                let spokeAngle = CGFloat(nearestSpokeIndex) * (2 * .pi / CGFloat(config.spokeCount))
                if abs(normalizeAngle(position.angle - spokeAngle)) < 0.15 && position.ringIndex < config.ringRadii.count - 1 {
                    newPosition = RailPosition.onSpoke(
                        nearestSpokeIndex,
                        ringIndex: position.ringIndex + 1,
                        progress: 0.0,
                        config: config
                    )
                }
            }
        }

        return newPosition
    }

    func getPlayerPaddle(for playerId: String) -> HordePaddle? {
        playerPaddles.first { $0.id == playerId }
    }
}

// MARK: - Helper Functions

/// Normalize angle to 0...2π range
func normalizeAngle(_ angle: CGFloat) -> CGFloat {
    var normalized = angle.truncatingRemainder(dividingBy: 2 * .pi)
    if normalized < 0 {
        normalized += 2 * .pi
    }
    return normalized
}

/// Find the nearest spoke index for a given angle
func findNearestSpokeIndex(to angle: CGFloat, config: HordeDefenseConfig) -> Int {
    let normalizedAngle = normalizeAngle(angle)
    let spokeAngleStep = 2 * .pi / CGFloat(config.spokeCount)

    var nearestIndex = 0
    var nearestDistance = CGFloat.infinity

    for i in 0..<config.spokeCount {
        let spokeAngle = CGFloat(i) * spokeAngleStep
        let distance = abs(normalizeAngle(normalizedAngle - spokeAngle))
        let wrappedDistance = min(distance, 2 * .pi - distance)

        if wrappedDistance < nearestDistance {
            nearestDistance = wrappedDistance
            nearestIndex = i
        }
    }

    return nearestIndex
}
