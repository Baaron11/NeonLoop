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
        print("🎱 [TiltTableGameCoordinator] init() CALLED")
        self.state = TiltTableState(holes: holes)
        print("🎱 [TiltTableGameCoordinator]   - state created, phase: \(state.phase)")
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
        print("🎱 [TiltTableGameCoordinator] setupSinglePlayer() CALLED")
        setupGame(playerCount: 1)
        // For single player, add ghost players for balance
        addGhostPlayers()
        print("🎱 [TiltTableGameCoordinator]   - Players after setup: \(state.players.count)")
        print("🎱 [TiltTableGameCoordinator]   - Player IDs: \(state.players.map { $0.id })")
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
        print("🎱 [TiltTableGameCoordinator] startGame() CALLED")
        print("🎱 [TiltTableGameCoordinator]   - Current phase before: \(state.phase)")
        state.startCountdown()
        print("🎱 [TiltTableGameCoordinator]   - Phase after startCountdown: \(state.phase)")
        startCountdownSequence()
        print("🎱 [TiltTableGameCoordinator]   - Countdown sequence started, timer scheduled")
    }

    private func startCountdownSequence() {
        print("🎱 [TiltTableGameCoordinator] startCountdownSequence() CALLED")
        countdownTimer?.invalidate()
        state.countdownValue = 3
        state.phase = .countdown(3)
        print("🎱 [TiltTableGameCoordinator]   - countdownValue: \(state.countdownValue), phase: \(state.phase)")

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                print("🎱 [TiltTableGameCoordinator] ⚠️ Timer fired but self is nil!")
                timer.invalidate()
                return
            }

            self.state.countdownValue -= 1
            print("🎱 [TiltTableGameCoordinator] Timer tick: countdownValue = \(self.state.countdownValue)")

            if self.state.countdownValue > 0 {
                self.state.phase = .countdown(self.state.countdownValue)
                print("🎱 [TiltTableGameCoordinator]   - Phase: \(self.state.phase)")
            } else if self.state.countdownValue == 0 {
                self.state.phase = .countdown(0)  // "GO!"
                print("🎱 [TiltTableGameCoordinator]   - Phase: GO!")
            } else {
                print("🎱 [TiltTableGameCoordinator]   - Countdown complete, starting game loop!")
                timer.invalidate()
                self.countdownTimer = nil
                self.state.startPlaying()
                self.startGameLoop()
                print("🎱 [TiltTableGameCoordinator]   - isRunning: \(self.isRunning)")
            }
        }
        print("🎱 [TiltTableGameCoordinator]   - Timer created: \(countdownTimer != nil ? "EXISTS" : "NIL")")
    }

    func stopGame() {
        print("🎱 [TiltTableGameCoordinator] stopGame() CALLED")
        print("🎱 [TiltTableGameCoordinator]   - isRunning before: \(isRunning)")
        stopGameLoop()
        countdownTimer?.invalidate()
        countdownTimer = nil
        isRunning = false
        print("🎱 [TiltTableGameCoordinator]   - isRunning after: \(isRunning)")
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
    @StateObject private var motionManager = TiltMotionManager()
    @State private var lastDragX: CGFloat = 0
    @State private var inputMode: TiltInputMode = .swipe

    enum TiltInputMode: String, CaseIterable {
        case swipe = "Swipe"
        case tilt = "Tilt"

        var icon: String {
            switch self {
            case .swipe: return "hand.draw"
            case .tilt: return "iphone.gen3.radiowaves.left.and.right"
            }
        }
    }

    var body: some View {
        let _ = print("🎮 [TiltTableGameView] body EVALUATED")
        let _ = print("🎮 [TiltTableGameView]   - mainCoordinator.appState: \(mainCoordinator.appState)")
        let _ = print("🎮 [TiltTableGameView]   - mainCoordinator.tiltTableCoordinator: \(mainCoordinator.tiltTableCoordinator != nil ? "EXISTS" : "NIL")")

        // Access tiltTableCoordinator DIRECTLY in body to ensure proper @Observable tracking
        // Using a computed property can sometimes break observation tracking
        let coordinator = mainCoordinator.tiltTableCoordinator

        GeometryReader { geometry in
            if let coordinator = coordinator {
                let _ = print("🎮 [TiltTableGameView]   - coordinator.state.phase: \(coordinator.state.phase)")
                let _ = print("🎮 [TiltTableGameView]   - coordinator.isRunning: \(coordinator.isRunning)")
                ZStack {
                    // Background
                    Color.black
                        .ignoresSafeArea()

                    // Grid pattern
                    TiltTableGridBackground()

                    VStack(spacing: 0) {
                        // Main game table (single view, no duplicate)
                        mainTableView(coordinator: coordinator, geometry: geometry)
                            .frame(maxHeight: geometry.size.height * 0.65)

                        Spacer(minLength: 16)

                        // Simplified control area (no mini table)
                        controlArea(coordinator: coordinator)
                            .frame(height: 200)
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

                            // Input mode toggle
                            inputModeToggle
                                .padding()
                        }
                        Spacer()
                    }

                    // Countdown overlay
                    if case .countdown(let count) = coordinator.state.phase {
                        CountdownOverlay(count: count)
                    }

                    // Ball falling animation
                    if case .ballFalling(let holeId) = coordinator.state.phase {
                        BallFallingOverlay(holeId: holeId, holes: coordinator.state.holes)
                    }

                    // Game complete overlay
                    if case .complete = coordinator.state.phase, let result = coordinator.state.result {
                        GameCompleteOverlay(result: result, onExit: handleExit)
                    }
                }
                .onAppear {
                    print("🎮 [TiltTableGameView] Main content onAppear")
                    print("🎮 [TiltTableGameView]   - coordinator.state.phase: \(coordinator.state.phase)")
                    print("🎮 [TiltTableGameView]   - coordinator.isRunning: \(coordinator.isRunning)")
                    if inputMode == .tilt {
                        motionManager.startMonitoring()
                    }
                }
                .onDisappear {
                    print("🎮 [TiltTableGameView] Main content onDisappear")
                    motionManager.stopMonitoring()
                }
                .onChange(of: inputMode) { _, newMode in
                    if newMode == .tilt {
                        motionManager.startMonitoring()
                    } else {
                        motionManager.stopMonitoring()
                    }
                }
                .onChange(of: motionManager.roll) { _, newRoll in
                    if inputMode == .tilt, coordinator.state.phase.isActive {
                        let movement = newRoll * 0.05
                        coordinator.handlePlayerMove(playerId: "player_0", deltaAngle: movement)
                    }
                }
            } else {
                // Fallback if coordinator not ready
                let _ = print("🎮 [TiltTableGameView] ⚠️ COORDINATOR IS NIL - showing fallback")
                Color.black
                    .ignoresSafeArea()
                VStack {
                    ProgressView()
                        .tint(.cyan)
                    Text("Loading Tilt Table...")
                        .foregroundStyle(.gray)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(.top, 8)
                }
                .onAppear {
                    print("🎮 [TiltTableGameView] Fallback view onAppear - coordinator still nil!")
                    print("🎮 [TiltTableGameView]   - Will initialize coordinator now...")
                    // If coordinator is nil when view appears, initialize it
                    // This handles race conditions where the view renders before
                    // the coordinator is set
                    if mainCoordinator.tiltTableCoordinator == nil {
                        mainCoordinator.initializeTiltTableIfNeeded()
                    }
                }
            }
        }
    }

    // MARK: - Main Table View

    @ViewBuilder
    private func mainTableView(coordinator: TiltTableGameCoordinator, geometry: GeometryProxy) -> some View {
        let state = coordinator.state
        let size = min(geometry.size.width, geometry.size.height * 0.65)
        let scale = size / (state.config.tableRadius * 2.5)

        ZStack {
            // Tilt shadow (shows table angle)
            TiltShadowView(tilt: state.tableTilt, config: state.config)
                .scaleEffect(scale)

            // Table surface
            TableSurfaceView(config: state.config)
                .scaleEffect(scale)

            // Holes
            ForEach(state.holes) { hole in
                HoleView(hole: hole, config: state.config, ball: state.ball)
                    .scaleEffect(scale)
            }

            // Player ring (guide line)
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                .frame(
                    width: state.config.ringRadius * 2 * scale,
                    height: state.config.ringRadius * 2 * scale
                )

            // Players
            ForEach(state.players) { player in
                PlayerAvatarView(player: player, config: state.config)
                    .scaleEffect(scale)
            }

            // Ball
            if state.phase != .countdown(3) {
                BallView(ball: state.ball, config: state.config)
                    .scaleEffect(scale)
            }
        }
        .frame(width: size, height: size)
    }

    // MARK: - Control Area

    @ViewBuilder
    private func controlArea(coordinator: TiltTableGameCoordinator) -> some View {
        let currentPlayer = coordinator.state.players.first { $0.id == "player_0" }

        VStack(spacing: 16) {
            // Instructions
            VStack(spacing: 8) {
                Text(inputMode == .swipe ? "SWIPE LEFT/RIGHT" : "TILT PHONE LEFT/RIGHT")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan)

                Text("Move around the ring to tilt the table")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.gray)
            }

            // Swipe input area
            GeometryReader { inputGeometry in
                ZStack {
                    // Background
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(white: 0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    currentPlayer?.color.opacity(0.3) ?? .cyan.opacity(0.3),
                                    lineWidth: 2
                                )
                        )

                    // Direction indicators
                    HStack {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.gray.opacity(0.3))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.gray.opacity(0.3))
                    }
                    .padding(.horizontal, 30)

                    // Center dot
                    Circle()
                        .fill(currentPlayer?.color ?? .cyan)
                        .frame(width: 20, height: 20)
                        .opacity(0.5)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard inputMode == .swipe, coordinator.state.phase.isActive else { return }

                            let deltaX = value.translation.width - lastDragX
                            lastDragX = value.translation.width

                            let angularDelta = -deltaX * 0.008
                            coordinator.handlePlayerMove(playerId: "player_0", deltaAngle: angularDelta)
                        }
                        .onEnded { _ in
                            lastDragX = 0
                        }
                )
            }
        }
    }

    // MARK: - Input Mode Toggle

    private var inputModeToggle: some View {
        Menu {
            ForEach(TiltInputMode.allCases, id: \.self) { mode in
                Button {
                    inputMode = mode
                } label: {
                    Label(mode.rawValue, systemImage: mode.icon)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: inputMode.icon)
                Text(inputMode.rawValue)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
            }
            .foregroundStyle(.cyan)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .stroke(.cyan.opacity(0.5), lineWidth: 1)
            )
        }
    }

    private func handleExit() {
        mainCoordinator.goToLauncher()
    }
}

// MARK: - Grid Background (for game view)

private struct TiltTableGridBackground: View {
    var body: some View {
        Canvas { context, size in
            let gridSize: CGFloat = 40
            let lineWidth: CGFloat = 0.5

            for x in stride(from: 0, through: size.width, by: gridSize) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(.pink.opacity(0.08)), lineWidth: lineWidth)
            }

            for y in stride(from: 0, through: size.height, by: gridSize) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(.pink.opacity(0.08)), lineWidth: lineWidth)
            }
        }
    }
}

// MARK: - Preview

#Preview("Tilt Table Game") {
    let coordinator = GameCoordinator()
    coordinator.launchTiltTable()  // This sets up the tiltTableCoordinator
    return TiltTableGameView()
        .environment(coordinator)
}

#Preview("Tilt Table - TV View Only") {
    let state = TiltTableState()
    state.setupPlayers(count: 3)
    state.phase = .playing
    state.ball.position = CGPoint(x: 50, y: -30)
    state.ball.velocity = CGVector(dx: 1, dy: 0.5)

    return TiltTableView(state: state, onExit: {})
}
