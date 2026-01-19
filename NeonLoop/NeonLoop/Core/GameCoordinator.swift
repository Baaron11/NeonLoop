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
    case launcher           // Game selection menu
    case home               // Legacy home (single game menu)
    case lobby              // Multiplayer lobby
    case playing            // Active game (Polygon Hockey)
    case playingTiltTable   // Tilt Table game
    case placeholderGame(GameInfo)  // Placeholder for unimplemented games
}

extension AppState {
    // Custom Equatable for GameInfo comparison
    static func == (lhs: AppState, rhs: AppState) -> Bool {
        switch (lhs, rhs) {
        case (.launcher, .launcher): return true
        case (.home, .home): return true
        case (.lobby, .lobby): return true
        case (.playing, .playing): return true
        case (.playingTiltTable, .playingTiltTable): return true
        case (.placeholderGame(let lhsGame), .placeholderGame(let rhsGame)):
            return lhsGame.id == rhsGame.id
        default: return false
        }
    }
}

// MARK: - Game Coordinator

@Observable
final class GameCoordinator {
    // MARK: - Properties

    var appState: AppState = .launcher
    var matchState: MatchState
    var aiOpponent: AIOpponent?

    // Tilt Table game coordinator (initialized when launching Tilt Table)
    var tiltTableCoordinator: TiltTableGameCoordinator?

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
        print("🏁 [GameCoordinator] init() CALLED")
        matchState = MatchState()
        aiOpponent = AIOpponent(difficulty: difficulty, config: matchState.config)
        print("🏁 [GameCoordinator]   - appState: \(appState)")
        print("🏁 [GameCoordinator]   - tiltTableCoordinator: \(tiltTableCoordinator != nil ? "EXISTS" : "NIL")")
    }

    // MARK: - Navigation

    func goToLauncher() {
        print("🔵 [GameCoordinator] goToLauncher() called")
        print("🔵 [GameCoordinator]   - Current appState: \(appState)")
        print("🔵 [GameCoordinator]   - tiltTableCoordinator before stop: \(tiltTableCoordinator != nil ? "EXISTS" : "NIL")")
        stopGameLoop()
        stopTiltTable()
        appState = .launcher
        print("🔵 [GameCoordinator]   - New appState: \(appState)")
    }

    func goToHome() {
        stopGameLoop()
        appState = .home
    }

    func goToLobby() {
        appState = .lobby
    }

    func launchPlaceholderGame(_ gameInfo: GameInfo) {
        appState = .placeholderGame(gameInfo)
    }

    func launchTiltTable() {
        print("🟢 [GameCoordinator] launchTiltTable() CALLED")
        print("🟢 [GameCoordinator]   - Current appState: \(appState)")
        print("🟢 [GameCoordinator]   - tiltTableCoordinator before: \(tiltTableCoordinator != nil ? "EXISTS" : "NIL")")

        stopGameLoop()

        // Initialize the Tilt Table game coordinator and start the game
        // This ensures the game is ready before the view appears
        print("🟢 [GameCoordinator]   - Creating TiltTableGameCoordinator...")
        tiltTableCoordinator = TiltTableGameCoordinator()
        print("🟢 [GameCoordinator]   - tiltTableCoordinator after create: \(tiltTableCoordinator != nil ? "EXISTS" : "NIL")")

        print("🟢 [GameCoordinator]   - Calling setupSinglePlayer()...")
        tiltTableCoordinator?.setupSinglePlayer()
        print("🟢 [GameCoordinator]   - Players count: \(tiltTableCoordinator?.state.players.count ?? -1)")

        print("🟢 [GameCoordinator]   - Calling startGame()...")
        tiltTableCoordinator?.startGame()
        print("🟢 [GameCoordinator]   - Phase after startGame: \(String(describing: tiltTableCoordinator?.state.phase))")
        print("🟢 [GameCoordinator]   - isRunning: \(tiltTableCoordinator?.isRunning ?? false)")

        print("🟢 [GameCoordinator]   - Setting appState to .playingTiltTable")
        appState = .playingTiltTable
        print("🟢 [GameCoordinator] launchTiltTable() COMPLETE")
    }

    func stopTiltTable() {
        print("🔴 [GameCoordinator] stopTiltTable() called")
        print("🔴 [GameCoordinator]   - tiltTableCoordinator: \(tiltTableCoordinator != nil ? "EXISTS" : "NIL")")
        tiltTableCoordinator?.stopGame()
        tiltTableCoordinator = nil
        print("🔴 [GameCoordinator]   - tiltTableCoordinator after nil: \(tiltTableCoordinator != nil ? "EXISTS" : "NIL")")
    }

    /// Initialize Tilt Table coordinator without changing app state.
    /// Called as a fallback when the view appears before the coordinator is ready.
    func initializeTiltTableIfNeeded() {
        print("🟣 [GameCoordinator] initializeTiltTableIfNeeded() called")
        print("🟣 [GameCoordinator]   - tiltTableCoordinator: \(tiltTableCoordinator != nil ? "EXISTS" : "NIL")")

        guard tiltTableCoordinator == nil else {
            print("🟣 [GameCoordinator]   - Coordinator already exists, skipping")
            return
        }

        print("🟣 [GameCoordinator]   - Creating TiltTableGameCoordinator...")
        tiltTableCoordinator = TiltTableGameCoordinator()
        tiltTableCoordinator?.setupSinglePlayer()
        tiltTableCoordinator?.startGame()
        print("🟣 [GameCoordinator]   - Coordinator created and started")
        print("🟣 [GameCoordinator]   - Phase: \(String(describing: tiltTableCoordinator?.state.phase))")
    }

    func startSinglePlayerGame(difficulty: Difficulty, mode: GameMode = .oneVsOne) {
        print("🟡 [GameCoordinator] startSinglePlayerGame() CALLED (Polygon Hockey)")
        print("🟡 [GameCoordinator]   - difficulty: \(difficulty), mode: \(mode)")
        print("🟡 [GameCoordinator]   - Current appState: \(appState)")

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
        print("🟡 [GameCoordinator]   - Setting appState to .playing")
        appState = .playing
        print("🟡 [GameCoordinator]   - Starting game loop...")
        startGameLoop()
        print("🟡 [GameCoordinator]   - displayLink: \(displayLink != nil ? "EXISTS" : "NIL")")
        print("🟡 [GameCoordinator] startSinglePlayerGame() COMPLETE")
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
