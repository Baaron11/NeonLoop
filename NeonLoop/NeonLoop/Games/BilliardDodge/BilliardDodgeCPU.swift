/**
 * BilliardDodge CPU - AI Shot Selection
 *
 * Handles CPU opponent logic that escalates by round:
 * - Rounds 1-3 (Easy): Random target, 70% accuracy, slow shot
 * - Rounds 4-6 (Medium): Closest ball to pocket, 85% accuracy
 * - Rounds 7-10 (Hard): Best available shot, 95% accuracy
 * - Rounds 11+ (Expert): Predicts player movement, uses bank shots
 */

import Foundation
import SwiftUI

// MARK: - CPU AI

enum BilliardDodgeCPU {

    // MARK: - Shot Calculation

    /// Calculates the CPU's shot for the current round
    static func calculateShot(state: BilliardDodgeState) -> CPUShot {
        let difficulty = CPUDifficulty.forRound(state.currentRound)
        let activeBalls = state.activeBalls

        guard !activeBalls.isEmpty else {
            // No targets, shoot randomly
            return randomShot(state: state, difficulty: difficulty)
        }

        switch difficulty {
        case .easy:
            return easyShot(state: state, targets: activeBalls, difficulty: difficulty)
        case .medium:
            return mediumShot(state: state, targets: activeBalls, difficulty: difficulty)
        case .hard:
            return hardShot(state: state, targets: activeBalls, difficulty: difficulty)
        case .expert:
            return expertShot(state: state, targets: activeBalls, difficulty: difficulty)
        }
    }

    // MARK: - Easy AI (Rounds 1-3)

    /// Random target selection with low accuracy
    private static func easyShot(state: BilliardDodgeState, targets: [BilliardBall], difficulty: CPUDifficulty) -> CPUShot {
        // Pick a random target
        guard let target = targets.randomElement() else {
            return randomShot(state: state, difficulty: difficulty)
        }

        // Calculate base angle to target
        let baseAngle = BilliardDodgePhysics.angleToTarget(
            from: state.cueBall.position,
            to: target.position
        )

        // Add inaccuracy
        let inaccuracy = applyInaccuracy(baseAngle: baseAngle, accuracy: difficulty.accuracy)

        // Random power in easy range
        let power = CGFloat.random(in: difficulty.shotPower)

        return CPUShot(angle: inaccuracy, power: power, targetBallId: target.id)
    }

    // MARK: - Medium AI (Rounds 4-6)

    /// Targets ball closest to a pocket
    private static func mediumShot(state: BilliardDodgeState, targets: [BilliardBall], difficulty: CPUDifficulty) -> CPUShot {
        // Find ball closest to any pocket
        let target = findBestTargetByPocketProximity(targets: targets, config: state.config)

        // Calculate angle to pocket the target
        let pocket = BilliardDodgePhysics.closestPocket(to: target.position, config: state.config)
        let angle = calculatePocketingAngle(
            cueBall: state.cueBall.position,
            targetBall: target.position,
            pocket: pocket,
            config: state.config
        )

        // Apply accuracy variance
        let finalAngle = applyInaccuracy(baseAngle: angle, accuracy: difficulty.accuracy)

        // Medium power range
        let power = CGFloat.random(in: difficulty.shotPower)

        return CPUShot(angle: finalAngle, power: power, targetBallId: target.id)
    }

    // MARK: - Hard AI (Rounds 7-10)

    /// Evaluates all shots and picks the best one
    private static func hardShot(state: BilliardDodgeState, targets: [BilliardBall], difficulty: CPUDifficulty) -> CPUShot {
        var bestShot: CPUShot?
        var bestScore: CGFloat = -1

        for target in targets {
            // Evaluate each pocket option
            for pocket in state.config.pocketPositions() {
                let score = evaluateShot(
                    cueBall: state.cueBall.position,
                    target: target.position,
                    pocket: pocket,
                    config: state.config
                )

                if score > bestScore {
                    bestScore = score
                    let angle = calculatePocketingAngle(
                        cueBall: state.cueBall.position,
                        targetBall: target.position,
                        pocket: pocket,
                        config: state.config
                    )
                    let power = calculateOptimalPower(distance: BilliardDodgePhysics.distance(from: state.cueBall.position, to: target.position), config: state.config)
                    bestShot = CPUShot(angle: angle, power: min(power, difficulty.shotPower.upperBound), targetBallId: target.id)
                }
            }
        }

        guard var shot = bestShot else {
            return mediumShot(state: state, targets: targets, difficulty: difficulty)
        }

        // Apply slight inaccuracy even at hard
        let finalAngle = applyInaccuracy(baseAngle: shot.angle, accuracy: difficulty.accuracy)
        shot = CPUShot(angle: finalAngle, power: shot.power, targetBallId: shot.targetBallId)

        return shot
    }

    // MARK: - Expert AI (Rounds 11+)

    /// Predicts player movement and uses bank shots
    private static func expertShot(state: BilliardDodgeState, targets: [BilliardBall], difficulty: CPUDifficulty) -> CPUShot {
        // Expert AI tries to predict where players might move
        // and aims for where they'll likely be

        var predictedTargets: [(ball: BilliardBall, predictedPos: CGPoint)] = []

        for target in targets {
            guard let playerId = target.playerId,
                  let move = state.playerMoves[playerId],
                  move.force > 0 else {
                // No known move, use current position
                predictedTargets.append((target, target.position))
                continue
            }

            // Predict where the player will move to
            let predictedMove = CGVector(
                dx: cos(move.angle) * move.force * state.config.maxForce * 0.5,
                dy: sin(move.angle) * move.force * state.config.maxForce * 0.5
            )
            let predictedPos = CGPoint(
                x: target.position.x + predictedMove.dx,
                y: target.position.y + predictedMove.dy
            )
            predictedTargets.append((target, predictedPos))
        }

        // Find best shot considering predicted positions
        var bestShot: CPUShot?
        var bestScore: CGFloat = -1

        for (target, predictedPos) in predictedTargets {
            for pocket in state.config.pocketPositions() {
                // Consider bank shots for expert level
                let directScore = evaluateShot(
                    cueBall: state.cueBall.position,
                    target: predictedPos,
                    pocket: pocket,
                    config: state.config
                )

                let bankScore = evaluateBankShot(
                    cueBall: state.cueBall.position,
                    target: predictedPos,
                    pocket: pocket,
                    config: state.config
                )

                let score = max(directScore, bankScore * 0.8) // Prefer direct shots slightly

                if score > bestScore {
                    bestScore = score

                    let angle: CGFloat
                    let power: CGFloat

                    if bankScore > directScore {
                        // Use bank shot
                        (angle, power) = calculateBankShot(
                            cueBall: state.cueBall.position,
                            target: predictedPos,
                            pocket: pocket,
                            config: state.config
                        )
                    } else {
                        angle = calculatePocketingAngle(
                            cueBall: state.cueBall.position,
                            targetBall: predictedPos,
                            pocket: pocket,
                            config: state.config
                        )
                        power = calculateOptimalPower(distance: BilliardDodgePhysics.distance(from: state.cueBall.position, to: predictedPos), config: state.config)
                    }

                    bestShot = CPUShot(angle: angle, power: min(power, difficulty.shotPower.upperBound), targetBallId: target.id)
                }
            }
        }

        guard var shot = bestShot else {
            return hardShot(state: state, targets: targets, difficulty: difficulty)
        }

        // Even expert has tiny variance
        let finalAngle = applyInaccuracy(baseAngle: shot.angle, accuracy: difficulty.accuracy)
        shot = CPUShot(angle: finalAngle, power: shot.power, targetBallId: shot.targetBallId)

        return shot
    }

    // MARK: - Helper Functions

    private static func randomShot(state: BilliardDodgeState, difficulty: CPUDifficulty) -> CPUShot {
        let angle = CGFloat.random(in: 0..<(.pi * 2))
        let power = CGFloat.random(in: difficulty.shotPower)
        return CPUShot(angle: angle, power: power, targetBallId: nil)
    }

    private static func applyInaccuracy(baseAngle: CGFloat, accuracy: CGFloat) -> CGFloat {
        // Accuracy 1.0 = perfect, 0.0 = random
        // Max inaccuracy is about 30 degrees (pi/6)
        let maxError = CGFloat.pi / 6 * (1 - accuracy)
        let error = CGFloat.random(in: -maxError...maxError)
        return baseAngle + error
    }

    private static func findBestTargetByPocketProximity(targets: [BilliardBall], config: BilliardDodgeConfig) -> BilliardBall {
        let pockets = config.pocketPositions()

        return targets.min { ball1, ball2 in
            let dist1 = pockets.map { BilliardDodgePhysics.distance(from: ball1.position, to: $0) }.min() ?? .infinity
            let dist2 = pockets.map { BilliardDodgePhysics.distance(from: ball2.position, to: $0) }.min() ?? .infinity
            return dist1 < dist2
        } ?? targets[0]
    }

    private static func calculatePocketingAngle(cueBall: CGPoint, targetBall: CGPoint, pocket: CGPoint, config: BilliardDodgeConfig) -> CGFloat {
        // Calculate the angle to hit the target ball such that it goes toward the pocket
        // This is the "ghost ball" method

        // Direction from target to pocket
        let targetToPocketAngle = BilliardDodgePhysics.angleToTarget(from: targetBall, to: pocket)

        // Ghost ball position (where cue ball needs to hit)
        let ghostBallPos = CGPoint(
            x: targetBall.x - cos(targetToPocketAngle) * config.ballRadius * 2,
            y: targetBall.y - sin(targetToPocketAngle) * config.ballRadius * 2
        )

        // Angle from cue ball to ghost ball position
        return BilliardDodgePhysics.angleToTarget(from: cueBall, to: ghostBallPos)
    }

    private static func calculateOptimalPower(distance: CGFloat, config: BilliardDodgeConfig) -> CGFloat {
        // Scale power based on distance
        let normalized = distance / (config.tableWidth * 0.7) // Normalize to typical shot distance
        return min(max(normalized * 0.6 + 0.3, 0.3), 1.0)
    }

    private static func evaluateShot(cueBall: CGPoint, target: CGPoint, pocket: CGPoint, config: BilliardDodgeConfig) -> CGFloat {
        // Score a potential shot (0-1, higher is better)

        let cueToBallDist = BilliardDodgePhysics.distance(from: cueBall, to: target)
        let ballToPocketDist = BilliardDodgePhysics.distance(from: target, to: pocket)

        // Prefer shorter total distances
        let distanceScore = 1.0 - min((cueToBallDist + ballToPocketDist) / (config.tableWidth * 2), 1.0)

        // Check if the line from cue to target is clear (simplified)
        let lineAngle = BilliardDodgePhysics.angleToTarget(from: cueBall, to: target)
        let pocketAngle = BilliardDodgePhysics.angleToTarget(from: target, to: pocket)

        // Calculate the cut angle (difference between incoming and outgoing)
        let cutAngle = abs(angleDifference(lineAngle + .pi, pocketAngle))

        // Prefer straighter shots (cut angle close to 0)
        let angleScore = 1.0 - (cutAngle / (.pi / 2))

        return (distanceScore * 0.4 + max(angleScore, 0) * 0.6)
    }

    private static func evaluateBankShot(cueBall: CGPoint, target: CGPoint, pocket: CGPoint, config: BilliardDodgeConfig) -> CGFloat {
        // Simplified bank shot evaluation
        // Check if bouncing off a rail would create a better angle

        // For simplicity, only consider if target is near a rail
        let nearRail = target.x < config.ballRadius * 4 ||
                       target.x > config.tableWidth - config.ballRadius * 4 ||
                       target.y < config.ballRadius * 4 ||
                       target.y > config.tableHeight - config.ballRadius * 4

        if nearRail {
            return evaluateShot(cueBall: cueBall, target: target, pocket: pocket, config: config) * 0.9
        }

        return 0
    }

    private static func calculateBankShot(cueBall: CGPoint, target: CGPoint, pocket: CGPoint, config: BilliardDodgeConfig) -> (angle: CGFloat, power: CGFloat) {
        // Simplified bank shot - just aim directly with extra power
        let angle = BilliardDodgePhysics.angleToTarget(from: cueBall, to: target)
        let distance = BilliardDodgePhysics.distance(from: cueBall, to: target)
        let power = calculateOptimalPower(distance: distance * 1.3, config: config)
        return (angle, power)
    }

    private static func angleDifference(_ a1: CGFloat, _ a2: CGFloat) -> CGFloat {
        var diff = a2 - a1
        while diff > .pi { diff -= .pi * 2 }
        while diff < -.pi { diff += .pi * 2 }
        return diff
    }
}
