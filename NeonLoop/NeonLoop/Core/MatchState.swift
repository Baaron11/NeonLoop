/**
 * Match State - Observable Game State Container
 *
 * This class holds the current game state and provides methods to update it.
 * It uses @Observable for SwiftUI integration.
 */

import Foundation
import SwiftUI

@Observable
final class MatchState {
    // MARK: - Properties

    var state: GameState
    var config: GameConfig
    var difficulty: Difficulty
    var gameMode: GameMode

    // Events for this frame (cleared each update)
    var pendingEvents: [GameEvent] = []

    // MARK: - Initialization

    init(config: GameConfig = .default, difficulty: Difficulty = .medium, gameMode: GameMode = .oneVsOne) {
        self.config = config
        self.difficulty = difficulty
        self.gameMode = gameMode
        self.state = .initial(config: config)
    }

    // MARK: - Computed Properties

    var puck: PuckState { state.puck }
    var playerPaddle: Position { state.playerPaddle }
    var opponentPaddle: Position { state.opponentPaddle }
    var playerScore: Int { state.playerScore }
    var opponentScore: Int { state.opponentScore }
    var isPlaying: Bool { state.isPlaying }
    var isPaused: Bool { state.isPaused }
    var winner: PlayerID? { state.winner }
    var playAreaShift: CGFloat { state.playAreaShift }

    // MARK: - Game Actions

    func startGame() {
        let towardsPlayer = Bool.random()
        state.puck = createPuck(config: config, towardsPlayer: towardsPlayer)
        state.playerScore = 0
        state.opponentScore = 0
        state.isPlaying = true
        state.isPaused = false
        state.winner = nil
        state.lastGoalScorer = nil
        state.playAreaShift = 0

        pendingEvents.append(GameEvent(type: .gameStarted))
    }

    func togglePause() {
        state.isPaused.toggle()
        pendingEvents.append(GameEvent(type: state.isPaused ? .gamePaused : .gameResumed))
    }

    func reset() {
        state = .initial(config: config)
        pendingEvents.removeAll()
    }

    // MARK: - Input Handling

    func movePlayerPaddle(to position: Position) {
        state.playerPaddle = constrainPaddlePosition1v1(
            paddle: position,
            radius: config.paddleRadius,
            config: config,
            isPlayer: true,
            playAreaShift: state.playAreaShift
        )
    }

    func moveOpponentPaddle(to position: Position) {
        state.opponentPaddle = constrainPaddlePosition1v1(
            paddle: position,
            radius: config.paddleRadius,
            config: config,
            isPlayer: false,
            playAreaShift: state.playAreaShift
        )
    }

    // MARK: - Game Update

    func update(deltaTime: CGFloat, realDeltaTime: TimeInterval, aiPosition: Position? = nil) {
        // Clear pending events
        pendingEvents.removeAll()

        // Skip if not playing
        guard state.isPlaying && !state.isPaused && state.winner == nil else {
            return
        }

        // Update AI paddle if provided
        if let aiPos = aiPosition {
            state.opponentPaddle = constrainPaddlePosition1v1(
                paddle: aiPos,
                radius: config.paddleRadius,
                config: config,
                isPlayer: false,
                playAreaShift: state.playAreaShift
            )
        }

        // Update puck
        updatePuck(deltaTime: deltaTime, realDeltaTime: realDeltaTime)
    }

    // MARK: - Private Update Methods

    private func updatePuck(deltaTime: CGFloat, realDeltaTime: TimeInterval) {
        // Update position
        var newPuck = updatePuckPosition(puck: state.puck, config: config, deltaTime: deltaTime)

        // Stuck detection
        let speed = newPuck.velocity.magnitude
        if speed < GameConstants.stuckThreshold {
            newPuck.stuckTime += realDeltaTime
            newPuck.isFlashing = newPuck.stuckTime >= GameConstants.stuckFlashTime

            // Boost if stuck too long
            if newPuck.stuckTime >= GameConstants.stuckBoostTime {
                let angle = CGFloat.random(in: 0..<(.pi * 2))
                let boostSpeed = config.puckSpeed * 1.2
                newPuck.velocity.dx = cos(angle) * boostSpeed
                newPuck.velocity.dy = sin(angle) * boostSpeed
                newPuck.stuckTime = 0
                newPuck.isFlashing = false
                pendingEvents.append(GameEvent(type: .puckBoosted))
            }
        } else {
            newPuck.stuckTime = 0
            newPuck.isFlashing = false
        }

        state.puck = newPuck

        // Check goal
        let puckCircle = Circle(position: newPuck.position, radius: config.puckRadius)
        if let goal = checkGoal(puckCircle, config: config) {
            handleGoal(scorer: goal == .player ? .player : .opponent)
            return
        }

        // Wall collisions
        let walls = checkWallCollision(puckCircle, config: config)
        if walls.hitLeft || walls.hitRight {
            pendingEvents.append(GameEvent(type: .wallHit))
            state.puck.velocity.dx = -state.puck.velocity.dx * 0.9
            state.puck.position.x = walls.hitLeft ? config.puckRadius : config.tableWidth - config.puckRadius
        }
        if walls.hitTop || walls.hitBottom {
            pendingEvents.append(GameEvent(type: .wallHit))
            state.puck.velocity.dy = -state.puck.velocity.dy * 0.9
            state.puck.position.y = walls.hitTop ? config.puckRadius : config.tableHeight - config.puckRadius
        }

        // Paddle collisions
        checkPaddleCollision(paddle: state.playerPaddle, playerId: .player)
        checkPaddleCollision(paddle: state.opponentPaddle, playerId: .opponent)

        // Limit speed
        state.puck = limitPuckSpeed(puck: state.puck, config: config)
    }

    private func checkPaddleCollision(paddle: Position, playerId: PlayerID) {
        let puckCircle = Circle(position: state.puck.position, radius: config.puckRadius)
        let paddleCircle = Circle(position: paddle, radius: config.paddleRadius)

        guard checkCircleCollision(puckCircle, paddleCircle) else { return }

        let intensity = min(1, 0.3 + CGFloat(state.puck.hitCount) * 0.1)
        pendingEvents.append(GameEvent(type: .paddleHit, intensity: intensity))

        // Resolve collision
        let newVelocity = resolvePaddlePuckCollision(
            puck: puckCircle,
            puckVelocity: state.puck.velocity,
            paddle: paddleCircle,
            hitCount: state.puck.hitCount,
            config: config
        )

        state.puck.velocity = newVelocity
        state.puck.hitCount += 1
        state.puck.lastHitBy = playerId

        // Separate circles
        let separated = separateCircles(movable: puckCircle, stationary: paddleCircle)
        state.puck.position = separated
    }

    private func handleGoal(scorer: PlayerID) {
        let isPlayerGoal = scorer == .player

        pendingEvents.append(GameEvent(type: .goalScored, scorer: scorer))

        // Update score
        if isPlayerGoal {
            state.playerScore += 1
        } else {
            state.opponentScore += 1
        }

        // Check for winner
        if state.playerScore >= config.maxScore {
            state.winner = .player
            state.isPlaying = false
            pendingEvents.append(GameEvent(type: .gameEnded, winner: .player))
            return
        }

        if state.opponentScore >= config.maxScore {
            state.winner = .opponent
            state.isPlaying = false
            pendingEvents.append(GameEvent(type: .gameEnded, winner: .opponent))
            return
        }

        // Update play area shift
        let shiftChange = isPlayerGoal ? -GameConstants.playAreaShiftAmount : GameConstants.playAreaShiftAmount
        state.playAreaShift = clamp(
            state.playAreaShift + shiftChange,
            min: -GameConstants.maxPlayAreaShift,
            max: GameConstants.maxPlayAreaShift
        )

        // Reset puck
        state.puck = createPuck(config: config, towardsPlayer: !isPlayerGoal)
        state.lastGoalScorer = scorer
    }
}
