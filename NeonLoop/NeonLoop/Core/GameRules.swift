/**
 * Game Rules - Physics & Collision Logic
 *
 * Swift translation of physics.ts from @neonloop/core.
 * Pure functions for physics calculations - no side effects.
 */

import Foundation
import CoreGraphics

// MARK: - Math Utilities

func distance(_ p1: Position, _ p2: Position) -> CGFloat {
    let dx = p2.x - p1.x
    let dy = p2.y - p1.y
    return sqrt(dx * dx + dy * dy)
}

func clamp(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
    Swift.min(Swift.max(value, minValue), maxValue)
}

// MARK: - GameCircle Type

struct GameCircle {
    var x: CGFloat
    var y: CGFloat
    var radius: CGFloat

    var position: Position {
        Position(x: x, y: y)
    }

    init(position: Position, radius: CGFloat) {
        self.x = position.x
        self.y = position.y
        self.radius = radius
    }

    init(x: CGFloat, y: CGFloat, radius: CGFloat) {
        self.x = x
        self.y = y
        self.radius = radius
    }
}

// MARK: - Collision Detection

func checkCircleCollision(_ c1: GameCircle, _ c2: GameCircle) -> Bool {
    distance(c1.position, c2.position) < c1.radius + c2.radius
}

struct WallCollisionResult {
    var hitLeft: Bool
    var hitRight: Bool
    var hitTop: Bool
    var hitBottom: Bool

    var didHit: Bool {
        hitLeft || hitRight || hitTop || hitBottom
    }
}

func checkWallCollision(_ entity: GameCircle, config: GameConfig) -> WallCollisionResult {
    WallCollisionResult(
        hitLeft: entity.x - entity.radius <= 0,
        hitRight: entity.x + entity.radius >= config.tableWidth,
        hitTop: entity.y - entity.radius <= 0,
        hitBottom: entity.y + entity.radius >= config.tableHeight
    )
}

enum GoalResult {
    case player   // Player scored (puck in opponent's goal)
    case opponent // Opponent scored (puck in player's goal)
}

func checkGoal(_ puck: GameCircle, config: GameConfig) -> GoalResult? {
    let goalLeft = (config.tableWidth - config.goalWidth) / 2
    let goalRight = goalLeft + config.goalWidth

    guard puck.x > goalLeft && puck.x < goalRight else {
        return nil
    }

    // Top goal (opponent's goal - player scores)
    if puck.y - puck.radius <= 0 {
        return .player
    }

    // Bottom goal (player's goal - opponent scores)
    if puck.y + puck.radius >= config.tableHeight {
        return .opponent
    }

    return nil
}

// MARK: - Collision Resolution

func resolvePaddlePuckCollision(
    puck: GameCircle,
    puckVelocity: Velocity,
    paddle: GameCircle,
    hitCount: Int,
    config: GameConfig
) -> Velocity {
    let dx = puck.x - paddle.x
    let dy = puck.y - paddle.y
    let dist = sqrt(dx * dx + dy * dy)

    guard dist > 0 else {
        // Puck exactly on paddle center - push in default direction
        return Velocity(dx: 0, dy: config.puckSpeed)
    }

    // Normalize collision vector
    let nx = dx / dist
    let ny = dy / dist

    // Calculate base speed with hit count boost
    let relativeSpeed = puckVelocity.magnitude
    let speedMultiplier = 1 + CGFloat(hitCount) * config.speedIncreasePerHit
    let clampedMultiplier = min(speedMultiplier, config.maxSpeedMultiplier)
    let baseSpeed = max(relativeSpeed * 1.1, config.puckSpeed * 0.8)
    let speed = baseSpeed * clampedMultiplier

    return Velocity(dx: nx * speed, dy: ny * speed)
}

func separateCircles(movable: GameCircle, stationary: GameCircle) -> Position {
    let dx = movable.x - stationary.x
    let dy = movable.y - stationary.y
    let dist = sqrt(dx * dx + dy * dy)

    guard dist > 0 else {
        // Exactly overlapping - push in arbitrary direction
        return Position(x: movable.x + movable.radius, y: movable.y)
    }

    let overlap = movable.radius + stationary.radius - dist
    guard overlap > 0 else {
        return movable.position
    }

    let angle = atan2(dy, dx)
    return Position(
        x: movable.x + cos(angle) * overlap,
        y: movable.y + sin(angle) * overlap
    )
}

// MARK: - Paddle Constraints

func constrainPaddlePosition1v1(
    paddle: Position,
    radius: CGFloat,
    config: GameConfig,
    isPlayer: Bool,
    playAreaShift: CGFloat = 0
) -> Position {
    let minX = radius
    let maxX = config.tableWidth - radius
    let shiftedCenter = config.tableHeight / 2 + playAreaShift

    let minY: CGFloat
    let maxY: CGFloat

    if isPlayer {
        // Player's area is from shifted center to bottom
        minY = shiftedCenter + radius
        maxY = config.tableHeight - radius
    } else {
        // Opponent's area is from top to shifted center
        minY = radius
        maxY = shiftedCenter - radius
    }

    return Position(
        x: clamp(paddle.x, min: minX, max: maxX),
        y: clamp(paddle.y, min: minY, max: maxY)
    )
}

// MARK: - Puck Operations

func createPuck(config: GameConfig, towardsPlayer: Bool) -> PuckState {
    let centerX = config.tableWidth / 2
    let centerY = config.tableHeight / 2
    let angle = (CGFloat.random(in: 0..<1) * .pi / 2) - .pi / 4  // -45 to +45 degrees
    let direction: CGFloat = towardsPlayer ? 1 : -1

    return PuckState(
        position: Position(x: centerX, y: centerY),
        velocity: Velocity(
            dx: sin(angle) * config.puckSpeed * 0.5,
            dy: cos(angle) * config.puckSpeed * 0.5 * direction
        ),
        hitCount: 0,
        lastHitBy: nil,
        id: nil,
        stuckTime: 0,
        isFlashing: false
    )
}

func updatePuckPosition(puck: PuckState, config: GameConfig, deltaTime: CGFloat) -> PuckState {
    var newPuck = puck
    newPuck.position.x += puck.velocity.dx * deltaTime
    newPuck.position.y += puck.velocity.dy * deltaTime
    newPuck.velocity.dx *= config.friction
    newPuck.velocity.dy *= config.friction
    return newPuck
}

func limitPuckSpeed(puck: PuckState, config: GameConfig) -> PuckState {
    let speed = puck.velocity.magnitude
    let maxSpeed = config.puckSpeed * config.maxSpeedMultiplier

    guard speed > maxSpeed else { return puck }

    var newPuck = puck
    let ratio = maxSpeed / speed
    newPuck.velocity.dx *= ratio
    newPuck.velocity.dy *= ratio
    return newPuck
}

// MARK: - Constants

enum GameConstants {
    static let stuckThreshold: CGFloat = 2        // Speed below which puck is "stuck"
    static let stuckFlashTime: TimeInterval = 2   // Start flashing after 2 seconds
    static let stuckBoostTime: TimeInterval = 3   // Boost after 3 seconds
    static let playAreaShiftAmount: CGFloat = 30
    static let maxPlayAreaShift: CGFloat = 120
}
