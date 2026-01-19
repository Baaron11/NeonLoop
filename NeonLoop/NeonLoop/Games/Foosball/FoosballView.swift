/**
 * Foosball View - Main Game Display
 *
 * Renders the foosball table with neon visual style, including the table,
 * goals, rods, foosmen, and ball. Also handles overlays for countdown,
 * goals, and game over.
 */

import SwiftUI

// MARK: - Main Game View

struct FoosballGameView: View {
    @Environment(GameCoordinator.self) var mainCoordinator
    @State private var showSettings = true
    @State private var lastDragX: CGFloat = 0

    var body: some View {
        let _ = print("⚽ [FoosballGameView] body EVALUATED")
        let _ = print("⚽ [FoosballGameView]   - mainCoordinator.appState: \(mainCoordinator.appState)")
        let _ = print("⚽ [FoosballGameView]   - mainCoordinator.foosballCoordinator: \(mainCoordinator.foosballCoordinator != nil ? "EXISTS" : "NIL")")

        let coordinator = mainCoordinator.foosballCoordinator

        GeometryReader { geometry in
            if let coordinator = coordinator {
                let _ = print("⚽ [FoosballGameView]   - coordinator.state.phase: \(coordinator.state.phase)")
                let _ = print("⚽ [FoosballGameView]   - coordinator.isRunning: \(coordinator.isRunning)")

                ZStack {
                    // Background
                    Color.black
                        .ignoresSafeArea()

                    // Grid pattern
                    FoosballGridBackground()

                    if showSettings && coordinator.state.phase == .settings {
                        // Settings view
                        FoosballSettingsView(coordinator: coordinator) {
                            showSettings = false
                            coordinator.startGame()
                        }
                    } else {
                        // Main game content
                        VStack(spacing: 0) {
                            // Score header
                            scoreHeader(coordinator: coordinator)
                                .padding(.top, 20)

                            // Main game table
                            mainTableView(coordinator: coordinator, geometry: geometry)
                                .frame(maxHeight: geometry.size.height * 0.65)

                            Spacer(minLength: 16)

                            // Control area
                            controlArea(coordinator: coordinator)
                                .frame(height: 180)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 30)
                        }

                        // Exit button overlay
                        exitButton

                        // Countdown overlay
                        if case .countdown(let count) = coordinator.state.phase {
                            FoosballCountdownOverlay(count: count)
                        }

                        // Goal scored overlay
                        if case .goalScored(let playerScored) = coordinator.state.phase {
                            GoalScoredOverlay(playerScored: playerScored)
                        }

                        // Game over overlay
                        if case .gameOver(let playerWon) = coordinator.state.phase {
                            GameOverOverlay(
                                playerWon: playerWon,
                                playerScore: coordinator.state.playerScore,
                                aiScore: coordinator.state.aiScore,
                                onRematch: {
                                    coordinator.restartGame()
                                },
                                onExit: handleExit
                            )
                        }
                    }
                }
                .onAppear {
                    print("⚽ [FoosballGameView] Main content onAppear")
                }
            } else {
                // Fallback if coordinator not ready
                let _ = print("⚽ [FoosballGameView] COORDINATOR IS NIL - showing fallback")
                Color.black
                    .ignoresSafeArea()
                VStack {
                    ProgressView()
                        .tint(.yellow)
                    Text("Loading Foosball...")
                        .foregroundStyle(.gray)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(.top, 8)
                }
                .onAppear {
                    print("⚽ [FoosballGameView] Fallback view onAppear - coordinator still nil!")
                    if mainCoordinator.foosballCoordinator == nil {
                        mainCoordinator.initializeFoosballIfNeeded()
                    }
                }
            }
        }
    }

    // MARK: - Score Header

    @ViewBuilder
    private func scoreHeader(coordinator: FoosballGameCoordinator) -> some View {
        HStack(spacing: 20) {
            // Player score
            VStack(spacing: 4) {
                Text("PLAYERS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan.opacity(0.8))
                Text("\(coordinator.state.playerScore)")
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan)
                    .shadow(color: .cyan.opacity(0.8), radius: 8)
            }

            // Timer or match info
            VStack(spacing: 4) {
                if let timeDisplay = coordinator.state.timeDisplay {
                    Text("TIME")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.gray)
                    Text(timeDisplay)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                } else {
                    Text(coordinator.state.matchFormat.displayName.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.gray)
                    Text("VS")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            // AI score
            VStack(spacing: 4) {
                Text("AI")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.pink.opacity(0.8))
                Text("\(coordinator.state.aiScore)")
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundStyle(.pink)
                    .shadow(color: .pink.opacity(0.8), radius: 8)
            }
        }
        .padding(.horizontal, 30)
    }

    // MARK: - Main Table View

    @ViewBuilder
    private func mainTableView(coordinator: FoosballGameCoordinator, geometry: GeometryProxy) -> some View {
        let state = coordinator.state
        let config = state.config
        let availableHeight = geometry.size.height * 0.55
        let availableWidth = geometry.size.width - 40
        let scale = min(availableWidth / config.tableWidth, availableHeight / config.tableHeight) * 0.9

        ZStack {
            // Table surface
            FoosballTableView(config: config)
                .scaleEffect(scale)

            // Goals
            GoalAreaView(config: config, isPlayerGoal: false)  // AI goal at top
                .scaleEffect(scale)
            GoalAreaView(config: config, isPlayerGoal: true)   // Player goal at bottom
                .scaleEffect(scale)

            // AI rods (at top)
            ForEach(state.aiRods) { rod in
                RodView(rod: rod, config: config, isHighlighted: false)
                    .scaleEffect(scale)
            }

            // Player rods (at bottom)
            ForEach(state.playerRods) { rod in
                let isHighlighted = rod.controlledBy == "player_0"
                RodView(rod: rod, config: config, isHighlighted: isHighlighted)
                    .scaleEffect(scale)
            }

            // Ball
            BallView(ball: state.ball, config: config)
                .scaleEffect(scale)
        }
        .frame(width: config.tableWidth * scale, height: config.tableHeight * scale)
    }

    // MARK: - Control Area

    @ViewBuilder
    private func controlArea(coordinator: FoosballGameCoordinator) -> some View {
        let assignment = coordinator.state.assignmentForPlayer("player_0")

        VStack(spacing: 12) {
            // Rod assignment display
            if let assignment = assignment {
                Text("Your rods: \(assignment.rodNames)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan)
            }

            // Control instructions
            HStack(spacing: 30) {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.left.and.right")
                        .font(.system(size: 20))
                    Text("SLIDE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(.gray)

                VStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 20))
                    Text("KICK FWD")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(.gray)

                VStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 20))
                    Text("PULL SHOT")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(.gray)
            }

            // Swipe/gesture control area
            GeometryReader { inputGeometry in
                ZStack {
                    // Background
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(white: 0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(.cyan.opacity(0.3), lineWidth: 2)
                        )

                    // Direction indicators
                    HStack {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.gray.opacity(0.3))
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "chevron.up")
                            Image(systemName: "chevron.down")
                        }
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.gray.opacity(0.3))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.gray.opacity(0.3))
                    }
                    .padding(.horizontal, 30)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard coordinator.state.phase.isActive else { return }

                            let deltaX = value.translation.width - lastDragX
                            lastDragX = value.translation.width

                            // Horizontal movement controls rod position
                            let currentRods = coordinator.state.rodsForPlayer("player_0")
                            if let firstRod = currentRods.first {
                                let sensitivity: CGFloat = 0.008
                                let newOffset = firstRod.xOffset + deltaX * sensitivity
                                coordinator.handleRodMove(playerId: "player_0", xOffset: newOffset)
                            }
                        }
                        .onEnded { value in
                            lastDragX = 0

                            // Check for vertical swipe (kick)
                            let verticalDistance = value.translation.height
                            let horizontalDistance = abs(value.translation.width)

                            if abs(verticalDistance) > 30 && abs(verticalDistance) > horizontalDistance {
                                if verticalDistance < 0 {
                                    // Swipe up - forward kick
                                    coordinator.handleKick(playerId: "player_0", type: .forward)
                                } else {
                                    // Swipe down - pull shot
                                    coordinator.handleKick(playerId: "player_0", type: .pullShot)
                                }
                            }
                        }
                )
            }
        }
    }

    // MARK: - Exit Button

    private var exitButton: some View {
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
    }

    private func handleExit() {
        mainCoordinator.goToLauncher()
    }
}

// MARK: - Table View

private struct FoosballTableView: View {
    let config: FoosballConfig

    var body: some View {
        let halfWidth = config.tableWidth / 2
        let halfHeight = config.tableHeight / 2

        ZStack {
            // Table surface
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 0.05, green: 0.08, blue: 0.05))
                .frame(width: config.tableWidth, height: config.tableHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            LinearGradient(
                                colors: [.green.opacity(0.6), .cyan.opacity(0.4)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 3
                        )
                )
                .shadow(color: .green.opacity(0.3), radius: 15)

            // Center line
            Rectangle()
                .fill(.white.opacity(0.2))
                .frame(width: config.tableWidth - 20, height: 2)

            // Center circle
            Circle()
                .stroke(.white.opacity(0.2), lineWidth: 2)
                .frame(width: 60, height: 60)

            // Center dot
            Circle()
                .fill(.white.opacity(0.3))
                .frame(width: 8, height: 8)
        }
    }
}

// MARK: - Goal Area View

private struct GoalAreaView: View {
    let config: FoosballConfig
    let isPlayerGoal: Bool

    var body: some View {
        let halfHeight = config.tableHeight / 2
        let yOffset = isPlayerGoal ? halfHeight : -halfHeight
        let color: Color = isPlayerGoal ? .pink : .cyan

        ZStack {
            // Goal opening
            Rectangle()
                .fill(color.opacity(0.3))
                .frame(width: config.goalWidth, height: config.goalDepth)
                .overlay(
                    Rectangle()
                        .stroke(color, lineWidth: 2)
                )
                .shadow(color: color.opacity(0.5), radius: 8)
        }
        .offset(y: yOffset + (isPlayerGoal ? config.goalDepth / 2 : -config.goalDepth / 2))
    }
}

// MARK: - Rod View

private struct RodView: View {
    let rod: FoosballRod
    let config: FoosballConfig
    let isHighlighted: Bool

    var body: some View {
        let positions = rod.foosmenPositions(config: config)
        let color: Color = rod.isPlayerSide ? .cyan : .pink
        let rotation = rod.kickState.currentRotation

        ZStack {
            // Rod bar
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.gray.opacity(0.6), .white.opacity(0.8), .gray.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: config.tableWidth - 20, height: config.rodBarHeight)
                .offset(y: rod.yPosition)
                .shadow(color: color.opacity(isHighlighted ? 0.5 : 0.2), radius: isHighlighted ? 6 : 2)

            // Foosmen
            ForEach(Array(positions.enumerated()), id: \.offset) { index, pos in
                FoosmanView(
                    config: config,
                    color: color,
                    rotation: rotation,
                    isKicking: rod.kickState.isKicking
                )
                .position(x: pos.x + config.tableWidth / 2, y: pos.y + config.tableHeight / 2)
            }
        }
        .frame(width: config.tableWidth, height: config.tableHeight)
        .opacity(isHighlighted ? 1.0 : 0.85)
    }
}

// MARK: - Foosman View

private struct FoosmanView: View {
    let config: FoosballConfig
    let color: Color
    let rotation: CGFloat
    let isKicking: Bool

    var body: some View {
        ZStack {
            // Body
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: config.manWidth, height: config.manHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(color.opacity(0.8), lineWidth: 1)
                )
                .shadow(color: color.opacity(isKicking ? 0.8 : 0.4), radius: isKicking ? 8 : 4)
                .rotationEffect(.radians(rotation))

            // Head indicator (small circle at top)
            Circle()
                .fill(color.opacity(0.8))
                .frame(width: 6, height: 6)
                .offset(y: -config.manHeight / 2 + 4)
                .rotationEffect(.radians(rotation))
        }
    }
}

// MARK: - Ball View

private struct BallView: View {
    let ball: FoosballBall
    let config: FoosballConfig

    var body: some View {
        ZStack {
            // Glow
            Circle()
                .fill(.white.opacity(0.3))
                .frame(width: config.ballRadius * 3, height: config.ballRadius * 3)
                .blur(radius: 8)

            // Ball
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white, .gray.opacity(0.8)],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: config.ballRadius
                    )
                )
                .frame(width: config.ballRadius * 2, height: config.ballRadius * 2)
                .shadow(color: .white.opacity(0.5), radius: 4)
        }
        .position(
            x: ball.position.x + config.tableWidth / 2,
            y: ball.position.y + config.tableHeight / 2
        )
    }
}

// MARK: - Grid Background

private struct FoosballGridBackground: View {
    var body: some View {
        Canvas { context, size in
            let gridSize: CGFloat = 40
            let lineWidth: CGFloat = 0.5

            for x in stride(from: 0, through: size.width, by: gridSize) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(.yellow.opacity(0.06)), lineWidth: lineWidth)
            }

            for y in stride(from: 0, through: size.height, by: gridSize) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(.yellow.opacity(0.06)), lineWidth: lineWidth)
            }
        }
    }
}

// MARK: - Countdown Overlay

private struct FoosballCountdownOverlay: View {
    let count: Int

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 120, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .shadow(color: .yellow.opacity(0.8), radius: 20)
                } else {
                    Text("GO!")
                        .font(.system(size: 80, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)
                        .shadow(color: .green.opacity(0.8), radius: 20)
                }
            }
        }
    }
}

// MARK: - Goal Scored Overlay

private struct GoalScoredOverlay: View {
    let playerScored: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("GOAL!")
                    .font(.system(size: 60, weight: .bold, design: .monospaced))
                    .foregroundStyle(playerScored ? .cyan : .pink)
                    .shadow(color: (playerScored ? Color.cyan : .pink).opacity(0.8), radius: 20)

                Text(playerScored ? "Players Score!" : "AI Scores!")
                    .font(.system(size: 24, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
            }
        }
    }
}

// MARK: - Game Over Overlay

private struct GameOverOverlay: View {
    let playerWon: Bool
    let playerScore: Int
    let aiScore: Int
    let onRematch: () -> Void
    let onExit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 30) {
                Text(playerWon ? "VICTORY!" : "DEFEAT")
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundStyle(playerWon ? .cyan : .pink)
                    .shadow(color: (playerWon ? Color.cyan : .pink).opacity(0.8), radius: 15)

                Text("\(playerScore) - \(aiScore)")
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)

                HStack(spacing: 20) {
                    Button(action: onRematch) {
                        Text("REMATCH")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 15)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(.yellow.opacity(0.3))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(.yellow, lineWidth: 2)
                                    )
                            )
                    }

                    Button(action: onExit) {
                        Text("EXIT")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundStyle(.gray)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 15)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(.gray, lineWidth: 2)
                            )
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Foosball Game") {
    let coordinator = GameCoordinator()
    coordinator.launchFoosball()
    return FoosballGameView()
        .environment(coordinator)
}
