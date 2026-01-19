/**
 * Foosball Physics - Ball Movement and Collision Detection
 *
 * Handles all physics calculations including ball movement, friction,
 * wall bounces, foosman collisions, kick impulses, and goal detection.
 */

import Foundation
import SwiftUI

// MARK: - Physics Engine

enum FoosballPhysics {

    // MARK: - Main Update

    /// Update the entire physics state for one frame
    static func step(state: FoosballState, deltaTime: CGFloat, currentTime: TimeInterval) {
        guard state.phase.isActive else { return }

        // Update kick states
        updateKickStates(state: state, deltaTime: deltaTime)

        // Update ball position
        updateBall(state: state, deltaTime: deltaTime)

        // Check collisions
        checkAllCollisions(state: state, currentTime: currentTime)

        // Apply friction
        applyFriction(state: state)

        // Check for goals
        if let result = checkGoal(ball: state.ball, config: state.config) {
            state.goalScored(by: result)
        }

        // Update timer for timed matches
        if var time = state.timeRemaining {
            time -= deltaTime / 60.0  // Convert frame delta to seconds
            state.timeRemaining = max(0, time)
            state.checkTimedGameOver()
        }
    }

    // MARK: - Kick State Updates

    private static func updateKickStates(state: FoosballState, deltaTime: CGFloat) {
        // Update player rods
        for i in 0..<state.playerRods.count {
            state.playerRods[i].kickState = updateKickState(
                state.playerRods[i].kickState,
                deltaTime: deltaTime,
                config: state.config
            )
        }

        // Update AI rods
        for i in 0..<state.aiRods.count {
            state.aiRods[i].kickState = updateKickState(
                state.aiRods[i].kickState,
                deltaTime: deltaTime,
                config: state.config
            )
        }
    }

    private static func updateKickState(_ kickState: KickState, deltaTime: CGFloat, config: FoosballConfig) -> KickState {
        switch kickState {
        case .idle:
            return .idle

        case .kicking(let type, let progress):
            let duration = CGFloat(type.duration)
            let frameTime = deltaTime / 60.0  // Convert to seconds
            let progressIncrement = frameTime / duration
            let newProgress = progress + progressIncrement

            if newProgress >= 1.0 {
                return .cooldown(remaining: config.kickCooldown)
            }
            return .kicking(type: type, progress: newProgress)

        case .cooldown(let remaining):
            let frameTime = deltaTime / 60.0
            let newRemaining = remaining - frameTime

            if newRemaining <= 0 {
                return .idle
            }
            return .cooldown(remaining: newRemaining)
        }
    }

    // MARK: - Ball Movement

    private static func updateBall(state: FoosballState, deltaTime: CGFloat) {
        state.ball.position.x += state.ball.velocity.dx * deltaTime
        state.ball.position.y += state.ball.velocity.dy * deltaTime
    }

    private static func applyFriction(state: FoosballState) {
        state.ball.velocity.dx *= state.config.ballFriction
        state.ball.velocity.dy *= state.config.ballFriction

        // Stop ball if very slow
        let speed = sqrt(state.ball.velocity.dx * state.ball.velocity.dx +
                        state.ball.velocity.dy * state.ball.velocity.dy)
        if speed < 0.1 {
            state.ball.velocity = .zero
        }
    }

    // MARK: - Collision Detection

    private static func checkAllCollisions(state: FoosballState, currentTime: TimeInterval) {
        // Check wall collisions first
        checkWallCollision(ball: &state.ball, config: state.config)

        // Check rod bar collisions
        for rod in state.allRods {
            checkRodBarCollision(ball: &state.ball, rod: rod, config: state.config)
        }

        // Check foosman collisions (both blocking and kicking)
        for rod in state.playerRods {
            checkFoosmanCollisions(ball: &state.ball, rod: rod, config: state.config, currentTime: currentTime)
        }
        for rod in state.aiRods {
            checkFoosmanCollisions(ball: &state.ball, rod: rod, config: state.config, currentTime: currentTime)
        }
    }

    // MARK: - Wall Collision

    static func checkWallCollision(ball: inout FoosballBall, config: FoosballConfig) {
        let halfWidth = config.tableWidth / 2
        let halfHeight = config.tableHeight / 2
        let radius = config.ballRadius

        // Left wall
        if ball.position.x - radius < -halfWidth {
            ball.position.x = -halfWidth + radius
            ball.velocity.dx = abs(ball.velocity.dx) * 0.9  // Slight energy loss
        }

        // Right wall
        if ball.position.x + radius > halfWidth {
            ball.position.x = halfWidth - radius
            ball.velocity.dx = -abs(ball.velocity.dx) * 0.9
        }

        // Top wall (except goal area)
        if ball.position.y - radius < -halfHeight {
            let goalHalfWidth = config.goalWidth / 2
            if abs(ball.position.x) > goalHalfWidth {
                // Hit wall, not goal
                ball.position.y = -halfHeight + radius
                ball.velocity.dy = abs(ball.velocity.dy) * 0.9
            }
        }

        // Bottom wall (except goal area)
        if ball.position.y + radius > halfHeight {
            let goalHalfWidth = config.goalWidth / 2
            if abs(ball.position.x) > goalHalfWidth {
                // Hit wall, not goal
                ball.position.y = halfHeight - radius
                ball.velocity.dy = -abs(ball.velocity.dy) * 0.9
            }
        }
    }

    // MARK: - Rod Bar Collision

    static func checkRodBarCollision(ball: inout FoosballBall, rod: FoosballRod, config: FoosballConfig) {
        let rodY = rod.yPosition
        let barHalfHeight = config.rodBarHeight / 2
        let radius = config.ballRadius
        let halfWidth = config.tableWidth / 2

        // Check if ball intersects with rod bar (horizontal line)
        if ball.position.y + radius > rodY - barHalfHeight &&
           ball.position.y - radius < rodY + barHalfHeight {
            // Ball is at rod Y level

            // Check if ball is hitting the bar (not a foosman)
            let foosmenPositions = rod.foosmenPositions(config: config)
            let manHalfWidth = config.manWidth / 2

            var hitsFoosman = false
            for pos in foosmenPositions {
                if abs(ball.position.x - pos.x) < manHalfWidth + radius {
                    hitsFoosman = true
                    break
                }
            }

            if !hitsFoosman && abs(ball.position.x) < halfWidth - 10 {
                // Ball hits the rod bar itself
                // Bounce based on direction of approach
                if ball.velocity.dy > 0 && ball.position.y < rodY {
                    // Coming from above
                    ball.position.y = rodY - barHalfHeight - radius
                    ball.velocity.dy = -abs(ball.velocity.dy) * 0.8
                } else if ball.velocity.dy < 0 && ball.position.y > rodY {
                    // Coming from below
                    ball.position.y = rodY + barHalfHeight + radius
                    ball.velocity.dy = abs(ball.velocity.dy) * 0.8
                }
            }
        }
    }

    // MARK: - Foosman Collision

    static func checkFoosmanCollisions(
        ball: inout FoosballBall,
        rod: FoosballRod,
        config: FoosballConfig,
        currentTime: TimeInterval
    ) {
        let positions = rod.foosmenPositions(config: config)
        let manHalfWidth = config.manWidth / 2
        let manHalfHeight = config.manHeight / 2
        let radius = config.ballRadius

        // Prevent double-hit on same rod
        if ball.lastHitBy == rod.id && currentTime - ball.lastHitTime < 0.1 {
            return
        }

        for pos in positions {
            // Get rotation from kick state
            let rotation = rod.kickState.currentRotation

            // Calculate effective hitbox based on rotation
            let effectiveWidth = abs(cos(rotation)) * manHalfWidth + abs(sin(rotation)) * manHalfHeight
            let effectiveHeight = abs(sin(rotation)) * manHalfWidth + abs(cos(rotation)) * manHalfHeight

            // Check if ball intersects foosman
            let dx = ball.position.x - pos.x
            let dy = ball.position.y - pos.y

            if abs(dx) < effectiveWidth + radius && abs(dy) < effectiveHeight + radius {
                // Collision detected!

                if case .kicking(let type, let progress) = rod.kickState {
                    // Kick collision - apply impulse
                    applyKickImpulse(
                        ball: &ball,
                        rod: rod,
                        kickType: type,
                        progress: progress,
                        contactOffset: dx,
                        config: config,
                        currentTime: currentTime
                    )
                } else {
                    // Static collision - bounce off
                    applyStaticBounce(
                        ball: &ball,
                        foosmanPos: pos,
                        config: config,
                        rod: rod,
                        currentTime: currentTime
                    )
                }
                return  // Only handle one collision per frame
            }
        }
    }

    private static func applyKickImpulse(
        ball: inout FoosballBall,
        rod: FoosballRod,
        kickType: KickType,
        progress: CGFloat,
        contactOffset: CGFloat,
        config: FoosballConfig,
        currentTime: TimeInterval
    ) {
        // Calculate kick power based on progress (peak power at middle of kick)
        let powerCurve = sin(progress * .pi)  // 0 at start/end, 1 at middle
        let basePower = config.kickPowerMin + (config.kickPowerMax - config.kickPowerMin) * powerCurve
        let finalPower = basePower * kickType.powerMultiplier

        // Determine kick direction based on which side the rod is on
        let kickDirection: CGFloat = rod.isPlayerSide ? -1.0 : 1.0  // Player kicks up (negative Y), AI kicks down

        // Add some angle based on where ball hit the foosman (edge = angled shot)
        let maxAngle: CGFloat = 0.4
        let angleOffset = (contactOffset / (config.manWidth / 2)) * maxAngle

        // Also add angle based on rod horizontal velocity (approximated by checking recent movement)
        // For simplicity, we'll use a small random factor for now
        let velocityAngle = CGFloat.random(in: -0.1...0.1)

        let finalAngle = angleOffset + velocityAngle

        // Apply impulse
        ball.velocity.dx = sin(finalAngle) * finalPower
        ball.velocity.dy = kickDirection * cos(finalAngle) * finalPower

        ball.lastHitBy = rod.id
        ball.lastHitTime = currentTime
    }

    private static func applyStaticBounce(
        ball: inout FoosballBall,
        foosmanPos: CGPoint,
        config: FoosballConfig,
        rod: FoosballRod,
        currentTime: TimeInterval
    ) {
        let dx = ball.position.x - foosmanPos.x
        let dy = ball.position.y - foosmanPos.y
        let dist = sqrt(dx * dx + dy * dy)

        if dist > 0 {
            // Normalize and push ball out
            let nx = dx / dist
            let ny = dy / dist

            // Push ball outside foosman
            let pushDist = config.ballRadius + config.manWidth / 2 + 1
            ball.position.x = foosmanPos.x + nx * pushDist
            ball.position.y = foosmanPos.y + ny * pushDist

            // Reflect velocity
            let dot = ball.velocity.dx * nx + ball.velocity.dy * ny
            ball.velocity.dx = (ball.velocity.dx - 2 * dot * nx) * 0.8
            ball.velocity.dy = (ball.velocity.dy - 2 * dot * ny) * 0.8
        }

        ball.lastHitBy = rod.id
        ball.lastHitTime = currentTime
    }

    // MARK: - Goal Detection

    static func checkGoal(ball: FoosballBall, config: FoosballConfig) -> FoosballGoalResult? {
        let halfHeight = config.tableHeight / 2
        let goalHalfWidth = config.goalWidth / 2
        let radius = config.ballRadius

        // Check if ball fully entered a goal
        // AI goal is at top (negative Y)
        if ball.position.y + radius < -halfHeight && abs(ball.position.x) < goalHalfWidth {
            return .playerScored
        }

        // Player goal is at bottom (positive Y)
        if ball.position.y - radius > halfHeight && abs(ball.position.x) < goalHalfWidth {
            return .aiScored
        }

        return nil
    }
}
