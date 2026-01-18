/**
 * AI Opponent - Computer-Controlled Player
 *
 * Swift translation of ai/opponent.ts from @neonloop/core.
 * Calculates AI paddle movement based on puck position and difficulty settings.
 */

import Foundation
import CoreGraphics

final class AIOpponent {
    // MARK: - Properties

    private let aiConfig: AIConfig
    private let gameConfig: GameConfig

    // State tracking
    private var targetPosition: Position
    private var lastUpdateTime: TimeInterval = 0

    // MARK: - Initialization

    init(difficulty: Difficulty, config: GameConfig) {
        self.aiConfig = .config(for: difficulty)
        self.gameConfig = config
        self.targetPosition = Position(x: config.tableWidth / 2, y: config.paddleRadius + 40)
    }

    // MARK: - AI Calculation

    func calculateMove(puck: PuckState, currentPaddle: Position, currentTime: TimeInterval) -> Position {
        // Only update target based on reaction delay
        if currentTime - lastUpdateTime > aiConfig.reactionDelay {
            lastUpdateTime = currentTime
            targetPosition = calculateTargetPosition(puck: puck)
        }

        // Move towards target
        let newPosition = moveTowardsTarget(current: currentPaddle)

        // Constrain to valid play area
        return constrainPaddlePosition1v1(
            paddle: newPosition,
            radius: gameConfig.paddleRadius,
            config: gameConfig,
            isPlayer: false,
            playAreaShift: 0
        )
    }

    // MARK: - Private Methods

    private func calculateTargetPosition(puck: PuckState) -> Position {
        // Default Y position (near AI's goal area)
        let defaultY = gameConfig.paddleRadius + 40
        var targetX = puck.position.x
        let targetY = defaultY

        // If puck is moving towards AI (negative dy = towards top)
        if puck.velocity.dy < 0 {
            // Predict where puck will be when it reaches AI's Y position
            let timeToReach = abs(puck.position.y - targetY) / abs(puck.velocity.dy)
            let predictedX = puck.position.x + puck.velocity.dx * timeToReach * aiConfig.predictionSkill

            // Clamp prediction to table bounds
            targetX = clamp(
                predictedX,
                min: gameConfig.paddleRadius,
                max: gameConfig.tableWidth - gameConfig.paddleRadius
            )
        } else {
            // Puck moving away - return to center
            targetX = gameConfig.tableWidth / 2
        }

        // Add inaccuracy based on difficulty
        let inaccuracy = (1 - aiConfig.accuracy) * 50
        targetX += CGFloat.random(in: -0.5...0.5) * inaccuracy

        return Position(x: targetX, y: targetY)
    }

    private func moveTowardsTarget(current: Position) -> Position {
        let dx = targetPosition.x - current.x
        let dy = targetPosition.y - current.y
        let dist = sqrt(dx * dx + dy * dy)

        // Already at target
        guard dist > 1 else { return current }

        // Move towards target, but don't overshoot
        let moveSpeed = min(aiConfig.maxSpeed, dist)
        return Position(
            x: current.x + (dx / dist) * moveSpeed,
            y: current.y + (dy / dist) * moveSpeed
        )
    }
}
