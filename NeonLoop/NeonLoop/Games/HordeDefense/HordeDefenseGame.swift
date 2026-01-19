/**
 * HordeDefense Game - Main Game Controller
 *
 * Implements the NeonLoopGame protocol and manages the complete game lifecycle.
 * Handles the countdown sequence, physics updates, AI updates, and goal detection.
 *
 * Game Flow:
 * 1. Settings screen - configure difficulty, paddle counts, etc.
 * 2. Countdown (3, 2, 1, GO!)
 * 3. Pucks spawn and start moving
 * 4. Players deflect pucks toward enemy goals
 * 5. AI paddles defend enemy goals
 * 6. Goal scored → brief pause → puck respawns
 * 7. First to target score wins
 */

import Foundation
import SwiftUI
import QuartzCore

// MARK: - HordeDefense Game Coordinator

@Observable
final class HordeDefenseGameCoordinator {
    var state: HordeDefenseState
    var isRunning: Bool = false

    private var displayLink: CADisplayLink?
    private var lastUpdateTime: CFTimeInterval = 0
    private var countdownTimer: Timer?
    private var goalScoredTimer: Timer?

    init() {
        self.state = HordeDefenseState()
    }

    // MARK: - Game Setup

    func setupGame() {
        state.setupGame()
    }

    func setupSinglePlayer() {
        state.settingsDefenderCount = 1
        state.settingsAttackerCount = 2
        state.settingsPuckCount = 1
        setupGame()
    }

    // MARK: - Game Control

    func startGame() {
        setupGame()
        startCountdown()
    }

    func startFromSettings() {
        state.applySettings()
        setupGame()
        startCountdown()
    }

    private func startCountdown() {
        state.startCountdown()
        countdownTimer?.invalidate()

        // Use .common mode so timer fires even during UI animations
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            self.state.decrementCountdown()

            if case .playing = self.state.phase {
                timer.invalidate()
                self.countdownTimer = nil
                self.startGameLoop()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        countdownTimer = timer
    }

    func stopGame() {
        stopGameLoop()
        countdownTimer?.invalidate()
        countdownTimer = nil
        goalScoredTimer?.invalidate()
        goalScoredTimer = nil
        isRunning = false
    }

    // MARK: - Game Loop

    private func startGameLoop() {
        stopGameLoop()
        isRunning = true

        displayLink = CADisplayLink(target: self, selector: #selector(gameLoopTick))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 60)
        displayLink?.add(to: .main, forMode: .common)
        lastUpdateTime = CACurrentMediaTime()
    }

    private func stopGameLoop() {
        displayLink?.invalidate()
        displayLink = nil
        isRunning = false
    }

    @objc private func gameLoopTick(_ link: CADisplayLink) {
        let currentTime = link.timestamp
        let deltaTime = currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        // Normalize delta time (target 60fps)
        let normalizedDelta = CGFloat(deltaTime) * 60.0

        // Update physics
        HordeDefensePhysics.step(state: state, deltaTime: normalizedDelta)

        // Update AI
        HordeDefenseAI.updateAIPaddles(state: state, deltaTime: normalizedDelta)

        // Check for goals
        checkGoals()
    }

    // MARK: - Goal Detection

    private func checkGoals() {
        guard state.phase.isActive else { return }

        for i in state.pucks.indices {
            guard state.pucks[i].isActive else { continue }

            // Check center goal (AI scores)
            if HordeDefensePhysics.checkCenterGoal(puck: state.pucks[i], config: state.config) {
                state.pucks[i].isActive = false
                handleGoal(playerScored: false, goalIndex: nil)
                return
            }

            // Check enemy goals (Players score)
            if let goal = HordeDefensePhysics.checkEnemyGoals(
                puck: state.pucks[i],
                goals: state.enemyGoals,
                config: state.config
            ) {
                state.pucks[i].isActive = false
                handleGoal(playerScored: true, goalIndex: goal.index)
                return
            }
        }
    }

    private func handleGoal(playerScored: Bool, goalIndex: Int?) {
        stopGameLoop()
        state.handleGoalScored(playerScored: playerScored, goalIndex: goalIndex)

        // Brief pause before resuming
        goalScoredTimer?.invalidate()
        goalScoredTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            self?.resumeAfterGoal()
        }
    }

    private func resumeAfterGoal() {
        state.resumeAfterGoal()

        // Check if game is over
        if case .gameOver = state.phase {
            // Game over - don't restart loop
            return
        }

        // Resume play
        startGameLoop()
    }

    // MARK: - Player Input

    func handlePlayerMove(playerId: String, direction: RailDirection, distance: CGFloat) {
        guard state.phase.isActive else { return }
        state.movePaddle(paddleId: playerId, direction: direction, distance: distance)
    }

    func handlePlayerSwitchRing(playerId: String, goInward: Bool) {
        guard state.phase.isActive else { return }

        // Find the player paddle
        guard let index = state.playerPaddles.firstIndex(where: { $0.id == playerId }) else { return }

        let paddle = state.playerPaddles[index]

        // Check if at a junction
        guard paddle.position.isAtJunction(config: state.config) else { return }

        // Switch ring
        let direction: RailDirection = goInward ? .inward : .outward
        state.movePaddle(paddleId: playerId, direction: direction, distance: 5)
    }

    // MARK: - Settings

    func setDifficulty(_ difficulty: Difficulty) {
        state.settingsDifficulty = difficulty
    }

    func setDefenderCount(_ count: Int) {
        state.settingsDefenderCount = max(1, min(3, count))
    }

    func setAttackerCount(_ count: Int) {
        state.settingsAttackerCount = max(1, min(3, count))
    }

    func setPuckCount(_ count: Int) {
        state.settingsPuckCount = max(1, min(3, count))
    }

    func setTargetScore(_ score: Int) {
        state.settingsTargetScore = score
    }

    // MARK: - State Queries

    var isGameOver: Bool {
        switch state.phase {
        case .gameOver: return true
        default: return false
        }
    }

    var playerWon: Bool {
        switch state.phase {
        case .gameOver(let won): return won
        default: return false
        }
    }
}

// MARK: - NeonLoopGame Protocol Conformance

extension HordeDefenseGameCoordinator: NeonLoopGame {
    var gameId: String { "horde_defense" }
    var gameName: String { "Horde Defense" }
    var isImplemented: Bool { true }
    var minPlayers: Int { 1 }
    var maxPlayers: Int { 3 }
    var inputType: GameInputType { .position }

    func setup(players: [Player], modifiers: [GameModifier]) {
        state.settingsDefenderCount = players.count
        setupGame()

        // Apply modifiers
        for modifier in modifiers {
            applyModifier(modifier)
        }
    }

    func handleInput(playerId: String, input: GameInput) {
        switch input {
        case .position(let point):
            // Convert position to rail movement
            handlePositionInput(playerId: playerId, position: point)

        default:
            break
        }
    }

    func update(deltaTime: CGFloat) {
        // Physics update is handled by the display link
        HordeDefensePhysics.step(state: state, deltaTime: deltaTime)
        HordeDefenseAI.updateAIPaddles(state: state, deltaTime: deltaTime)
    }

    var winner: Player? {
        // This is a cooperative game - no individual winner
        nil
    }

    private func applyModifier(_ modifier: GameModifier) {
        switch modifier.id {
        case "speed_boost":
            // Increase puck speed
            state.config = HordeDefenseConfig(
                arenaRadius: state.config.arenaRadius,
                centerGoalRadius: state.config.centerGoalRadius,
                ringRadii: state.config.ringRadii,
                spokeCount: state.config.spokeCount,
                enemyGoalCount: state.config.enemyGoalCount,
                enemyGoalArcWidth: state.config.enemyGoalArcWidth,
                paddleLength: state.config.paddleLength,
                paddleThickness: state.config.paddleThickness,
                puckRadius: state.config.puckRadius,
                puckSpeed: state.config.puckSpeed * 1.5,
                targetScore: state.config.targetScore,
                defenderCount: state.config.defenderCount,
                attackerCount: state.config.attackerCount,
                puckCount: state.config.puckCount
            )

        case "multi_puck":
            state.config = HordeDefenseConfig(
                arenaRadius: state.config.arenaRadius,
                centerGoalRadius: state.config.centerGoalRadius,
                ringRadii: state.config.ringRadii,
                spokeCount: state.config.spokeCount,
                enemyGoalCount: state.config.enemyGoalCount,
                enemyGoalArcWidth: state.config.enemyGoalArcWidth,
                paddleLength: state.config.paddleLength,
                paddleThickness: state.config.paddleThickness,
                puckRadius: state.config.puckRadius,
                puckSpeed: state.config.puckSpeed,
                targetScore: state.config.targetScore,
                defenderCount: state.config.defenderCount,
                attackerCount: state.config.attackerCount,
                puckCount: 3
            )

        default:
            break
        }
    }

    private func handlePositionInput(playerId: String, position: CGPoint) {
        // Convert screen position to rail movement direction
        // This is a simplified version - the controller view handles the actual logic
        guard let paddle = state.getPlayerPaddle(for: playerId) else { return }

        let paddlePos = paddle.position.toPoint(config: state.config)
        let center = state.arenaCenter

        // Calculate angle from center to position
        let posAngle = atan2(position.y - center.y, position.x - center.x)
        let paddleAngle = paddle.position.angle

        // Determine direction
        var angleDiff = normalizeAngle(posAngle - paddleAngle)
        if angleDiff > .pi {
            angleDiff -= 2 * .pi
        }

        if abs(angleDiff) > 0.1 {
            let direction: RailDirection = angleDiff > 0 ? .clockwise : .counterClockwise
            handlePlayerMove(playerId: playerId, direction: direction, distance: 3)
        }
    }
}
