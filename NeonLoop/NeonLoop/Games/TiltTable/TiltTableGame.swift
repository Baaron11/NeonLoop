/**
 * TiltTable Game - Main Game Controller
 *
 * Implements the NeonLoopGame protocol and manages the complete game lifecycle.
 * Handles the game loop, countdown sequence, physics updates, and result detection.
 */

import Foundation
import SwiftUI
import QuartzCore

// MARK: - TiltTable Game Coordinator

@Observable
final class TiltTableGameCoordinator {
    var state: TiltTableState
    var isRunning: Bool = false

    private var displayLink: CADisplayLink?
    private var lastUpdateTime: CFTimeInterval = 0
    private var countdownTimer: Timer?

    init(holes: [TiltTableHole]? = nil) {
        self.state = TiltTableState(holes: holes)
    }

    // MARK: - Game Setup

    func setupGame(playerCount: Int, holes: [TiltTableHole]? = nil) {
        if let holes = holes {
            state = TiltTableState(holes: holes)
        } else {
            state = TiltTableState()
        }
        state.setupPlayers(count: max(1, playerCount))
    }

    func setupSinglePlayer() {
        setupGame(playerCount: 1)
        // For single player, add ghost players for balance
        addGhostPlayers()
    }

    private func addGhostPlayers() {
        // Add 2 ghost players on opposite sides for single player mode
        // These create a balanced starting tilt
        state.addPlayer(id: "ghost_1", name: "Ghost 1")
        state.addPlayer(id: "ghost_2", name: "Ghost 2")

        // Position ghosts opposite to player
        if state.players.count >= 3 {
            state.players[1].angle = .pi * 2 / 3
            state.players[1].targetAngle = .pi * 2 / 3
            state.players[2].angle = .pi * 4 / 3
            state.players[2].targetAngle = .pi * 4 / 3
        }
    }

    // MARK: - Game Control

    func startGame() {
        state.startCountdown()
        startCountdownSequence()
    }

    private func startCountdownSequence() {
        countdownTimer?.invalidate()
        state.countdownValue = 3
        state.phase = .countdown(3)

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            self.state.countdownValue -= 1

            if self.state.countdownValue > 0 {
                self.state.phase = .countdown(self.state.countdownValue)
            } else if self.state.countdownValue == 0 {
                self.state.phase = .countdown(0)  // "GO!"
            } else {
                timer.invalidate()
                self.countdownTimer = nil
                self.state.startPlaying()
                self.startGameLoop()
            }
        }
    }

    func stopGame() {
        stopGameLoop()
        countdownTimer?.invalidate()
        countdownTimer = nil
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
        TiltTablePhysics.step(state: state, deltaTime: normalizedDelta)

        // Check for game end conditions
        switch state.phase {
        case .ballFalling:
            // Wait a moment then complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.state.complete()
                self?.stopGameLoop()
            }

        case .complete:
            stopGameLoop()

        default:
            break
        }
    }

    // MARK: - Player Input

    func handlePlayerMove(playerId: String, deltaAngle: CGFloat) {
        guard state.phase.isActive else { return }
        state.movePlayer(id: playerId, deltaAngle: deltaAngle)
    }

    func handlePlayerSetAngle(playerId: String, angle: CGFloat) {
        guard state.phase.isActive else { return }
        state.setPlayerAngle(id: playerId, angle: angle)
    }

    // MARK: - Result

    var selectedResult: TiltTableHole? {
        state.result
    }

    var isGameOver: Bool {
        state.isGameOver
    }
}

// MARK: - NeonLoopGame Protocol Conformance

extension TiltTableGameCoordinator: NeonLoopGame {
    var gameId: String { "tilt_table" }
    var gameName: String { "Tilt Table" }
    var isImplemented: Bool { true }
    var minPlayers: Int { 1 }
    var maxPlayers: Int { 6 }
    var inputType: GameInputType { .position }

    func setup(players: [Player], modifiers: [GameModifier]) {
        state = TiltTableState()

        for player in players {
            state.addPlayer(id: player.id, name: player.name)
        }

        // Apply any modifiers
        for modifier in modifiers {
            applyModifier(modifier)
        }
    }

    func handleInput(playerId: String, input: GameInput) {
        switch input {
        case .position(let point):
            // Convert position to angle around the ring
            let angle = atan2(point.y, point.x)
            handlePlayerSetAngle(playerId: playerId, angle: angle)

        case .tilt(let x, _):
            // Use horizontal tilt as angular movement
            let deltaAngle = x * 0.1
            handlePlayerMove(playerId: playerId, deltaAngle: deltaAngle)

        default:
            break
        }
    }

    func update(deltaTime: CGFloat) {
        // Physics update is handled by the display link
        // This is called for manual updates if needed
        TiltTablePhysics.step(state: state, deltaTime: deltaTime)
    }

    var winner: Player? {
        // Tilt Table doesn't have a traditional winner
        // It returns the selected hole as the result
        nil
    }

    private func applyModifier(_ modifier: GameModifier) {
        // Future: Apply game modifiers
        // e.g., faster ball, smaller holes, etc.
        switch modifier.id {
        case "speed_boost":
            state.config = TiltTableConfig(
                tableRadius: state.config.tableRadius,
                ballRadius: state.config.ballRadius,
                playerAvatarRadius: state.config.playerAvatarRadius,
                holeRadius: state.config.holeRadius,
                holeCaptureRadius: state.config.holeCaptureRadius,
                gravity: state.config.gravity * 1.5,
                friction: state.config.friction,
                maxTilt: state.config.maxTilt,
                maxBallSpeed: state.config.maxBallSpeed * 1.3,
                playerMoveSpeed: state.config.playerMoveSpeed,
                ringRadius: state.config.ringRadius
            )
        default:
            break
        }
    }
}

// MARK: - SwiftUI Integration View

/// Standalone view for playing Tilt Table from the launcher
struct TiltTableGameView: View {
    @Environment(GameCoordinator.self) var mainCoordinator
    @State private var gameCoordinator = TiltTableGameCoordinator()
    @State private var hasStarted = false

    var body: some View {
        ZStack {
            // Main game view (TV display)
            TiltTableView(
                state: gameCoordinator.state,
                onExit: handleExit
            )

            // Controller overlay for single-player testing
            // In multiplayer, this would be on separate devices
            VStack {
                Spacer()

                TiltTableControllerView(
                    state: gameCoordinator.state,
                    playerId: "player_0",
                    onMove: { delta in
                        gameCoordinator.handlePlayerMove(playerId: "player_0", deltaAngle: delta)
                    },
                    onExit: handleExit
                )
                .frame(height: 400)
                .background(Color.black.opacity(0.9))
                .cornerRadius(20)
                .padding()
            }
        }
        .onAppear {
            if !hasStarted {
                gameCoordinator.setupSinglePlayer()
                gameCoordinator.startGame()
                hasStarted = true
            }
        }
        .onDisappear {
            gameCoordinator.stopGame()
        }
    }

    private func handleExit() {
        gameCoordinator.stopGame()
        mainCoordinator.goToLauncher()
    }
}

// MARK: - Preview

#Preview("Tilt Table Game") {
    TiltTableGameView()
        .environment(GameCoordinator())
}

#Preview("Tilt Table - TV View Only") {
    let state = TiltTableState()
    state.setupPlayers(count: 3)
    state.phase = .playing
    state.ball.position = CGPoint(x: 50, y: -30)
    state.ball.velocity = CGVector(dx: 1, dy: 0.5)

    return TiltTableView(state: state, onExit: {})
}

#Preview("Tilt Table - Controller Only") {
    let state = TiltTableState()
    state.setupPlayers(count: 2)
    state.phase = .playing

    return TiltTableControllerView(
        state: state,
        playerId: "player_0",
        onMove: { _ in },
        onExit: {}
    )
}
