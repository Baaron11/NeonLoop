/**
 * Foosball Game - Main Game Controller
 *
 * Implements the NeonLoopGame protocol and manages the complete game lifecycle.
 * Handles the game loop, countdown sequence, physics updates, AI, and result detection.
 */

import Foundation
import SwiftUI
import QuartzCore

// MARK: - Foosball Game Coordinator

@Observable
final class FoosballGameCoordinator {
    var state: FoosballState
    var isRunning: Bool = false

    private var displayLink: CADisplayLink?
    private var lastUpdateTime: CFTimeInterval = 0
    private var countdownTimer: Timer?
    private var goalCelebrationTimer: Timer?

    init() {
        print("⚽ [FoosballGameCoordinator] init() CALLED")
        self.state = FoosballState()
        print("⚽ [FoosballGameCoordinator]   - state created, phase: \(state.phase)")
    }

    // MARK: - Game Setup

    func setupGame(playerCount: Int, matchFormat: MatchFormat, difficulty: FoosballDifficulty) {
        state = FoosballState()
        state.playerCount = playerCount
        state.matchFormat = matchFormat
        state.difficulty = difficulty

        if case .timed(let duration) = matchFormat {
            state.timeRemaining = duration
        }

        state.assignRodsToPlayers(playerCount: playerCount)
    }

    func setupSinglePlayer() {
        print("⚽ [FoosballGameCoordinator] setupSinglePlayer() CALLED")
        setupGame(playerCount: 1, matchFormat: .firstTo(5), difficulty: .medium)
        print("⚽ [FoosballGameCoordinator]   - Player count: \(state.playerCount)")
        print("⚽ [FoosballGameCoordinator]   - Match format: \(state.matchFormat)")
    }

    // MARK: - Game Control

    func startGame() {
        print("⚽ [FoosballGameCoordinator] startGame() CALLED")
        print("⚽ [FoosballGameCoordinator]   - Current phase before: \(state.phase)")

        // Reset scores if not already in a game
        if case .settings = state.phase {
            state.playerScore = 0
            state.aiScore = 0
            if case .timed(let duration) = state.matchFormat {
                state.timeRemaining = duration
            }
        }

        state.startCountdown()
        print("⚽ [FoosballGameCoordinator]   - Phase after startCountdown: \(state.phase)")
        startCountdownSequence()
        print("⚽ [FoosballGameCoordinator]   - Countdown sequence started, timer scheduled")
    }

    private func startCountdownSequence() {
        print("⚽ [FoosballGameCoordinator] startCountdownSequence() CALLED")
        countdownTimer?.invalidate()
        state.countdownValue = 3
        state.phase = .countdown(3)
        print("⚽ [FoosballGameCoordinator]   - countdownValue: \(state.countdownValue), phase: \(state.phase)")

        // Use .common mode so timer fires even during UI animations
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                print("⚽ [FoosballGameCoordinator] Timer fired but self is nil!")
                timer.invalidate()
                return
            }

            self.state.countdownValue -= 1
            print("⚽ [FoosballGameCoordinator] Timer tick: countdownValue = \(self.state.countdownValue)")

            if self.state.countdownValue > 0 {
                self.state.phase = .countdown(self.state.countdownValue)
                print("⚽ [FoosballGameCoordinator]   - Phase: \(self.state.phase)")
            } else if self.state.countdownValue == 0 {
                self.state.phase = .countdown(0)  // "GO!"
                print("⚽ [FoosballGameCoordinator]   - Phase: GO!")
            } else {
                print("⚽ [FoosballGameCoordinator]   - Countdown complete, starting game loop!")
                timer.invalidate()
                self.countdownTimer = nil
                self.state.startPlaying()
                self.startGameLoop()
                print("⚽ [FoosballGameCoordinator]   - isRunning: \(self.isRunning)")
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        countdownTimer = timer
        print("⚽ [FoosballGameCoordinator]   - Timer created: \(countdownTimer != nil ? "EXISTS" : "NIL")")
    }

    func stopGame() {
        print("⚽ [FoosballGameCoordinator] stopGame() CALLED")
        print("⚽ [FoosballGameCoordinator]   - isRunning before: \(isRunning)")
        stopGameLoop()
        countdownTimer?.invalidate()
        countdownTimer = nil
        goalCelebrationTimer?.invalidate()
        goalCelebrationTimer = nil
        isRunning = false
        print("⚽ [FoosballGameCoordinator]   - isRunning after: \(isRunning)")
    }

    func restartGame() {
        stopGame()
        state.resetGame()
        startGame()
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

        // Update AI
        FoosballAI.update(state: state, deltaTime: normalizedDelta, currentTime: currentTime)

        // Update physics
        FoosballPhysics.step(state: state, deltaTime: normalizedDelta, currentTime: currentTime)

        // Check for phase changes
        handlePhaseChanges()
    }

    private func handlePhaseChanges() {
        switch state.phase {
        case .goalScored(let playerScored):
            // Pause for celebration, then reset ball
            if goalCelebrationTimer == nil {
                stopGameLoop()
                goalCelebrationTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                    guard let self = self else { return }
                    self.goalCelebrationTimer = nil

                    // Check if game is over
                    if self.state.isGameOver {
                        return
                    }

                    // Reset ball and continue
                    self.state.resetBall(towardPlayer: !playerScored)
                    self.state.phase = .playing
                    self.startGameLoop()
                }
            }

        case .gameOver:
            stopGameLoop()

        default:
            break
        }
    }

    // MARK: - Player Input

    func handleRodMove(playerId: String, xOffset: CGFloat) {
        guard state.phase.isActive else { return }

        // Find all rods controlled by this player
        let controlledRods = state.rodsForPlayer(playerId)
        for rod in controlledRods {
            state.moveRod(rodId: rod.id, xOffset: xOffset)
        }
    }

    func handleKick(playerId: String, type: KickType) {
        guard state.phase.isActive else { return }

        // Find all rods controlled by this player and kick them
        let controlledRods = state.rodsForPlayer(playerId)
        for rod in controlledRods {
            state.kickRod(rodId: rod.id, type: type)
        }
    }

    // MARK: - Settings Updates

    func setPlayerCount(_ count: Int) {
        state.playerCount = count
        state.assignRodsToPlayers(playerCount: count)
    }

    func setMatchFormat(_ format: MatchFormat) {
        state.matchFormat = format
        if case .timed(let duration) = format {
            state.timeRemaining = duration
        } else {
            state.timeRemaining = nil
        }
    }

    func setDifficulty(_ difficulty: FoosballDifficulty) {
        state.difficulty = difficulty
    }

    // MARK: - Computed Properties

    var isGameOver: Bool {
        state.isGameOver
    }

    var playerWon: Bool? {
        state.playerWon
    }
}

// MARK: - NeonLoopGame Protocol Conformance

extension FoosballGameCoordinator: NeonLoopGame {
    var gameId: String { "foosball" }
    var gameName: String { "Foosball" }
    var isImplemented: Bool { true }
    var minPlayers: Int { 1 }
    var maxPlayers: Int { 4 }
    var inputType: GameInputType { .swipeAndTap }

    func setup(players: [Player], modifiers: [GameModifier]) {
        state = FoosballState()
        state.assignRodsToPlayers(playerCount: max(1, players.count))

        // Apply any modifiers
        for modifier in modifiers {
            applyModifier(modifier)
        }
    }

    func handleInput(playerId: String, input: GameInput) {
        switch input {
        case .swipe(let delta):
            // Convert swipe delta to rod position
            let currentRods = state.rodsForPlayer(playerId)
            if let firstRod = currentRods.first {
                let newOffset = firstRod.xOffset + delta * 0.01
                handleRodMove(playerId: playerId, xOffset: newOffset)
            }

        case .doubleTap:
            handleKick(playerId: playerId, type: .forward)

        default:
            break
        }
    }

    func update(deltaTime: CGFloat) {
        // Physics update is handled by the display link
        // This is called for manual updates if needed
        let currentTime = CACurrentMediaTime()
        FoosballAI.update(state: state, deltaTime: deltaTime, currentTime: currentTime)
        FoosballPhysics.step(state: state, deltaTime: deltaTime, currentTime: currentTime)
    }

    var winner: Player? {
        // Foosball is cooperative against AI, so there's no individual winner
        // Return nil and use isGameOver/playerWon instead
        nil
    }

    private func applyModifier(_ modifier: GameModifier) {
        switch modifier.id {
        case "speed_boost":
            // Increase ball speed
            state.config = FoosballConfig(
                tableWidth: state.config.tableWidth,
                tableHeight: state.config.tableHeight,
                goalWidth: state.config.goalWidth,
                goalDepth: state.config.goalDepth,
                rodSlideRange: state.config.rodSlideRange,
                manWidth: state.config.manWidth,
                manHeight: state.config.manHeight,
                ballRadius: state.config.ballRadius,
                kickDuration: state.config.kickDuration,
                kickPowerMin: state.config.kickPowerMin * 1.3,
                kickPowerMax: state.config.kickPowerMax * 1.3,
                ballFriction: state.config.ballFriction,
                kickCooldown: state.config.kickCooldown,
                rodBarHeight: state.config.rodBarHeight
            )
        default:
            break
        }
    }
}
