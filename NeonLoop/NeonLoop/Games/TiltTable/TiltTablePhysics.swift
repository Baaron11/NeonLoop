/**
 * TiltTable Physics - Ball Movement and Tilt Calculation
 *
 * Handles the physics simulation for the Tilt Table game including:
 * - Table tilt calculation based on player positions
 * - Ball acceleration and movement based on tilt
 * - Friction and speed limiting
 * - Edge bouncing
 * - Hole capture detection
 */

import Foundation
import CoreGraphics

// MARK: - Physics Engine

enum TiltTablePhysics {

    // MARK: - Tilt Calculation

    /// Calculate table tilt based on player positions
    /// Players cluster on one side → table tilts that direction
    /// More players on one side → stronger tilt
    static func calculateTilt(
        players: [TiltTablePlayer],
        config: TiltTableConfig
    ) -> CGVector {
        guard !players.isEmpty else { return .zero }

        // Calculate weighted average position
        var totalX: CGFloat = 0
        var totalY: CGFloat = 0

        for player in players {
            let pos = player.position(config: config)
            totalX += pos.x
            totalY += pos.y
        }

        // Average position determines tilt direction
        let avgX = totalX / CGFloat(players.count)
        let avgY = totalY / CGFloat(players.count)

        // Normalize to get direction
        let magnitude = sqrt(avgX * avgX + avgY * avgY)
        guard magnitude > 0 else { return .zero }

        // Tilt intensity based on how far from center (clustered = stronger)
        // Also scales with number of players (more agreement = stronger effect)
        let clusterFactor = magnitude / config.ringRadius
        let intensityFactor = min(1.0, clusterFactor * 1.5)

        let tiltX = (avgX / magnitude) * intensityFactor * config.maxTilt
        let tiltY = (avgY / magnitude) * intensityFactor * config.maxTilt

        return CGVector(dx: tiltX, dy: tiltY)
    }

    // MARK: - Ball Update

    /// Update ball position and velocity based on tilt and physics
    static func updateBall(
        ball: inout TiltTableBall,
        tilt: CGVector,
        config: TiltTableConfig,
        deltaTime: CGFloat
    ) {
        // Apply tilt as acceleration (gravity pulling in tilt direction)
        let acceleration = CGVector(
            dx: tilt.dx * config.gravity * deltaTime,
            dy: tilt.dy * config.gravity * deltaTime
        )

        ball.velocity = ball.velocity + acceleration

        // Apply friction
        ball.velocity = ball.velocity.scaled(by: pow(config.friction, deltaTime))

        // Limit speed
        let speed = ball.velocity.magnitude
        if speed > config.maxBallSpeed {
            ball.velocity = ball.velocity.normalized.scaled(by: config.maxBallSpeed)
        }

        // Update position
        ball.position = ball.position + ball.velocity.scaled(by: deltaTime)

        // Bounce off edges
        let distanceFromCenter = sqrt(
            ball.position.x * ball.position.x +
            ball.position.y * ball.position.y
        )

        let maxDistance = config.tableRadius - config.ballRadius

        if distanceFromCenter > maxDistance {
            // Calculate bounce
            let normalX = ball.position.x / distanceFromCenter
            let normalY = ball.position.y / distanceFromCenter

            // Reflect velocity
            let dot = ball.velocity.dx * normalX + ball.velocity.dy * normalY
            ball.velocity = CGVector(
                dx: ball.velocity.dx - 2 * dot * normalX,
                dy: ball.velocity.dy - 2 * dot * normalY
            )

            // Apply bounce damping
            ball.velocity = ball.velocity.scaled(by: 0.8)

            // Push ball back inside
            ball.position = CGPoint(
                x: normalX * maxDistance,
                y: normalY * maxDistance
            )
        }
    }

    // MARK: - Player Movement

    /// Update player positions (smooth movement toward target)
    static func updatePlayers(
        players: inout [TiltTablePlayer],
        config: TiltTableConfig,
        deltaTime: CGFloat
    ) {
        for i in players.indices {
            let diff = normalizeAngle(players[i].targetAngle - players[i].angle)
            let maxMove = config.playerMoveSpeed * deltaTime * 0.1  // Convert to radians

            if abs(diff) > 0.01 {
                if abs(diff) < maxMove {
                    players[i].angle = players[i].targetAngle
                } else {
                    players[i].angle += (diff > 0 ? 1 : -1) * maxMove
                }
                players[i].angle = normalizeAngle(players[i].angle)
            }
        }
    }

    /// Normalize angle to -pi to pi range
    private static func normalizeAngle(_ angle: CGFloat) -> CGFloat {
        var normalized = angle
        while normalized > .pi { normalized -= 2 * .pi }
        while normalized < -.pi { normalized += 2 * .pi }
        return normalized
    }

    // MARK: - Hole Detection

    /// Check if ball has fallen into any hole
    static func checkHoleCapture(
        ball: TiltTableBall,
        holes: [TiltTableHole],
        config: TiltTableConfig
    ) -> TiltTableHole? {
        for hole in holes where !hole.isPlugged {
            let holePos = hole.position(config: config)
            let distance = ball.position.distance(to: holePos)

            if distance < config.holeRadius {
                return hole
            }
        }
        return nil
    }

    /// Check if ball is being pulled toward a hole (for visual feedback)
    static func getNearbyHole(
        ball: TiltTableBall,
        holes: [TiltTableHole],
        config: TiltTableConfig
    ) -> (hole: TiltTableHole, pullStrength: CGFloat)? {
        var closest: (hole: TiltTableHole, distance: CGFloat)?

        for hole in holes where !hole.isPlugged {
            let holePos = hole.position(config: config)
            let distance = ball.position.distance(to: holePos)

            if distance < config.holeCaptureRadius {
                if closest == nil || distance < closest!.distance {
                    closest = (hole, distance)
                }
            }
        }

        guard let found = closest else { return nil }

        // Calculate pull strength (1.0 = at hole, 0.0 = at edge of capture radius)
        let pullStrength = 1.0 - (found.distance / config.holeCaptureRadius)
        return (found.hole, pullStrength)
    }

    /// Apply gravitational pull from nearby holes
    static func applyHoleGravity(
        ball: inout TiltTableBall,
        holes: [TiltTableHole],
        config: TiltTableConfig,
        deltaTime: CGFloat
    ) {
        for hole in holes where !hole.isPlugged {
            let holePos = hole.position(config: config)
            let distance = ball.position.distance(to: holePos)

            if distance < config.holeCaptureRadius && distance > 0 {
                // Calculate pull toward hole
                let dirX = (holePos.x - ball.position.x) / distance
                let dirY = (holePos.y - ball.position.y) / distance

                // Stronger pull as ball gets closer
                let pullStrength = (1.0 - distance / config.holeCaptureRadius)
                let pullForce = pullStrength * pullStrength * 0.3 * deltaTime

                ball.velocity = CGVector(
                    dx: ball.velocity.dx + dirX * pullForce,
                    dy: ball.velocity.dy + dirY * pullForce
                )
            }
        }
    }

    // MARK: - Full Physics Step

    /// Complete physics update for one frame
    static func step(
        state: TiltTableState,
        deltaTime: CGFloat
    ) {
        guard state.phase.isActive else { return }

        // Update player positions
        var players = state.players
        updatePlayers(players: &players, config: state.config, deltaTime: deltaTime)
        state.players = players

        // Calculate tilt from player positions
        let tilt = calculateTilt(players: state.players, config: state.config)
        state.tableTilt = tilt

        // Update ball physics
        var ball = state.ball
        updateBall(ball: &ball, tilt: tilt, config: state.config, deltaTime: deltaTime)

        // Apply hole gravity
        applyHoleGravity(ball: &ball, holes: state.holes, config: state.config, deltaTime: deltaTime)

        state.ball = ball

        // Check for hole capture
        if let capturedHole = checkHoleCapture(
            ball: state.ball,
            holes: state.holes,
            config: state.config
        ) {
            state.ballFellInHole(capturedHole)
        }
    }
}
