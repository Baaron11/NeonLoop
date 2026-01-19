/**
 * HordeDefense AI - AI Paddle Behavior
 *
 * Handles AI paddle movement and decision making:
 * - Each AI paddle defends 1-2 enemy goals
 * - AI moves along outer ring to intercept pucks
 * - Difficulty affects reaction time, speed, and prediction
 */

import Foundation
import SwiftUI

// MARK: - AI Constants

private struct AIConstants {
    // Reaction time in seconds (higher = slower reaction)
    static func reactionTime(for difficulty: Difficulty) -> Double {
        switch difficulty {
        case .easy: return 0.3
        case .medium: return 0.15
        case .hard: return 0.05
        }
    }

    // Movement speed multiplier
    static func speedMultiplier(for difficulty: Difficulty) -> CGFloat {
        switch difficulty {
        case .easy: return 0.7
        case .medium: return 0.85
        case .hard: return 1.0
        }
    }

    // Prediction accuracy (0-1)
    static func predictionAccuracy(for difficulty: Difficulty) -> CGFloat {
        switch difficulty {
        case .easy: return 0.3
        case .medium: return 0.6
        case .hard: return 0.9
        }
    }

    // Base AI movement speed
    static let baseSpeed: CGFloat = 3.0

    // Distance threshold to consider "at position"
    static let positionThreshold: CGFloat = 5.0
}

// MARK: - AI Engine

enum HordeDefenseAI {

    // MARK: - Main Update

    /// Update all AI paddles
    static func updateAIPaddles(
        state: HordeDefenseState,
        deltaTime: CGFloat
    ) {
        guard state.phase.isActive else { return }

        for i in state.aiPaddles.indices {
            updateAIPaddle(
                paddle: &state.aiPaddles[i],
                pucks: state.pucks,
                enemyGoals: state.enemyGoals,
                config: state.config,
                difficulty: state.difficulty,
                deltaTime: deltaTime
            )
        }
    }

    /// Update a single AI paddle
    static func updateAIPaddle(
        paddle: inout HordePaddle,
        pucks: [HordePuck],
        enemyGoals: [EnemyGoal],
        config: HordeDefenseConfig,
        difficulty: Difficulty,
        deltaTime: CGFloat
    ) {
        // Find the goals this AI defends
        let defendedGoals = goalsDefendedBy(paddle: paddle, allGoals: enemyGoals)

        // Find the most threatening puck
        guard let threatInfo = findMostThreateningPuck(
            to: defendedGoals,
            pucks: pucks,
            paddle: paddle,
            config: config,
            difficulty: difficulty
        ) else {
            // No threat - patrol between defended goals
            patrolBetweenGoals(
                paddle: &paddle,
                goals: defendedGoals,
                config: config,
                deltaTime: deltaTime,
                difficulty: difficulty
            )
            return
        }

        // Move to intercept the threatening puck
        moveToIntercept(
            paddle: &paddle,
            targetAngle: threatInfo.interceptAngle,
            config: config,
            deltaTime: deltaTime,
            difficulty: difficulty
        )
    }

    // MARK: - Goal Assignment

    private static func goalsDefendedBy(paddle: HordePaddle, allGoals: [EnemyGoal]) -> [EnemyGoal] {
        guard let targetIndex = paddle.targetGoalIndex else {
            return allGoals
        }

        // Return the primary goal and adjacent ones
        var defended: [EnemyGoal] = []

        if targetIndex < allGoals.count {
            defended.append(allGoals[targetIndex])
        }

        // Add adjacent goal for coverage
        let nextIndex = (targetIndex + 1) % allGoals.count
        if nextIndex < allGoals.count {
            defended.append(allGoals[nextIndex])
        }

        return defended
    }

    // MARK: - Threat Detection

    private struct ThreatInfo {
        let puck: HordePuck
        let threatLevel: CGFloat  // Higher = more urgent
        let interceptAngle: CGFloat
    }

    private static func findMostThreateningPuck(
        to goals: [EnemyGoal],
        pucks: [HordePuck],
        paddle: HordePaddle,
        config: HordeDefenseConfig,
        difficulty: Difficulty
    ) -> ThreatInfo? {
        var bestThreat: ThreatInfo?
        var highestThreatLevel: CGFloat = 0

        let center = CGPoint(x: config.arenaRadius, y: config.arenaRadius)
        let predictionAccuracy = AIConstants.predictionAccuracy(for: difficulty)

        for puck in pucks where puck.isActive {
            // Calculate puck direction
            let puckAngle = atan2(puck.position.y - center.y, puck.position.x - center.x)
            let normalizedPuckAngle = normalizeAngle(puckAngle)

            // Calculate puck velocity direction
            let velocityAngle = atan2(puck.velocity.dy, puck.velocity.dx)
            let speed = puck.velocity.magnitude

            // Skip slow-moving pucks
            guard speed > 0.5 else { continue }

            // Predict where the puck will be
            let predictionTime: CGFloat = 1.0 * predictionAccuracy
            let predictedPosition = CGPoint(
                x: puck.position.x + puck.velocity.dx * predictionTime * 60, // 60fps
                y: puck.position.y + puck.velocity.dy * predictionTime * 60
            )
            let predictedAngle = atan2(predictedPosition.y - center.y, predictedPosition.x - center.x)
            let normalizedPredictedAngle = normalizeAngle(predictedAngle)

            // Check if puck is heading toward any defended goal
            for goal in goals {
                // Check if puck or predicted position is heading toward this goal
                let isCurrentlyTowardGoal = goal.containsAngle(normalizedPuckAngle) ||
                    isMovingTowardGoal(puck: puck, goal: goal, center: center)

                let isPredictedTowardGoal = goal.containsAngle(normalizedPredictedAngle)

                if isCurrentlyTowardGoal || isPredictedTowardGoal {
                    // Calculate threat level based on distance and speed
                    let distFromCenter = distance(from: center, to: puck.position)
                    let distToEdge = config.arenaRadius - distFromCenter
                    let threatLevel = speed / max(distToEdge, 1) * 100

                    if threatLevel > highestThreatLevel {
                        highestThreatLevel = threatLevel

                        // Calculate intercept angle (blend current and predicted)
                        let blendedAngle = normalizedPuckAngle * (1 - predictionAccuracy) +
                            normalizedPredictedAngle * predictionAccuracy

                        bestThreat = ThreatInfo(
                            puck: puck,
                            threatLevel: threatLevel,
                            interceptAngle: blendedAngle
                        )
                    }
                }
            }
        }

        return bestThreat
    }

    private static func isMovingTowardGoal(puck: HordePuck, goal: EnemyGoal, center: CGPoint) -> Bool {
        // Check if velocity is pointing outward and toward the goal
        let puckAngle = atan2(puck.position.y - center.y, puck.position.x - center.x)
        let velocityAngle = atan2(puck.velocity.dy, puck.velocity.dx)

        // Is velocity pointing away from center?
        let outwardComponent = cos(velocityAngle - puckAngle)
        guard outwardComponent > 0 else { return false }

        // Project where puck will cross the outer ring
        let distFromCenter = distance(from: center, to: puck.position)
        let speed = puck.velocity.magnitude

        guard speed > 0 else { return false }

        // Time to reach outer ring
        let timeToEdge = (center.x - distFromCenter) / (speed * outwardComponent)
        let projectedX = puck.position.x + puck.velocity.dx * timeToEdge * 2
        let projectedY = puck.position.y + puck.velocity.dy * timeToEdge * 2
        let projectedAngle = atan2(projectedY - center.y, projectedX - center.x)

        return goal.containsAngle(normalizeAngle(projectedAngle))
    }

    // MARK: - Movement

    private static func moveToIntercept(
        paddle: inout HordePaddle,
        targetAngle: CGFloat,
        config: HordeDefenseConfig,
        deltaTime: CGFloat,
        difficulty: Difficulty
    ) {
        let currentAngle = paddle.position.angle
        let speedMultiplier = AIConstants.speedMultiplier(for: difficulty)
        let speed = AIConstants.baseSpeed * speedMultiplier * deltaTime

        // Calculate shortest angular distance
        var angleDiff = normalizeAngle(targetAngle - currentAngle)
        if angleDiff > .pi {
            angleDiff -= 2 * .pi
        }

        // Move toward target
        if abs(angleDiff) > AIConstants.positionThreshold / config.arenaRadius {
            let direction: RailDirection = angleDiff > 0 ? .clockwise : .counterClockwise
            let moveDistance = min(abs(angleDiff) * config.arenaRadius, speed)

            // Update paddle position
            paddle.position = moveOnRing(
                from: paddle.position,
                direction: direction,
                distance: moveDistance,
                config: config
            )
        }
    }

    private static func patrolBetweenGoals(
        paddle: inout HordePaddle,
        goals: [EnemyGoal],
        config: HordeDefenseConfig,
        deltaTime: CGFloat,
        difficulty: Difficulty
    ) {
        guard !goals.isEmpty else { return }

        // Calculate patrol center (average of goal positions)
        let avgAngle = goals.reduce(0) { $0 + $1.centerAngle } / CGFloat(goals.count)
        let speedMultiplier = AIConstants.speedMultiplier(for: difficulty)
        let speed = AIConstants.baseSpeed * speedMultiplier * deltaTime * 0.5 // Slower patrol

        // Slight oscillation around patrol center
        let oscillation = sin(Date().timeIntervalSince1970 * 2) * 0.3

        let targetAngle = avgAngle + oscillation

        // Calculate shortest angular distance
        let currentAngle = paddle.position.angle
        var angleDiff = normalizeAngle(targetAngle - currentAngle)
        if angleDiff > .pi {
            angleDiff -= 2 * .pi
        }

        if abs(angleDiff) > 0.1 {
            let direction: RailDirection = angleDiff > 0 ? .clockwise : .counterClockwise
            let moveDistance = min(abs(angleDiff) * config.arenaRadius, speed)

            paddle.position = moveOnRing(
                from: paddle.position,
                direction: direction,
                distance: moveDistance,
                config: config
            )
        }
    }

    // MARK: - Movement Helpers

    private static func moveOnRing(
        from position: RailPosition,
        direction: RailDirection,
        distance: CGFloat,
        config: HordeDefenseConfig
    ) -> RailPosition {
        var newPosition = position

        // AI paddles always stay on the outer ring
        let ringRadius = config.ringRadii[position.ringIndex < config.ringRadii.count ? position.ringIndex : config.ringRadii.count - 1]
        let circumference = 2 * .pi * ringRadius
        let angleDelta = (distance / circumference) * 2 * .pi

        switch direction {
        case .clockwise:
            newPosition.angle = normalizeAngle(position.angle + angleDelta)
        case .counterClockwise:
            newPosition.angle = normalizeAngle(position.angle - angleDelta)
        default:
            break
        }

        return newPosition
    }

    // MARK: - Helper Functions

    private static func distance(from p1: CGPoint, to p2: CGPoint) -> CGFloat {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        return sqrt(dx * dx + dy * dy)
    }
}

// MARK: - AI Strategy Notes

/*
 AI Behavior Summary:

 1. GOAL ASSIGNMENT
    - Each AI paddle is assigned to defend 1-2 enemy goals
    - Adjacent goals are grouped for coverage

 2. THREAT DETECTION
    - AI monitors all active pucks
    - Calculates threat level based on:
      * Puck speed
      * Distance to outer ring
      * Direction toward defended goals

 3. PREDICTION (Difficulty-based)
    - Easy: Reacts to current puck position only
    - Medium: Some prediction of future position
    - Hard: Accurate prediction of intercept point

 4. MOVEMENT
    - AI moves along outer ring only
    - Speed varies by difficulty (70% / 85% / 100%)
    - Reaction time varies (300ms / 150ms / 50ms)

 5. PATROL
    - When no threats detected, AI patrols between assigned goals
    - Slight oscillation to appear more natural
 */
