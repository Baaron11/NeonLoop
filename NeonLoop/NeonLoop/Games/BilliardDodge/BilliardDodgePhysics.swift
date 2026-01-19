/**
 * BilliardDodge Physics - Ball Movement & Collisions
 *
 * Handles all physics simulation for the billiard dodge game:
 * - Ball movement with friction
 * - Rail/wall bounces
 * - Ball-to-ball collisions with momentum transfer
 * - Pocket detection
 */

import Foundation
import SwiftUI

// MARK: - Physics Engine

enum BilliardDodgePhysics {

    // MARK: - Main Physics Step

    /// Updates all ball positions and handles collisions for one frame
    static func step(state: BilliardDodgeState, deltaTime: CGFloat) {
        let config = state.config

        // Update cue ball
        updateBall(&state.cueBall, config: config, deltaTime: deltaTime)

        // Update player balls
        for i in state.balls.indices {
            if !state.balls[i].isEliminated && !state.balls[i].isPocketed {
                updateBall(&state.balls[i], config: config, deltaTime: deltaTime)
            }
        }

        // Handle ball-to-ball collisions
        handleCollisions(state: state, config: config)

        // Check pocket collisions
        checkPockets(state: state, config: config)
    }

    // MARK: - Ball Update

    private static func updateBall(_ ball: inout BilliardBall, config: BilliardDodgeConfig, deltaTime: CGFloat) {
        guard !ball.isPocketed else { return }

        // Apply velocity
        ball.position.x += ball.velocity.dx * deltaTime
        ball.position.y += ball.velocity.dy * deltaTime

        // Apply friction
        ball.velocity = ball.velocity.scaled(by: pow(config.friction, deltaTime))

        // Stop very slow balls
        if ball.velocity.magnitude < 0.05 {
            ball.velocity = .zero
        }

        // Handle rail bounces
        handleRailBounce(&ball, config: config)
    }

    // MARK: - Rail Bounces

    private static func handleRailBounce(_ ball: inout BilliardBall, config: BilliardDodgeConfig) {
        let radius = config.ballRadius
        let bounce = config.railBounce

        // Left rail
        if ball.position.x - radius < 0 {
            ball.position.x = radius
            ball.velocity.dx = abs(ball.velocity.dx) * bounce
        }

        // Right rail
        if ball.position.x + radius > config.tableWidth {
            ball.position.x = config.tableWidth - radius
            ball.velocity.dx = -abs(ball.velocity.dx) * bounce
        }

        // Top rail
        if ball.position.y - radius < 0 {
            ball.position.y = radius
            ball.velocity.dy = abs(ball.velocity.dy) * bounce
        }

        // Bottom rail
        if ball.position.y + radius > config.tableHeight {
            ball.position.y = config.tableHeight - radius
            ball.velocity.dy = -abs(ball.velocity.dy) * bounce
        }
    }

    // MARK: - Ball-to-Ball Collisions

    private static func handleCollisions(state: BilliardDodgeState, config: BilliardDodgeConfig) {
        var allBalls: [BilliardBall] = []

        // Collect all active balls including cue ball
        if !state.cueBall.isPocketed {
            allBalls.append(state.cueBall)
        }
        for ball in state.balls where !ball.isPocketed && !ball.isEliminated {
            allBalls.append(ball)
        }

        // Check all pairs for collisions
        for i in 0..<allBalls.count {
            for j in (i + 1)..<allBalls.count {
                if checkAndResolveCollision(&allBalls[i], &allBalls[j], config: config) {
                    // Collision occurred, update the state
                }
            }
        }

        // Write back to state
        for ball in allBalls {
            if ball.id == state.cueBall.id {
                state.cueBall = ball
            } else if let index = state.balls.firstIndex(where: { $0.id == ball.id }) {
                state.balls[index] = ball
            }
        }
    }

    private static func checkAndResolveCollision(_ ball1: inout BilliardBall, _ ball2: inout BilliardBall, config: BilliardDodgeConfig) -> Bool {
        let dx = ball2.position.x - ball1.position.x
        let dy = ball2.position.y - ball1.position.y
        let distance = sqrt(dx * dx + dy * dy)
        let minDistance = config.ballRadius * 2

        guard distance < minDistance && distance > 0 else { return false }

        // Normalize collision vector
        let nx = dx / distance
        let ny = dy / distance

        // Relative velocity
        let dvx = ball1.velocity.dx - ball2.velocity.dx
        let dvy = ball1.velocity.dy - ball2.velocity.dy

        // Relative velocity along collision normal
        let dvn = dvx * nx + dvy * ny

        // Don't resolve if velocities are separating
        if dvn > 0 { return false }

        // Coefficient of restitution
        let restitution = config.ballBounce

        // Impulse scalar (assuming equal masses)
        let impulse = -(1 + restitution) * dvn / 2

        // Apply impulse
        ball1.velocity.dx += impulse * nx
        ball1.velocity.dy += impulse * ny
        ball2.velocity.dx -= impulse * nx
        ball2.velocity.dy -= impulse * ny

        // Separate balls to prevent overlap
        let overlap = minDistance - distance
        let separationX = (overlap / 2 + 0.5) * nx
        let separationY = (overlap / 2 + 0.5) * ny
        ball1.position.x -= separationX
        ball1.position.y -= separationY
        ball2.position.x += separationX
        ball2.position.y += separationY

        return true
    }

    // MARK: - Pocket Detection

    private static func checkPockets(state: BilliardDodgeState, config: BilliardDodgeConfig) {
        let pockets = config.pocketPositions()

        // Check cue ball
        if !state.cueBall.isPocketed {
            for pocket in pockets {
                if isInPocket(ball: state.cueBall, pocket: pocket, config: config) {
                    state.cueBall.isPocketed = true
                    state.cueBall.velocity = .zero
                    break
                }
            }
        }

        // Check player balls
        for i in state.balls.indices {
            guard !state.balls[i].isPocketed && !state.balls[i].isEliminated else { continue }

            for pocket in pockets {
                if isInPocket(ball: state.balls[i], pocket: pocket, config: config) {
                    state.balls[i].isPocketed = true
                    state.balls[i].isEliminated = true
                    state.balls[i].velocity = .zero

                    // Track eliminated player
                    if let playerId = state.balls[i].playerId {
                        state.eliminatedPlayers.insert(playerId)
                    }
                    break
                }
            }
        }
    }

    private static func isInPocket(ball: BilliardBall, pocket: CGPoint, config: BilliardDodgeConfig) -> Bool {
        let dx = ball.position.x - pocket.x
        let dy = ball.position.y - pocket.y
        let distance = sqrt(dx * dx + dy * dy)

        // Ball center needs to be within pocket radius to be pocketed
        return distance < config.pocketRadius
    }

    // MARK: - Trajectory Prediction

    /// Predicts where a ball will go given an initial position, angle, and power
    /// Returns array of points for drawing trajectory preview
    static func predictTrajectory(
        from position: CGPoint,
        angle: CGFloat,
        power: CGFloat,
        config: BilliardDodgeConfig,
        maxPoints: Int = 50,
        maxBounces: Int = 3
    ) -> [CGPoint] {
        var points: [CGPoint] = [position]
        var currentPos = position
        var velocity = CGVector(
            dx: cos(angle) * power * config.maxForce,
            dy: sin(angle) * power * config.maxForce
        )

        var bounces = 0
        let radius = config.ballRadius
        let stepSize: CGFloat = 5.0

        for _ in 0..<maxPoints {
            // Check if velocity is too slow
            if velocity.magnitude < 0.5 {
                break
            }

            // Normalize and step
            let normalized = velocity.normalized
            let nextPos = CGPoint(
                x: currentPos.x + normalized.dx * stepSize,
                y: currentPos.y + normalized.dy * stepSize
            )

            // Check for rail bounces
            var bounced = false

            if nextPos.x - radius < 0 || nextPos.x + radius > config.tableWidth {
                velocity.dx = -velocity.dx * config.railBounce
                bounced = true
                bounces += 1
            }

            if nextPos.y - radius < 0 || nextPos.y + radius > config.tableHeight {
                velocity.dy = -velocity.dy * config.railBounce
                bounced = true
                bounces += 1
            }

            if bounces > maxBounces {
                break
            }

            // Apply friction
            velocity = velocity.scaled(by: 0.995)

            // Clamp position within table
            currentPos = CGPoint(
                x: max(radius, min(config.tableWidth - radius, nextPos.x)),
                y: max(radius, min(config.tableHeight - radius, nextPos.y))
            )

            points.append(currentPos)

            // Check if we hit a pocket
            for pocket in config.pocketPositions() {
                let dx = currentPos.x - pocket.x
                let dy = currentPos.y - pocket.y
                if sqrt(dx * dx + dy * dy) < config.pocketRadius {
                    return points
                }
            }
        }

        return points
    }

    /// Calculates angle from cue ball to target ball
    static func angleToTarget(from: CGPoint, to: CGPoint) -> CGFloat {
        atan2(to.y - from.y, to.x - from.x)
    }

    /// Finds the closest pocket to a given position
    static func closestPocket(to position: CGPoint, config: BilliardDodgeConfig) -> CGPoint {
        let pockets = config.pocketPositions()
        return pockets.min { p1, p2 in
            distance(from: position, to: p1) < distance(from: position, to: p2)
        } ?? pockets[0]
    }

    /// Calculates distance between two points
    static func distance(from p1: CGPoint, to p2: CGPoint) -> CGFloat {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        return sqrt(dx * dx + dy * dy)
    }
}
