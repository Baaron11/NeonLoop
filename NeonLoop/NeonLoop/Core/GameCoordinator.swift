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
    case playingBilliardDodge   // Billiard Dodge game
    case playingHordeDefense    // Horde Defense game
    case playingFoosball        // Foosball game
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
        case (.playingBilliardDodge, .playingBilliardDodge): return true
        case (.playingHordeDefense, .playingHordeDefense): return true
        case (.playingFoosball, .playingFoosball): return true
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

    // Billiard Dodge game coordinator (initialized when launching Billiard Dodge)
    var billiardDodgeCoordinator: BilliardDodgeGameCoordinator?

    // Horde Defense game coordinator (initialized when launching Horde Defense)
    var hordeDefenseCoordinator: HordeDefenseGameCoordinator?

    // Foosball game coordinator (initialized when launching Foosball)
    var foosballCoordinator: FoosballGameCoordinator?

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
        print("🔵 [GameCoordinator]   - billiardDodgeCoordinator before stop: \(billiardDodgeCoordinator != nil ? "EXISTS" : "NIL")")
        print("🔵 [GameCoordinator]   - hordeDefenseCoordinator before stop: \(hordeDefenseCoordinator != nil ? "EXISTS" : "NIL")")
        print("🔵 [GameCoordinator]   - foosballCoordinator before stop: \(foosballCoordinator != nil ? "EXISTS" : "NIL")")
        stopGameLoop()
        stopTiltTable()
        stopBilliardDodge()
        stopHordeDefense()
        stopFoosball()
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

    // MARK: - Billiard Dodge

    func launchBilliardDodge() {
        print("🟣 [GameCoordinator] launchBilliardDodge() CALLED")
        print("🟣 [GameCoordinator]   - Current appState: \(appState)")
        print("🟣 [GameCoordinator]   - billiardDodgeCoordinator before: \(billiardDodgeCoordinator != nil ? "EXISTS" : "NIL")")

        stopGameLoop()

        // Initialize the Billiard Dodge game coordinator and start the game
        // CRITICAL: Complete all initialization BEFORE changing app state
        // This follows the working pattern from Polygon Hockey to avoid race conditions
        print("🟣 [GameCoordinator]   - Creating BilliardDodgeGameCoordinator...")
        billiardDodgeCoordinator = BilliardDodgeGameCoordinator()
        print("🟣 [GameCoordinator]   - billiardDodgeCoordinator after create: \(billiardDodgeCoordinator != nil ? "EXISTS" : "NIL")")

        print("🟣 [GameCoordinator]   - Calling setupSinglePlayer()...")
        billiardDodgeCoordinator?.setupSinglePlayer()
        print("🟣 [GameCoordinator]   - Players count: \(billiardDodgeCoordinator?.state.balls.count ?? -1)")

        print("🟣 [GameCoordinator]   - Calling startGame()...")
        billiardDodgeCoordinator?.startGame()
        print("🟣 [GameCoordinator]   - Phase after startGame: \(String(describing: billiardDodgeCoordinator?.state.phase))")
        print("🟣 [GameCoordinator]   - isRunning: \(billiardDodgeCoordinator?.isRunning ?? false)")

        print("🟣 [GameCoordinator]   - Setting appState to .playingBilliardDodge")
        appState = .playingBilliardDodge
        print("🟣 [GameCoordinator] launchBilliardDodge() COMPLETE")
    }

    func stopBilliardDodge() {
        print("🔴 [GameCoordinator] stopBilliardDodge() called")
        print("🔴 [GameCoordinator]   - billiardDodgeCoordinator: \(billiardDodgeCoordinator != nil ? "EXISTS" : "NIL")")
        billiardDodgeCoordinator?.stopGame()
        billiardDodgeCoordinator = nil
        print("🔴 [GameCoordinator]   - billiardDodgeCoordinator after nil: \(billiardDodgeCoordinator != nil ? "EXISTS" : "NIL")")
    }

    /// Initialize Billiard Dodge coordinator without changing app state.
    /// Called as a fallback when the view appears before the coordinator is ready.
    func initializeBilliardDodgeIfNeeded() {
        print("🟣 [GameCoordinator] initializeBilliardDodgeIfNeeded() called")
        print("🟣 [GameCoordinator]   - billiardDodgeCoordinator: \(billiardDodgeCoordinator != nil ? "EXISTS" : "NIL")")

        guard billiardDodgeCoordinator == nil else {
            print("🟣 [GameCoordinator]   - Coordinator already exists, skipping")
            return
        }

        print("🟣 [GameCoordinator]   - Creating BilliardDodgeGameCoordinator...")
        billiardDodgeCoordinator = BilliardDodgeGameCoordinator()
        billiardDodgeCoordinator?.setupSinglePlayer()
        billiardDodgeCoordinator?.startGame()
        print("🟣 [GameCoordinator]   - Coordinator created and started")
        print("🟣 [GameCoordinator]   - Phase: \(String(describing: billiardDodgeCoordinator?.state.phase))")
    }

    // MARK: - Horde Defense

    func launchHordeDefense() {
        print("🟢 [GameCoordinator] launchHordeDefense() CALLED")
        print("🟢 [GameCoordinator]   - Current appState: \(appState)")
        print("🟢 [GameCoordinator]   - hordeDefenseCoordinator before: \(hordeDefenseCoordinator != nil ? "EXISTS" : "NIL")")

        stopGameLoop()

        // Initialize the Horde Defense game coordinator
        // CRITICAL: Complete all initialization BEFORE changing app state
        // This follows the working pattern from Polygon Hockey to avoid race conditions
        print("🟢 [GameCoordinator]   - Creating HordeDefenseGameCoordinator...")
        hordeDefenseCoordinator = HordeDefenseGameCoordinator()
        print("🟢 [GameCoordinator]   - hordeDefenseCoordinator after create: \(hordeDefenseCoordinator != nil ? "EXISTS" : "NIL")")

        print("🟢 [GameCoordinator]   - Calling setupSinglePlayer()...")
        hordeDefenseCoordinator?.setupSinglePlayer()

        // Note: We don't start the game immediately - the settings view will show first
        // The game starts when the player presses "Start Game" in settings
        print("🟢 [GameCoordinator]   - Phase: \(String(describing: hordeDefenseCoordinator?.state.phase))")

        print("🟢 [GameCoordinator]   - Setting appState to .playingHordeDefense")
        appState = .playingHordeDefense
        print("🟢 [GameCoordinator] launchHordeDefense() COMPLETE")
    }

    func stopHordeDefense() {
        print("🔴 [GameCoordinator] stopHordeDefense() called")
        print("🔴 [GameCoordinator]   - hordeDefenseCoordinator: \(hordeDefenseCoordinator != nil ? "EXISTS" : "NIL")")
        hordeDefenseCoordinator?.stopGame()
        hordeDefenseCoordinator = nil
        print("🔴 [GameCoordinator]   - hordeDefenseCoordinator after nil: \(hordeDefenseCoordinator != nil ? "EXISTS" : "NIL")")
    }

    /// Initialize Horde Defense coordinator without changing app state.
    /// Called as a fallback when the view appears before the coordinator is ready.
    func initializeHordeDefenseIfNeeded() {
        print("🟣 [GameCoordinator] initializeHordeDefenseIfNeeded() called")
        print("🟣 [GameCoordinator]   - hordeDefenseCoordinator: \(hordeDefenseCoordinator != nil ? "EXISTS" : "NIL")")

        guard hordeDefenseCoordinator == nil else {
            print("🟣 [GameCoordinator]   - Coordinator already exists, skipping")
            return
        }

        print("🟣 [GameCoordinator]   - Creating HordeDefenseGameCoordinator...")
        hordeDefenseCoordinator = HordeDefenseGameCoordinator()
        hordeDefenseCoordinator?.setupSinglePlayer()
        print("🟣 [GameCoordinator]   - Coordinator created")
        print("🟣 [GameCoordinator]   - Phase: \(String(describing: hordeDefenseCoordinator?.state.phase))")
    }

    // MARK: - Foosball

    func launchFoosball() {
        print("⚽ [GameCoordinator] launchFoosball() CALLED")
        print("⚽ [GameCoordinator]   - Current appState: \(appState)")
        print("⚽ [GameCoordinator]   - foosballCoordinator before: \(foosballCoordinator != nil ? "EXISTS" : "NIL")")

        stopGameLoop()

        // Initialize the Foosball game coordinator
        // CRITICAL: Complete all initialization BEFORE changing app state
        // This follows the working pattern from Polygon Hockey to avoid race conditions
        print("⚽ [GameCoordinator]   - Creating FoosballGameCoordinator...")
        foosballCoordinator = FoosballGameCoordinator()
        print("⚽ [GameCoordinator]   - foosballCoordinator after create: \(foosballCoordinator != nil ? "EXISTS" : "NIL")")

        print("⚽ [GameCoordinator]   - Calling setupSinglePlayer()...")
        foosballCoordinator?.setupSinglePlayer()

        // Note: We don't start the game immediately - the settings view will show first
        // The game starts when the player presses "Start Game" in settings
        print("⚽ [GameCoordinator]   - Phase: \(String(describing: foosballCoordinator?.state.phase))")

        print("⚽ [GameCoordinator]   - Setting appState to .playingFoosball")
        appState = .playingFoosball
        print("⚽ [GameCoordinator] launchFoosball() COMPLETE")
    }

    func stopFoosball() {
        print("🔴 [GameCoordinator] stopFoosball() called")
        print("🔴 [GameCoordinator]   - foosballCoordinator: \(foosballCoordinator != nil ? "EXISTS" : "NIL")")
        foosballCoordinator?.stopGame()
        foosballCoordinator = nil
        print("🔴 [GameCoordinator]   - foosballCoordinator after nil: \(foosballCoordinator != nil ? "EXISTS" : "NIL")")
    }

    /// Initialize Foosball coordinator without changing app state.
    /// Called as a fallback when the view appears before the coordinator is ready.
    func initializeFoosballIfNeeded() {
        print("🟣 [GameCoordinator] initializeFoosballIfNeeded() called")
        print("🟣 [GameCoordinator]   - foosballCoordinator: \(foosballCoordinator != nil ? "EXISTS" : "NIL")")

        guard foosballCoordinator == nil else {
            print("🟣 [GameCoordinator]   - Coordinator already exists, skipping")
            return
        }

        print("🟣 [GameCoordinator]   - Creating FoosballGameCoordinator...")
        foosballCoordinator = FoosballGameCoordinator()
        foosballCoordinator?.setupSinglePlayer()
        print("🟣 [GameCoordinator]   - Coordinator created")
        print("🟣 [GameCoordinator]   - Phase: \(String(describing: foosballCoordinator?.state.phase))")
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
