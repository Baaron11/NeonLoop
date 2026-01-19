/**
 * Foosball AI - Artificial Intelligence for AI Rods
 *
 * Handles AI rod behavior including positioning, tracking the ball,
 * and deciding when to kick. Difficulty affects reaction time, accuracy,
 * and kick timing.
 */

import Foundation
import SwiftUI

// MARK: - AI Controller

enum FoosballAI {

    // MARK: - Main Update

    /// Update all AI rods for one frame
    static func update(
        state: FoosballState,
        deltaTime: CGFloat,
        currentTime: TimeInterval
    ) {
        guard state.phase.isActive else { return }

        let difficulty = state.difficulty

        for i in 0..<state.aiRods.count {
            updateRod(
                rod: &state.aiRods[i],
                state: state,
                difficulty: difficulty,
                deltaTime: deltaTime,
                currentTime: currentTime
            )
        }
    }

    // MARK: - Individual Rod Update

    private static func updateRod(
        rod: inout FoosballRod,
        state: FoosballState,
        difficulty: FoosballDifficulty,
        deltaTime: CGFloat,
        currentTime: TimeInterval
    ) {
        let ball = state.ball
        let config = state.config

        // Get strategy for this rod type
        let strategy = getStrategy(for: rod.rodType)

        // Calculate target position based on strategy
        let targetX = calculateTargetPosition(
            rod: rod,
            ball: ball,
            config: config,
            strategy: strategy,
            difficulty: difficulty
        )

        // Move rod toward target with some delay based on difficulty
        let reactionFactor = 1.0 - (difficulty.reactionDelay * 2)  // Faster reaction = faster movement
        let moveSpeed = CGFloat(0.02 + 0.03 * reactionFactor) * deltaTime

        let currentX = rod.xOffset
        let diff = targetX - currentX

        if abs(diff) > 0.01 {
            // Add some accuracy wobble for easier difficulties
            let accuracyWobble = (1.0 - difficulty.accuracy) * CGFloat.random(in: -0.1...0.1)
            let newX = currentX + diff * moveSpeed + accuracyWobble
            rod.xOffset = max(-1.0, min(1.0, newX))
        }

        // Decide whether to kick
        if shouldKick(rod: rod, ball: ball, config: config, strategy: strategy, difficulty: difficulty) {
            if case .idle = rod.kickState {
                // Random chance based on kick timing skill
                if CGFloat.random(in: 0...1) < difficulty.kickTiming {
                    let kickType: KickType = CGFloat.random(in: 0...1) < 0.3 ? .pullShot : .forward
                    rod.kickState = .kicking(type: kickType, progress: 0)
                }
            }
        }
    }

    // MARK: - Strategy

    private enum RodStrategy {
        case defensive      // Stay between ball and goal
        case interceptor    // Track ball X position
        case aggressive     // Move toward ball and shoot
        case goalie         // Guard the goal
    }

    private static func getStrategy(for rodType: RodType) -> RodStrategy {
        switch rodType {
        case .goalie:
            return .goalie
        case .defense:
            return .defensive
        case .midfield:
            return .interceptor
        case .attack:
            return .aggressive
        }
    }

    // MARK: - Target Position

    private static func calculateTargetPosition(
        rod: FoosballRod,
        ball: FoosballBall,
        config: FoosballConfig,
        strategy: RodStrategy,
        difficulty: FoosballDifficulty
    ) -> CGFloat {
        let halfWidth = config.tableWidth / 2

        switch strategy {
        case .goalie:
            // Track ball X but stay centered more
            // Predict where ball will be when it reaches goalie Y
            let predictedX = predictBallX(ball: ball, targetY: rod.yPosition, config: config)
            let normalizedX = predictedX / halfWidth
            // Goalie stays more centered, doesn't chase as aggressively
            return normalizedX * 0.8

        case .defensive:
            // Stay between ball and goal, with emphasis on blocking
            let ballNormalizedX = ball.position.x / halfWidth
            // If ball is coming toward our goal (positive Y for AI), track more closely
            if ball.velocity.dy < 0 {
                let predictedX = predictBallX(ball: ball, targetY: rod.yPosition, config: config)
                return predictedX / halfWidth
            }
            return ballNormalizedX * 0.9

        case .interceptor:
            // Most active - track ball position directly
            let predictedX = predictBallX(ball: ball, targetY: rod.yPosition, config: config)
            return predictedX / halfWidth

        case .aggressive:
            // Position for shots toward player goal
            // When ball is near, align to shoot
            let ballY = ball.position.y
            let rodY = rod.yPosition

            if abs(ballY - rodY) < 80 {
                // Ball is close, position to hit
                return ball.position.x / halfWidth
            } else if ball.velocity.dy > 0 {
                // Ball coming toward us, prepare to intercept
                let predictedX = predictBallX(ball: ball, targetY: rod.yPosition, config: config)
                return predictedX / halfWidth
            } else {
                // Ball going away, stay somewhat centered for pass interception
                return ball.position.x / halfWidth * 0.5
            }
        }
    }

    private static func predictBallX(ball: FoosballBall, targetY: CGFloat, config: FoosballConfig) -> CGFloat {
        // Simple prediction: where will ball be when it reaches targetY?
        let dy = targetY - ball.position.y

        if ball.velocity.dy == 0 || (dy > 0 && ball.velocity.dy < 0) || (dy < 0 && ball.velocity.dy > 0) {
            // Ball not moving toward target, or moving away
            return ball.position.x
        }

        let timeToReach = abs(dy / ball.velocity.dy)
        var predictedX = ball.position.x + ball.velocity.dx * timeToReach

        // Clamp to table bounds and account for bounces (simplified)
        let halfWidth = config.tableWidth / 2
        while abs(predictedX) > halfWidth {
            if predictedX > halfWidth {
                predictedX = 2 * halfWidth - predictedX
            } else if predictedX < -halfWidth {
                predictedX = -2 * halfWidth - predictedX
            }
        }

        return predictedX
    }

    // MARK: - Kick Decision

    private static func shouldKick(
        rod: FoosballRod,
        ball: FoosballBall,
        config: FoosballConfig,
        strategy: RodStrategy,
        difficulty: FoosballDifficulty
    ) -> Bool {
        // Only kick if not already kicking
        guard case .idle = rod.kickState else { return false }

        let positions = rod.foosmenPositions(config: config)
        let kickRange = config.manHeight + config.ballRadius + 15

        // Check if any foosman is close enough to the ball
        for pos in positions {
            let dx = ball.position.x - pos.x
            let dy = ball.position.y - pos.y
            let dist = sqrt(dx * dx + dy * dy)

            if dist < kickRange {
                // Ball is in range!
                switch strategy {
                case .goalie:
                    // Goalie kicks defensively - when ball is close and moving toward goal
                    return ball.velocity.dy < 0 || dist < config.manHeight

                case .defensive:
                    // Defense kicks to clear - when ball is close
                    return dist < kickRange * 0.8

                case .interceptor:
                    // Midfield kicks opportunistically
                    return CGFloat.random(in: 0...1) < 0.6

                case .aggressive:
                    // Attack kicks aggressively toward player goal
                    // Better chance if ball is in front (can push toward goal)
                    let inFrontOfRod = ball.position.y > rod.yPosition
                    return inFrontOfRod || CGFloat.random(in: 0...1) < 0.4
                }
            }
        }

        return false
    }
}
