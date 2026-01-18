/**
 * Controller View - Main Game Screen
 *
 * The primary game view that displays the air hockey table
 * and handles touch input for paddle control.
 */

import SwiftUI

struct ControllerView: View {
    @EnvironmentObject var coordinator: GameCoordinator

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Score display
                    ScoreDisplay(
                        playerScore: coordinator.matchState.playerScore,
                        opponentScore: coordinator.matchState.opponentScore,
                        maxScore: coordinator.matchState.config.maxScore
                    )
                    .padding(.top, 8)

                    // Game table
                    GameTableView(
                        matchState: coordinator.matchState,
                        onPaddleMove: { position in
                            coordinator.handlePaddleMove(to: position)
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    // Controls
                    GameControls(
                        isPaused: coordinator.matchState.isPaused,
                        onPause: { coordinator.handlePause() },
                        onExit: { coordinator.goToHome() }
                    )
                    .padding(.bottom, 8)
                }

                // Overlay for pause/win states
                if coordinator.matchState.isPaused {
                    PauseOverlay(
                        onResume: { coordinator.handlePause() },
                        onExit: { coordinator.goToHome() }
                    )
                }

                if let winner = coordinator.matchState.winner {
                    GameOverOverlay(
                        winner: winner,
                        isSinglePlayer: coordinator.isSinglePlayer,
                        playerScore: coordinator.matchState.playerScore,
                        opponentScore: coordinator.matchState.opponentScore,
                        onRematch: { coordinator.handleRematch() },
                        onExit: { coordinator.goToHome() }
                    )
                }
            }
        }
    }
}

// MARK: - Score Display

struct ScoreDisplay: View {
    let playerScore: Int
    let opponentScore: Int
    let maxScore: Int

    var body: some View {
        HStack(spacing: 40) {
            // Opponent score
            VStack(spacing: 2) {
                Text("OPPONENT")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.pink.opacity(0.7))
                Text("\(opponentScore)")
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundStyle(.pink)
                    .shadow(color: .pink.opacity(0.5), radius: 5)
            }

            // Divider
            Text(":")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundStyle(.gray)

            // Player score
            VStack(spacing: 2) {
                Text("YOU")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.cyan.opacity(0.7))
                Text("\(playerScore)")
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan)
                    .shadow(color: .cyan.opacity(0.5), radius: 5)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Game Table View

struct GameTableView: View {
    let matchState: MatchState
    let onPaddleMove: (Position) -> Void

    var body: some View {
        GeometryReader { geometry in
            let config = matchState.config
            let scaleX = geometry.size.width / config.tableWidth
            let scaleY = geometry.size.height / config.tableHeight
            let scale = min(scaleX, scaleY)

            let scaledWidth = config.tableWidth * scale
            let scaledHeight = config.tableHeight * scale
            let offsetX = (geometry.size.width - scaledWidth) / 2
            let offsetY = (geometry.size.height - scaledHeight) / 2

            ZStack {
                // Table background
                TableBackground(
                    config: config,
                    playAreaShift: matchState.playAreaShift
                )
                .frame(width: scaledWidth, height: scaledHeight)
                .offset(x: offsetX, y: offsetY)

                // Puck
                PuckView(
                    puck: matchState.puck,
                    radius: config.puckRadius * scale
                )
                .position(
                    x: offsetX + matchState.puck.position.x * scale,
                    y: offsetY + matchState.puck.position.y * scale
                )

                // Opponent paddle
                PaddleView(
                    isPlayer: false,
                    radius: config.paddleRadius * scale
                )
                .position(
                    x: offsetX + matchState.opponentPaddle.x * scale,
                    y: offsetY + matchState.opponentPaddle.y * scale
                )

                // Player paddle
                PaddleView(
                    isPlayer: true,
                    radius: config.paddleRadius * scale
                )
                .position(
                    x: offsetX + matchState.playerPaddle.x * scale,
                    y: offsetY + matchState.playerPaddle.y * scale
                )
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard matchState.isPlaying && !matchState.isPaused else { return }

                        // Convert touch to game coordinates
                        let touchX = (value.location.x - offsetX) / scale
                        let touchY = (value.location.y - offsetY) / scale
                        onPaddleMove(Position(x: touchX, y: touchY))
                    }
            )
        }
        .aspectRatio(
            matchState.config.tableWidth / matchState.config.tableHeight,
            contentMode: .fit
        )
    }
}

// MARK: - Table Background

struct TableBackground: View {
    let config: GameConfig
    let playAreaShift: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let goalWidth = config.goalWidth / config.tableWidth * width
            let goalLeft = (width - goalWidth) / 2
            let centerY = height / 2 + (playAreaShift / config.tableHeight * height)

            ZStack {
                // Table surface
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: 0.08))

                // Grid
                GridPattern(width: width, height: height)

                // Center line
                Path { path in
                    path.move(to: CGPoint(x: 0, y: centerY))
                    path.addLine(to: CGPoint(x: width, y: centerY))
                }
                .stroke(
                    playAreaShift != 0
                        ? (playAreaShift > 0 ? .pink : .cyan)
                        : .cyan,
                    style: StrokeStyle(lineWidth: 2, dash: [10, 5])
                )
                .opacity(0.6)

                // Center circle
                Circle()
                    .stroke(
                        playAreaShift != 0
                            ? (playAreaShift > 0 ? .pink : .cyan)
                            : .cyan,
                        lineWidth: 2
                    )
                    .frame(width: 80, height: 80)
                    .position(x: width / 2, y: centerY)
                    .opacity(0.5)

                // Top goal (opponent)
                Rectangle()
                    .fill(.pink)
                    .frame(width: goalWidth, height: 8)
                    .position(x: width / 2, y: 4)
                    .shadow(color: .pink.opacity(0.8), radius: 10)

                // Bottom goal (player)
                Rectangle()
                    .fill(.cyan)
                    .frame(width: goalWidth, height: 8)
                    .position(x: width / 2, y: height - 4)
                    .shadow(color: .cyan.opacity(0.8), radius: 10)

                // Border
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.cyan, lineWidth: 3)
                    .shadow(color: .cyan.opacity(0.5), radius: 10)
            }
        }
    }
}

struct GridPattern: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Canvas { context, size in
            let gridSize: CGFloat = 30

            for x in stride(from: 0, through: width, by: gridSize) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: height))
                context.stroke(path, with: .color(.cyan.opacity(0.1)), lineWidth: 0.5)
            }

            for y in stride(from: 0, through: height, by: gridSize) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: width, y: y))
                context.stroke(path, with: .color(.cyan.opacity(0.1)), lineWidth: 0.5)
            }
        }
    }
}

// MARK: - Puck View

struct PuckView: View {
    let puck: PuckState
    let radius: CGFloat

    var body: some View {
        ZStack {
            // Glow
            Circle()
                .fill(.cyan.opacity(0.3))
                .frame(width: radius * 3, height: radius * 3)
                .blur(radius: 10)

            // Puck body
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.cyan, .cyan.opacity(0.7)],
                        center: .center,
                        startRadius: 0,
                        endRadius: radius
                    )
                )
                .frame(width: radius * 2, height: radius * 2)
                .shadow(color: .cyan, radius: 8)

            // Flashing indicator
            if puck.isFlashing {
                Circle()
                    .fill(.white.opacity(0.5))
                    .frame(width: radius * 2, height: radius * 2)
                    .opacity(puck.isFlashing ? 0.8 : 0)
                    .animation(.easeInOut(duration: 0.3).repeatForever(), value: puck.isFlashing)
            }
        }
    }
}

// MARK: - Paddle View

struct PaddleView: View {
    let isPlayer: Bool
    let radius: CGFloat

    private var color: Color { isPlayer ? .cyan : .pink }

    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: radius * 2.5, height: radius * 2.5)
                .blur(radius: 8)

            // Paddle body
            Circle()
                .fill(
                    RadialGradient(
                        colors: [color, color.opacity(0.8)],
                        center: .center,
                        startRadius: 0,
                        endRadius: radius
                    )
                )
                .frame(width: radius * 2, height: radius * 2)

            // Inner ring
            Circle()
                .stroke(color.opacity(0.5), lineWidth: 2)
                .frame(width: radius * 1.4, height: radius * 1.4)

            // Center dot
            Circle()
                .fill(color)
                .frame(width: radius * 0.4, height: radius * 0.4)
        }
        .shadow(color: color.opacity(0.8), radius: 10)
    }
}

// MARK: - Game Controls

struct GameControls: View {
    let isPaused: Bool
    let onPause: () -> Void
    let onExit: () -> Void

    var body: some View {
        HStack(spacing: 20) {
            // Exit button
            Button(action: onExit) {
                Image(systemName: "house.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.gray)
                    .frame(width: 44, height: 44)
                    .background(Circle().stroke(.gray.opacity(0.3)))
            }

            Spacer()

            // Pause button
            Button(action: onPause) {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.cyan)
                    .frame(width: 44, height: 44)
                    .background(Circle().stroke(.cyan.opacity(0.5)))
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Pause Overlay

struct PauseOverlay: View {
    let onResume: () -> Void
    let onExit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("PAUSED")
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan)
                    .shadow(color: .cyan.opacity(0.5), radius: 10)

                VStack(spacing: 12) {
                    Button(action: onResume) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Resume")
                        }
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.black)
                        .frame(width: 200, height: 50)
                        .background(.cyan)
                        .cornerRadius(12)
                    }

                    Button(action: onExit) {
                        HStack {
                            Image(systemName: "house.fill")
                            Text("Exit")
                        }
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.cyan)
                        .frame(width: 200, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.cyan, lineWidth: 2)
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Game Over Overlay

struct GameOverOverlay: View {
    let winner: PlayerID
    let isSinglePlayer: Bool
    let playerScore: Int
    let opponentScore: Int
    let onRematch: () -> Void
    let onExit: () -> Void

    private var isPlayerWinner: Bool { winner == .player }

    private var title: String {
        if isSinglePlayer {
            return isPlayerWinner ? "YOU WIN!" : "YOU LOSE"
        } else {
            return isPlayerWinner ? "PLAYER 1 WINS!" : "PLAYER 2 WINS!"
        }
    }

    private var color: Color { isPlayerWinner ? .cyan : .pink }

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text(title)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
                    .shadow(color: color.opacity(0.8), radius: 15)

                // Final score
                HStack(spacing: 20) {
                    Text("\(opponentScore)")
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundStyle(.pink)

                    Text("-")
                        .font(.system(size: 36, design: .monospaced))
                        .foregroundStyle(.gray)

                    Text("\(playerScore)")
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundStyle(.cyan)
                }

                VStack(spacing: 12) {
                    Button(action: onRematch) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Rematch")
                        }
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.black)
                        .frame(width: 200, height: 50)
                        .background(color)
                        .cornerRadius(12)
                    }

                    Button(action: onExit) {
                        HStack {
                            Image(systemName: "house.fill")
                            Text("Exit")
                        }
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundStyle(color)
                        .frame(width: 200, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(color, lineWidth: 2)
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ControllerView()
        .environmentObject(GameCoordinator())
}
