/**
 * HordeDefense Physics - Puck Movement & Collisions
 *
 * Handles all physics simulation for the Horde Defense game:
 * - Puck movement (pucks move freely, not on rails)
 * - Rail collision (pucks bounce off rail segments)
 * - Paddle collision (pucks deflect off paddles)
 * - Goal detection (center goal and enemy goals)
 */

import Foundation
import SwiftUI

// MARK: - Physics Engine

enum HordeDefensePhysics {

    // MARK: - Configuration

    private static let substeps = 4
    private static let railThickness: CGFloat = 6.0
    private static let friction: CGFloat = 0.998
    private static let railBounce: CGFloat = 0.9
    private static let paddleBounce: CGFloat = 1.1 // Slight speed boost on paddle hit
    private static let maxSpeed: CGFloat = 12.0
    private static let minSpeed: CGFloat = 2.0

    // MARK: - Main Physics Step

    /// Updates all pucks and handles collisions for one frame
    static func step(state: HordeDefenseState, deltaTime: CGFloat) {
        guard state.phase.isActive else { return }

        let config = state.config
        let subDelta = deltaTime / CGFloat(substeps)

        for _ in 0..<substeps {
            // Move pucks
            updatePucks(state: state, config: config, deltaTime: subDelta)

            // Check collisions with rails
            for i in state.pucks.indices {
                if state.pucks[i].isActive {
                    checkRailCollision(puck: &state.pucks[i], config: config)
                }
            }

            // Check collisions with paddles
            for i in state.pucks.indices {
                if state.pucks[i].isActive {
                    for paddle in state.allPaddles {
                        checkPaddleCollision(puck: &state.pucks[i], paddle: paddle, config: config)
                    }
                }
            }

            // Check outer boundary
            for i in state.pucks.indices {
                if state.pucks[i].isActive {
                    checkOuterBoundary(puck: &state.pucks[i], config: config)
                }
            }
        }
    }

    // MARK: - Puck Movement

    private static func updatePucks(state: HordeDefenseState, config: HordeDefenseConfig, deltaTime: CGFloat) {
        for i in state.pucks.indices {
            guard state.pucks[i].isActive else { continue }

            // Apply velocity
            state.pucks[i].position.x += state.pucks[i].velocity.dx * deltaTime
            state.pucks[i].position.y += state.pucks[i].velocity.dy * deltaTime

            // Apply friction
            state.pucks[i].velocity = state.pucks[i].velocity.scaled(by: pow(friction, deltaTime))

            // Enforce minimum speed (pucks should keep moving)
            let speed = state.pucks[i].velocity.magnitude
            if speed > 0 && speed < minSpeed {
                let normalized = state.pucks[i].velocity.normalized
                state.pucks[i].velocity = CGVector(
                    dx: normalized.dx * minSpeed,
                    dy: normalized.dy * minSpeed
                )
            }

            // Enforce maximum speed
            if speed > maxSpeed {
                let normalized = state.pucks[i].velocity.normalized
                state.pucks[i].velocity = CGVector(
                    dx: normalized.dx * maxSpeed,
                    dy: normalized.dy * maxSpeed
                )
            }
        }
    }

    // MARK: - Rail Collision

    static func checkRailCollision(puck: inout HordePuck, config: HordeDefenseConfig) {
        let center = CGPoint(x: config.arenaRadius, y: config.arenaRadius)
        let railSystem = RailSystem(config: config)

        // Check collision with rings
        for radius in config.ringRadii {
            let distFromCenter = distance(from: center, to: puck.position)
            let distToRing = abs(distFromCenter - radius)

            // Check if puck overlaps with ring
            if distToRing < config.puckRadius + railThickness / 2 {
                // Calculate bounce
                let angle = atan2(puck.position.y - center.y, puck.position.x - center.x)

                // Normal direction (outward if inside ring, inward if outside)
                let normalDir: CGFloat = distFromCenter < radius ? 1 : -1
                let normal = CGVector(dx: cos(angle) * normalDir, dy: sin(angle) * normalDir)

                // Reflect velocity
                let dotProduct = puck.velocity.dx * normal.dx + puck.velocity.dy * normal.dy

                // Only bounce if moving toward the rail
                if dotProduct < 0 {
                    puck.velocity.dx -= 2 * dotProduct * normal.dx
                    puck.velocity.dy -= 2 * dotProduct * normal.dy

                    // Apply bounce coefficient
                    puck.velocity = puck.velocity.scaled(by: railBounce)

                    // Separate puck from rail
                    let separation = config.puckRadius + railThickness / 2 - distToRing + 1
                    puck.position.x += normal.dx * separation
                    puck.position.y += normal.dy * separation
                }
            }
        }

        // Check collision with spokes
        for spokeIndex in 0..<config.spokeCount {
            let angle = CGFloat(spokeIndex) * (2 * .pi / CGFloat(config.spokeCount))
            let innerRadius = config.centerGoalRadius + 10
            let outerRadius = config.ringRadii.last ?? config.arenaRadius

            let spokeStart = CGPoint(
                x: center.x + cos(angle) * innerRadius,
                y: center.y + sin(angle) * innerRadius
            )
            let spokeEnd = CGPoint(
                x: center.x + cos(angle) * outerRadius,
                y: center.y + sin(angle) * outerRadius
            )

            let closest = closestPointOnLineSegment(point: puck.position, lineStart: spokeStart, lineEnd: spokeEnd)

            if closest.distance < config.puckRadius + railThickness / 2 {
                // Calculate perpendicular normal
                let dx = puck.position.x - closest.point.x
                let dy = puck.position.y - closest.point.y
                let dist = sqrt(dx * dx + dy * dy)

                guard dist > 0 else { continue }

                let normal = CGVector(dx: dx / dist, dy: dy / dist)

                // Reflect velocity
                let dotProduct = puck.velocity.dx * normal.dx + puck.velocity.dy * normal.dy

                // Only bounce if moving toward the spoke
                if dotProduct < 0 {
                    puck.velocity.dx -= 2 * dotProduct * normal.dx
                    puck.velocity.dy -= 2 * dotProduct * normal.dy

                    // Apply bounce coefficient
                    puck.velocity = puck.velocity.scaled(by: railBounce)

                    // Separate puck from spoke
                    let separation = config.puckRadius + railThickness / 2 - closest.distance + 1
                    puck.position.x += normal.dx * separation
                    puck.position.y += normal.dy * separation
                }
            }
        }
    }

    // MARK: - Paddle Collision

    static func checkPaddleCollision(puck: inout HordePuck, paddle: HordePaddle, config: HordeDefenseConfig) {
        let paddlePos = paddle.position.toPoint(config: config)
        let puckPos = puck.position

        // Calculate distance to paddle center
        let dx = puckPos.x - paddlePos.x
        let dy = puckPos.y - paddlePos.y
        let dist = sqrt(dx * dx + dy * dy)

        // Paddle is a line segment along the rail
        // For simplicity, we treat it as a circle with radius = paddleLength / 2
        let paddleRadius = config.paddleLength / 2
        let collisionDist = config.puckRadius + paddleRadius

        if dist < collisionDist && dist > 0 {
            // Calculate normal (from paddle to puck)
            let normal = CGVector(dx: dx / dist, dy: dy / dist)

            // Check if puck is moving toward paddle
            let dotProduct = puck.velocity.dx * normal.dx + puck.velocity.dy * normal.dy

            if dotProduct < 0 {
                // Reflect velocity
                puck.velocity.dx -= 2 * dotProduct * normal.dx
                puck.velocity.dy -= 2 * dotProduct * normal.dy

                // Apply paddle bounce (slight speed boost)
                puck.velocity = puck.velocity.scaled(by: paddleBounce)

                // Add some deflection based on where puck hit paddle
                let deflectionAngle = atan2(dy, dx)
                let deflectionStrength: CGFloat = 0.5
                puck.velocity.dx += cos(deflectionAngle) * deflectionStrength
                puck.velocity.dy += sin(deflectionAngle) * deflectionStrength

                // Separate puck from paddle
                let separation = collisionDist - dist + 1
                puck.position.x += normal.dx * separation
                puck.position.y += normal.dy * separation

                // Record who hit the puck
                puck.lastHitBy = paddle.id
            }
        }
    }

    // MARK: - Outer Boundary

    private static func checkOuterBoundary(puck: inout HordePuck, config: HordeDefenseConfig) {
        let center = CGPoint(x: config.arenaRadius, y: config.arenaRadius)
        let distFromCenter = distance(from: center, to: puck.position)

        // Bounce off outer boundary
        if distFromCenter + config.puckRadius > config.arenaRadius {
            let angle = atan2(puck.position.y - center.y, puck.position.x - center.x)
            let normal = CGVector(dx: -cos(angle), dy: -sin(angle)) // Inward

            // Reflect velocity
            let dotProduct = puck.velocity.dx * normal.dx + puck.velocity.dy * normal.dy

            if dotProduct < 0 {
                puck.velocity.dx -= 2 * dotProduct * normal.dx
                puck.velocity.dy -= 2 * dotProduct * normal.dy
                puck.velocity = puck.velocity.scaled(by: railBounce)

                // Push back inside
                let newRadius = config.arenaRadius - config.puckRadius - 1
                puck.position.x = center.x + cos(angle) * newRadius
                puck.position.y = center.y + sin(angle) * newRadius
            }
        }
    }

    // MARK: - Goal Detection

    /// Check if puck entered center goal (AI scores)
    static func checkCenterGoal(puck: HordePuck, config: HordeDefenseConfig) -> Bool {
        let center = CGPoint(x: config.arenaRadius, y: config.arenaRadius)
        let dist = distance(from: center, to: puck.position)

        return dist < config.centerGoalRadius
    }

    /// Check if puck entered any enemy goal (Players score)
    static func checkEnemyGoals(puck: HordePuck, goals: [EnemyGoal], config: HordeDefenseConfig) -> EnemyGoal? {
        let center = CGPoint(x: config.arenaRadius, y: config.arenaRadius)
        let distFromCenter = distance(from: center, to: puck.position)

        // Only check if puck is near outer edge
        guard distFromCenter > config.arenaRadius - config.puckRadius * 2 else { return nil }

        // Get puck angle from center
        let puckAngle = atan2(puck.position.y - center.y, puck.position.x - center.x)
        let normalizedPuckAngle = normalizeAngle(puckAngle)

        // Check each enemy goal
        for goal in goals {
            if goal.containsAngle(normalizedPuckAngle) {
                return goal
            }
        }

        return nil
    }

    // MARK: - Puck Spawning

    /// Spawn puck at random position (not inside goals or on paddles)
    static func spawnPuck(config: HordeDefenseConfig, existingPucks: [HordePuck], paddles: [HordePaddle]) -> HordePuck {
        let center = CGPoint(x: config.arenaRadius, y: config.arenaRadius)
        var attempts = 0
        let maxAttempts = 50

        while attempts < maxAttempts {
            // Random position in middle area
            let minRadius = config.ringRadii[0] + config.puckRadius * 2
            let maxRadius = (config.ringRadii.count > 1 ? config.ringRadii[1] : config.ringRadii[0] * 1.5) - config.puckRadius * 2
            let radius = CGFloat.random(in: minRadius...max(minRadius + 10, maxRadius))
            let angle = CGFloat.random(in: 0...(2 * .pi))

            let position = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )

            // Check distance from existing pucks
            var tooClose = false
            for existingPuck in existingPucks where existingPuck.isActive {
                if distance(from: position, to: existingPuck.position) < config.puckRadius * 4 {
                    tooClose = true
                    break
                }
            }

            // Check distance from paddles
            if !tooClose {
                for paddle in paddles {
                    let paddlePos = paddle.position.toPoint(config: config)
                    if distance(from: position, to: paddlePos) < config.paddleLength * 2 {
                        tooClose = true
                        break
                    }
                }
            }

            if !tooClose {
                // Random initial velocity
                let velAngle = CGFloat.random(in: 0...(2 * .pi))
                let speed = config.puckSpeed
                let velocity = CGVector(
                    dx: cos(velAngle) * speed,
                    dy: sin(velAngle) * speed
                )

                return HordePuck.spawn(
                    id: "puck_\(Date().timeIntervalSince1970)",
                    position: position,
                    velocity: velocity
                )
            }

            attempts += 1
        }

        // Fallback: spawn at center area anyway
        let position = CGPoint(
            x: center.x + CGFloat.random(in: -20...20),
            y: center.y + CGFloat.random(in: -20...20)
        )
        let velocity = CGVector(
            dx: CGFloat.random(in: -config.puckSpeed...config.puckSpeed),
            dy: CGFloat.random(in: -config.puckSpeed...config.puckSpeed)
        )

        return HordePuck.spawn(
            id: "puck_\(Date().timeIntervalSince1970)",
            position: position,
            velocity: velocity
        )
    }

    // MARK: - Helper Functions

    private static func distance(from p1: CGPoint, to p2: CGPoint) -> CGFloat {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        return sqrt(dx * dx + dy * dy)
    }

    private static func closestPointOnLineSegment(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> (point: CGPoint, distance: CGFloat) {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        let lengthSquared = dx * dx + dy * dy

        if lengthSquared == 0 {
            let d = distance(from: point, to: lineStart)
            return (lineStart, d)
        }

        var t = ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / lengthSquared
        t = max(0, min(1, t))

        let closestPoint = CGPoint(
            x: lineStart.x + t * dx,
            y: lineStart.y + t * dy
        )

        let d = distance(from: point, to: closestPoint)
        return (closestPoint, d)
    }
}
