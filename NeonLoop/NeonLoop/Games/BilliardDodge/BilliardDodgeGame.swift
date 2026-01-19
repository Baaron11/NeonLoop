/**
 * BilliardDodge Game - Main Game Controller
 *
 * Implements the NeonLoopGame protocol and manages the complete game lifecycle.
 * Handles the countdown sequence, CPU shot calculation, physics updates,
 * and round/game result detection.
 *
 * Game Flow:
 * 1. CPU calculates and shows shot preview
 * 2. 5-second countdown starts
 * 3. Players set escape vectors on their phones
 * 4. Countdown hits 0 - all balls move simultaneously
 * 5. Physics resolves (collisions, bounces, pockets)
 * 6. Check for pocketed players (eliminated)
 * 7. If players remain and rounds left: next round
 * 8. Win: Survive all rounds. Lose: All players pocketed.
 */

import Foundation
import SwiftUI
import QuartzCore

// MARK: - BilliardDodge Game Coordinator

@Observable
final class BilliardDodgeGameCoordinator {
    var state: BilliardDodgeState
    var isRunning: Bool = false

    private var displayLink: CADisplayLink?
    private var lastUpdateTime: CFTimeInterval = 0
    private var countdownTimer: Timer?
    private var roundResultTimer: Timer?

    init() {
        self.state = BilliardDodgeState()
    }

    // MARK: - Game Setup

    func setupGame(playerCount: Int) {
        state = BilliardDodgeState(playerCount: playerCount)
        state.setupPlayers(count: playerCount)
    }

    func setupSinglePlayer() {
        setupGame(playerCount: 1)
    }

    // MARK: - Game Control

    func startGame() {
        state.currentRound = 1
        startRound()
    }

    func startRound() {
        // Calculate CPU shot for this round
        let cpuShot = BilliardDodgeCPU.calculateShot(state: state)
        state.cpuShot = cpuShot

        // Start the countdown
        state.startRound()
        startCountdown()
    }

    private func startCountdown() {
        countdownTimer?.invalidate()
        state.countdownValue = state.config.countdownDuration
        state.phase = .countdown(remaining: state.countdownValue)

        // Use a high-frequency timer for smooth countdown display
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            self.state.countdownValue -= 0.05

            if self.state.countdownValue > 0 {
                self.state.phase = .countdown(remaining: self.state.countdownValue)
            } else {
                timer.invalidate()
                self.countdownTimer = nil
                self.executeRound()
            }
        }
    }

    private func executeRound() {
        state.executeRound()
        startGameLoop()
    }

    func stopGame() {
        stopGameLoop()
        countdownTimer?.invalidate()
        countdownTimer = nil
        roundResultTimer?.invalidate()
        roundResultTimer = nil
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
        BilliardDodgePhysics.step(state: state, deltaTime: normalizedDelta)

        // Check if all balls have stopped
        if state.allBallsStopped {
            stopGameLoop()
            evaluateRoundResult()
        }
    }

    // MARK: - Round Evaluation

    private func evaluateRoundResult() {
        // Check for eliminated players this round
        let newlyEliminated = state.balls.filter { $0.isPocketed && !state.eliminatedPlayers.contains($0.playerId ?? "") }

        var message: String

        if state.cueBall.isPocketed {
            // Scratch - cue ball pocketed, no player elimination
            message = "SCRATCH!"
        } else if !newlyEliminated.isEmpty {
            let names = newlyEliminated.compactMap { $0.playerId }.joined(separator: ", ")
            if newlyEliminated.count == 1 {
                message = "\(newlyEliminated[0].displayLabel) POCKETED!"
            } else {
                message = "\(newlyEliminated.count) PLAYERS POCKETED!"
            }
        } else {
            message = "SAFE!"
        }

        // Mark newly eliminated players
        for ball in newlyEliminated {
            if let playerId = ball.playerId {
                state.eliminatedPlayers.insert(playerId)
            }
        }

        // Show result
        state.showRoundResult(message: message)

        // Schedule next action
        roundResultTimer?.invalidate()
        roundResultTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.proceedAfterResult()
        }
    }

    private func proceedAfterResult() {
        // Check game over conditions
        if state.allPlayersEliminated {
            // All players eliminated - they lose
            state.endGame(won: false)
            return
        }

        if state.currentRound >= state.totalRounds {
            // Survived all rounds - they win!
            state.endGame(won: true)
            return
        }

        // Continue to next round
        state.currentRound += 1

        // Reset pocketed balls that aren't eliminated (only cue ball)
        state.cueBall.isPocketed = false
        state.cueBall.position = CGPoint(x: state.config.tableWidth * 0.25, y: state.config.tableHeight / 2)
        state.cueBall.velocity = .zero

        // Reset player balls velocities
        for i in state.balls.indices {
            state.balls[i].velocity = .zero
            state.balls[i].isPocketed = false
        }

        startRound()
    }

    // MARK: - Player Input

    func handlePlayerMove(playerId: String, angle: CGFloat, force: CGFloat) {
        state.setPlayerMove(playerId: playerId, angle: angle, force: force)
    }

    func lockPlayerMove(playerId: String) {
        state.lockPlayerMove(playerId: playerId)
    }

    func unlockPlayerMove(playerId: String) {
        state.unlockPlayerMove(playerId: playerId)
    }

    // MARK: - State Queries

    var isGameOver: Bool {
        switch state.phase {
        case .gameOver: return true
        default: return false
        }
    }

    var didWin: Bool {
        switch state.phase {
        case .gameOver(let won): return won
        default: return false
        }
    }
}

// MARK: - NeonLoopGame Protocol Conformance

extension BilliardDodgeGameCoordinator: NeonLoopGame {
    var gameId: String { "billiard_dodge" }
    var gameName: String { "Billiard Dodge" }
    var isImplemented: Bool { true }
    var minPlayers: Int { 1 }
    var maxPlayers: Int { 4 }
    var inputType: GameInputType { .vector }

    func setup(players: [Player], modifiers: [GameModifier]) {
        state = BilliardDodgeState(playerCount: players.count)
        state.setupPlayers(count: players.count)

        // Apply any modifiers
        for modifier in modifiers {
            applyModifier(modifier)
        }
    }

    func handleInput(playerId: String, input: GameInput) {
        switch input {
        case .vector(let angle, let force):
            handlePlayerMove(playerId: playerId, angle: angle, force: force)

        default:
            break
        }
    }

    func update(deltaTime: CGFloat) {
        // Physics update is handled by the display link
        // This is called for manual updates if needed
        BilliardDodgePhysics.step(state: state, deltaTime: deltaTime)
    }

    var winner: Player? {
        // Cooperative game - no individual winner
        nil
    }

    private func applyModifier(_ modifier: GameModifier) {
        // Future: Apply game modifiers
        switch modifier.id {
        case "speed_boost":
            state.config = BilliardDodgeConfig(
                tableWidth: state.config.tableWidth,
                tableHeight: state.config.tableHeight,
                ballRadius: state.config.ballRadius,
                pocketRadius: state.config.pocketRadius,
                maxForce: state.config.maxForce * 1.3,
                friction: state.config.friction,
                countdownDuration: state.config.countdownDuration,
                railBounce: state.config.railBounce,
                ballBounce: state.config.ballBounce
            )
        default:
            break
        }
    }
}

// MARK: - SwiftUI Integration View

/// Standalone view for playing Billiard Dodge from the launcher
struct BilliardDodgeGameView: View {
    @Environment(GameCoordinator.self) var mainCoordinator

    var body: some View {
        // Access billiardDodgeCoordinator DIRECTLY in body to ensure proper @Observable tracking
        let coordinator = mainCoordinator.billiardDodgeCoordinator

        GeometryReader { geometry in
            if let coordinator = coordinator {
                ZStack {
                    // Background
                    Color.black
                        .ignoresSafeArea()

                    // Grid pattern
                    BilliardDodgeGridBackground()

                    VStack(spacing: 0) {
                        // Header with round info
                        BilliardDodgeHeader(state: coordinator.state)
                            .padding(.top, 16)
                            .padding(.horizontal, 20)

                        Spacer()

                        // Main table view
                        BilliardDodgeTableView(state: coordinator.state)
                            .frame(maxHeight: geometry.size.height * 0.45)
                            .padding(.horizontal, 20)

                        Spacer()

                        // Controller area (radial input)
                        BilliardDodgeControllerArea(
                            coordinator: coordinator,
                            playerId: "player_0"
                        )
                        .frame(height: 280)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }

                    // Exit button overlay
                    VStack {
                        HStack {
                            Button(action: handleExit) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(.gray)
                            }
                            .padding()
                            Spacer()
                        }
                        Spacer()
                    }

                    // Countdown overlay
                    if case .countdown(let remaining) = coordinator.state.phase {
                        BilliardDodgeCountdownOverlay(remaining: remaining)
                    }

                    // Round result overlay
                    if case .roundResult(let message) = coordinator.state.phase {
                        BilliardDodgeResultOverlay(message: message)
                    }

                    // Game over overlay
                    if case .gameOver(let won) = coordinator.state.phase {
                        BilliardDodgeGameOverOverlay(won: won, state: coordinator.state, onExit: handleExit)
                    }
                }
            } else {
                // Fallback if coordinator not ready
                Color.black
                    .ignoresSafeArea()
                VStack {
                    ProgressView()
                        .tint(.purple)
                    Text("Loading Billiard Dodge...")
                        .foregroundStyle(.gray)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(.top, 8)
                }
                .onAppear {
                    // If coordinator is nil when view appears, initialize it
                    if mainCoordinator.billiardDodgeCoordinator == nil {
                        mainCoordinator.initializeBilliardDodgeIfNeeded()
                    }
                }
            }
        }
    }

    private func handleExit() {
        mainCoordinator.goToLauncher()
    }
}

// MARK: - Grid Background

private struct BilliardDodgeGridBackground: View {
    var body: some View {
        Canvas { context, size in
            let gridSize: CGFloat = 40
            let lineWidth: CGFloat = 0.5

            for x in stride(from: 0, through: size.width, by: gridSize) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(.purple.opacity(0.08)), lineWidth: lineWidth)
            }

            for y in stride(from: 0, through: size.height, by: gridSize) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(.purple.opacity(0.08)), lineWidth: lineWidth)
            }
        }
    }
}

// MARK: - Preview

#Preview("Billiard Dodge Game") {
    let coordinator = GameCoordinator()
    coordinator.launchBilliardDodge()
    return BilliardDodgeGameView()
        .environment(coordinator)
}
