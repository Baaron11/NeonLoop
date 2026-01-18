/**
 * Game Coordinator - Main Game Orchestrator
 *
 * Manages the overall app state, game loop, and coordinates between
 * different systems (input, rendering, networking, audio).
 */

import Foundation
import SwiftUI
import Combine

// MARK: - App State

enum AppState: Equatable {
    case home
    case lobby
    case playing
}

// MARK: - Game Coordinator

@Observable
final class GameCoordinator: ObservableObject {
    // MARK: - Properties

    var appState: AppState = .home
    var matchState: MatchState
    var aiOpponent: AIOpponent?

    // Game loop
    private var displayLink: CADisplayLink?
    private var lastUpdateTime: CFTimeInterval = 0

    // Settings
    var isSinglePlayer: Bool = true
    var difficulty: Difficulty = .medium {
        didSet {
            aiOpponent = AIOpponent(difficulty: difficulty, config: matchState.config)
        }
    }
    var gameMode: GameMode = .oneVsOne

    // MARK: - Initialization

    init() {
        matchState = MatchState()
        aiOpponent = AIOpponent(difficulty: difficulty, config: matchState.config)
    }

    // MARK: - Navigation

    func goToHome() {
        stopGameLoop()
        appState = .home
    }

    func goToLobby() {
        appState = .lobby
    }

    func startSinglePlayerGame(difficulty: Difficulty, mode: GameMode = .oneVsOne) {
        self.difficulty = difficulty
        self.gameMode = mode
        self.isSinglePlayer = true

        matchState = MatchState(
            config: mode == .twoVsTwo ? .doubles : .default,
            difficulty: difficulty,
            gameMode: mode
        )
        aiOpponent = AIOpponent(difficulty: difficulty, config: matchState.config)

        matchState.startGame()
        appState = .playing
        startGameLoop()
    }

    func startMultiplayerGame(mode: GameMode = .oneVsOne) {
        self.gameMode = mode
        self.isSinglePlayer = false

        matchState = MatchState(
            config: mode == .twoVsTwo ? .doubles : .default,
            difficulty: .medium,
            gameMode: mode
        )

        matchState.startGame()
        appState = .playing
        startGameLoop()
    }

    // MARK: - Game Loop

    func startGameLoop() {
        stopGameLoop()

        displayLink = CADisplayLink(target: self, selector: #selector(gameLoopTick))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 60)
        displayLink?.add(to: .main, forMode: .common)
        lastUpdateTime = CACurrentMediaTime()
    }

    func stopGameLoop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func gameLoopTick(_ link: CADisplayLink) {
        let currentTime = link.timestamp
        let deltaTime = currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        // Normalize delta time (1.0 = ~16.67ms at 60fps)
        let normalizedDelta = CGFloat(deltaTime) * 60.0

        // Calculate AI move if single player
        var aiPosition: Position? = nil
        if isSinglePlayer, let ai = aiOpponent {
            aiPosition = ai.calculateMove(
                puck: matchState.puck,
                currentPaddle: matchState.opponentPaddle,
                currentTime: currentTime
            )
        }

        // Update game state
        matchState.update(
            deltaTime: normalizedDelta,
            realDeltaTime: deltaTime,
            aiPosition: aiPosition
        )

        // Handle events (audio, haptics, etc.)
        for event in matchState.pendingEvents {
            handleGameEvent(event)
        }
    }

    private func handleGameEvent(_ event: GameEvent) {
        switch event.type {
        case .paddleHit:
            // Play hit sound, trigger haptics
            let intensity = event.intensity ?? 0.5
            HapticManager.shared.impact(intensity: intensity)

        case .wallHit:
            HapticManager.shared.impact(intensity: 0.3)

        case .goalScored:
            HapticManager.shared.notification(type: event.scorer == .player ? .success : .warning)

        case .gameEnded:
            stopGameLoop()
            HapticManager.shared.notification(type: event.winner == .player ? .success : .error)

        case .puckBoosted:
            HapticManager.shared.impact(intensity: 0.6)

        default:
            break
        }
    }

    // MARK: - Input

    func handlePaddleMove(to position: Position) {
        matchState.movePlayerPaddle(to: position)
    }

    func handlePause() {
        matchState.togglePause()
    }

    func handleRematch() {
        matchState.startGame()
        startGameLoop()
    }
}

// MARK: - Haptic Manager

final class HapticManager {
    static let shared = HapticManager()

    private init() {}

    func impact(intensity: CGFloat) {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: intensity > 0.6 ? .heavy : intensity > 0.3 ? .medium : .light)
        generator.impactOccurred(intensity: intensity)
        #endif
    }

    func notification(type: NotificationType) {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        switch type {
        case .success:
            generator.notificationOccurred(.success)
        case .warning:
            generator.notificationOccurred(.warning)
        case .error:
            generator.notificationOccurred(.error)
        }
        #endif
    }

    enum NotificationType {
        case success, warning, error
    }
}
