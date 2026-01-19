/**
 * HordeDefense View - Main Game Display
 *
 * Renders the game arena with:
 * - Concentric rings and radial spokes (rails)
 * - Center goal (pulsing, defend this)
 * - Enemy goals (gaps in outer ring with pink glow)
 * - Player and AI paddles
 * - Pucks with motion trails
 * - Score display and overlays
 */

import SwiftUI

// MARK: - Main Game View

struct HordeDefenseGameView: View {
    @Environment(GameCoordinator.self) var mainCoordinator

    var body: some View {
        let coordinator = mainCoordinator.hordeDefenseCoordinator

        GeometryReader { geometry in
            if let coordinator = coordinator {
                ZStack {
                    // Background
                    Color.black
                        .ignoresSafeArea()

                    // Grid pattern
                    HordeDefenseGridBackground()

                    VStack(spacing: 0) {
                        // Header with score
                        HordeDefenseHeader(state: coordinator.state)
                            .padding(.top, 16)
                            .padding(.horizontal, 20)

                        Spacer()

                        // Main arena view
                        HordeDefenseArenaView(state: coordinator.state)
                            .aspectRatio(1, contentMode: .fit)
                            .padding(.horizontal, 20)

                        Spacer()

                        // Controller area
                        HordeDefenseControllerArea(coordinator: coordinator)
                            .frame(height: 200)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 40)
                    }

                    // Exit button
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

                    // Settings overlay
                    if case .settings = coordinator.state.phase {
                        HordeDefenseSettingsOverlay(coordinator: coordinator)
                    }

                    // Countdown overlay
                    if case .countdown(let count) = coordinator.state.phase {
                        HordeDefenseCountdownOverlay(count: count)
                    }

                    // Goal scored overlay
                    if case .goalScored(let playerScored) = coordinator.state.phase {
                        HordeDefenseGoalOverlay(playerScored: playerScored)
                    }

                    // Game over overlay
                    if case .gameOver(let playerWon) = coordinator.state.phase {
                        HordeDefenseGameOverOverlay(
                            playerWon: playerWon,
                            state: coordinator.state,
                            onExit: handleExit
                        )
                    }
                }
            } else {
                // Loading state
                Color.black
                    .ignoresSafeArea()
                VStack {
                    ProgressView()
                        .tint(.green)
                    Text("Loading Horde Defense...")
                        .foregroundStyle(.gray)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(.top, 8)
                }
                .onAppear {
                    if mainCoordinator.hordeDefenseCoordinator == nil {
                        mainCoordinator.initializeHordeDefenseIfNeeded()
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

private struct HordeDefenseGridBackground: View {
    var body: some View {
        Canvas { context, size in
            let gridSize: CGFloat = 40
            let lineWidth: CGFloat = 0.5

            for x in stride(from: 0, through: size.width, by: gridSize) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(.green.opacity(0.05)), lineWidth: lineWidth)
            }

            for y in stride(from: 0, through: size.height, by: gridSize) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(.green.opacity(0.05)), lineWidth: lineWidth)
            }
        }
    }
}

// MARK: - Header

private struct HordeDefenseHeader: View {
    let state: HordeDefenseState

    var body: some View {
        HStack {
            // Player score
            VStack(alignment: .leading, spacing: 2) {
                Text("PLAYERS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan.opacity(0.7))

                Text("\(state.playerScore)")
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan)
                    .shadow(color: .cyan.opacity(0.5), radius: 10)
            }

            Spacer()

            // Target score
            VStack(spacing: 2) {
                Text("TARGET")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.gray)

                Text("\(state.config.targetScore)")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }

            Spacer()

            // AI score
            VStack(alignment: .trailing, spacing: 2) {
                Text("AI")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.pink.opacity(0.7))

                Text("\(state.aiScore)")
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundStyle(.pink)
                    .shadow(color: .pink.opacity(0.5), radius: 10)
            }
        }
    }
}

// MARK: - Arena View

struct HordeDefenseArenaView: View {
    let state: HordeDefenseState

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let scale = size / (state.config.arenaRadius * 2)

            ZStack {
                // Outer boundary
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                    .frame(width: state.config.arenaRadius * 2 * scale,
                           height: state.config.arenaRadius * 2 * scale)

                // Rails (rings)
                ForEach(0..<state.config.ringRadii.count, id: \.self) { ringIndex in
                    let radius = state.config.ringRadii[ringIndex]
                    Circle()
                        .stroke(Color.cyan.opacity(0.6), lineWidth: 3)
                        .frame(width: radius * 2 * scale, height: radius * 2 * scale)
                        .shadow(color: .cyan.opacity(0.3), radius: 4)
                }

                // Rails (spokes)
                ForEach(0..<state.config.spokeCount, id: \.self) { spokeIndex in
                    SpokeView(
                        spokeIndex: spokeIndex,
                        config: state.config,
                        scale: scale
                    )
                }

                // Enemy goals
                ForEach(state.enemyGoals) { goal in
                    EnemyGoalView(
                        goal: goal,
                        config: state.config,
                        scale: scale
                    )
                }

                // Center goal
                CenterGoalView(
                    radius: state.config.centerGoalRadius,
                    scale: scale
                )

                // Pucks
                ForEach(state.pucks) { puck in
                    if puck.isActive {
                        HordePuckView(
                            puck: puck,
                            config: state.config,
                            scale: scale
                        )
                    }
                }

                // Player paddles
                ForEach(state.playerPaddles) { paddle in
                    HordePaddleView(
                        paddle: paddle,
                        config: state.config,
                        scale: scale
                    )
                }

                // AI paddles
                ForEach(state.aiPaddles) { paddle in
                    HordePaddleView(
                        paddle: paddle,
                        config: state.config,
                        scale: scale
                    )
                }

                // Junction points
                JunctionPointsView(
                    config: state.config,
                    scale: scale
                )
            }
            .frame(width: size, height: size)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }
}

// MARK: - Spoke View

private struct SpokeView: View {
    let spokeIndex: Int
    let config: HordeDefenseConfig
    let scale: CGFloat

    var body: some View {
        let angle = CGFloat(spokeIndex) * (2 * .pi / CGFloat(config.spokeCount))
        let innerRadius = (config.centerGoalRadius + 10) * scale
        let outerRadius = (config.ringRadii.last ?? config.arenaRadius) * scale
        let center = config.arenaRadius * scale

        Path { path in
            let start = CGPoint(
                x: center + cos(angle) * innerRadius,
                y: center + sin(angle) * innerRadius
            )
            let end = CGPoint(
                x: center + cos(angle) * outerRadius,
                y: center + sin(angle) * outerRadius
            )
            path.move(to: start)
            path.addLine(to: end)
        }
        .stroke(Color.cyan.opacity(0.6), lineWidth: 3)
        .shadow(color: .cyan.opacity(0.3), radius: 4)
    }
}

// MARK: - Enemy Goal View

private struct EnemyGoalView: View {
    let goal: EnemyGoal
    let config: HordeDefenseConfig
    let scale: CGFloat

    var body: some View {
        let radius = config.arenaRadius * scale
        let center = config.arenaRadius * scale

        ZStack {
            // Goal arc (gap in outer ring)
            Path { path in
                path.addArc(
                    center: CGPoint(x: center, y: center),
                    radius: radius,
                    startAngle: .radians(goal.startAngle),
                    endAngle: .radians(goal.endAngle),
                    clockwise: false
                )
            }
            .stroke(
                goal.recentlyScored ? Color.white : Color.pink,
                lineWidth: 6
            )
            .shadow(color: goal.recentlyScored ? .white : .pink, radius: 10)

            // Goal indicator
            let midAngle = goal.centerAngle
            let indicatorRadius = radius + 15
            Circle()
                .fill(goal.recentlyScored ? Color.white : Color.pink.opacity(0.8))
                .frame(width: 12, height: 12)
                .position(
                    x: center + cos(midAngle) * indicatorRadius,
                    y: center + sin(midAngle) * indicatorRadius
                )
                .shadow(color: goal.recentlyScored ? .white : .pink, radius: 8)
        }
    }
}

// MARK: - Center Goal View

private struct CenterGoalView: View {
    let radius: CGFloat
    let scale: CGFloat

    @State private var isPulsing = false

    var body: some View {
        let scaledRadius = radius * scale

        ZStack {
            // Glow effect
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.purple.opacity(0.5), .purple.opacity(0)],
                        center: .center,
                        startRadius: scaledRadius * 0.5,
                        endRadius: scaledRadius * 1.5
                    )
                )
                .frame(width: scaledRadius * 3, height: scaledRadius * 3)
                .scaleEffect(isPulsing ? 1.2 : 1.0)

            // Goal circle
            Circle()
                .stroke(Color.purple, lineWidth: 4)
                .frame(width: scaledRadius * 2, height: scaledRadius * 2)
                .shadow(color: .purple, radius: 10)

            // Inner fill
            Circle()
                .fill(Color.purple.opacity(0.2))
                .frame(width: scaledRadius * 2, height: scaledRadius * 2)

            // Label
            Text("GOAL")
                .font(.system(size: 10 * scale, weight: .bold, design: .monospaced))
                .foregroundStyle(.purple)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

// MARK: - Puck View

private struct HordePuckView: View {
    let puck: HordePuck
    let config: HordeDefenseConfig
    let scale: CGFloat

    var body: some View {
        let x = puck.position.x * scale
        let y = puck.position.y * scale
        let radius = config.puckRadius * scale

        ZStack {
            // Motion trail
            if puck.velocity.magnitude > 1 {
                let trailLength: CGFloat = 20 * scale
                let angle = atan2(-puck.velocity.dy, -puck.velocity.dx)

                Path { path in
                    path.move(to: CGPoint(x: x, y: y))
                    path.addLine(to: CGPoint(
                        x: x + cos(angle) * trailLength,
                        y: y + sin(angle) * trailLength
                    ))
                }
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.8), .white.opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: radius
                )
            }

            // Puck glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white, .cyan.opacity(0.5)],
                        center: .center,
                        startRadius: 0,
                        endRadius: radius * 2
                    )
                )
                .frame(width: radius * 2, height: radius * 2)
                .shadow(color: .cyan, radius: 8)
                .position(x: x, y: y)
        }
    }
}

// MARK: - Paddle View

private struct HordePaddleView: View {
    let paddle: HordePaddle
    let config: HordeDefenseConfig
    let scale: CGFloat

    var body: some View {
        let position = paddle.position.toPoint(config: config)
        let x = position.x * scale
        let y = position.y * scale
        let length = config.paddleLength * scale
        let thickness = config.paddleThickness * scale

        ZStack {
            // Paddle glow
            Capsule()
                .fill(paddle.color.opacity(0.3))
                .frame(width: length * 1.3, height: thickness * 2)
                .blur(radius: 4)
                .position(x: x, y: y)

            // Paddle body
            Capsule()
                .fill(paddle.color)
                .frame(width: length, height: thickness)
                .shadow(color: paddle.color, radius: 6)
                .position(x: x, y: y)

            // Label
            Text(paddle.displayLabel)
                .font(.system(size: 8 * scale, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .position(x: x, y: y)
        }
    }
}

// MARK: - Junction Points View

private struct JunctionPointsView: View {
    let config: HordeDefenseConfig
    let scale: CGFloat

    var body: some View {
        let railSystem = RailSystem(config: config)

        ForEach(railSystem.junctionPoints()) { junction in
            Circle()
                .fill(Color.cyan.opacity(0.8))
                .frame(width: 6 * scale, height: 6 * scale)
                .position(
                    x: junction.position.x * scale,
                    y: junction.position.y * scale
                )
        }
    }
}

// MARK: - Countdown Overlay

private struct HordeDefenseCountdownOverlay: View {
    let count: Int

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            Text(count > 0 ? "\(count)" : "GO!")
                .font(.system(size: 120, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .shadow(color: .cyan, radius: 20)
                .shadow(color: .cyan, radius: 40)
        }
    }
}

// MARK: - Goal Overlay

private struct HordeDefenseGoalOverlay: View {
    let playerScored: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("GOAL!")
                    .font(.system(size: 60, weight: .bold, design: .monospaced))
                    .foregroundStyle(playerScored ? .cyan : .pink)
                    .shadow(color: playerScored ? .cyan : .pink, radius: 20)

                Text(playerScored ? "Players Score!" : "AI Scores!")
                    .font(.system(size: 20, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
            }
        }
    }
}

// MARK: - Game Over Overlay

private struct HordeDefenseGameOverOverlay: View {
    let playerWon: Bool
    let state: HordeDefenseState
    let onExit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text(playerWon ? "VICTORY!" : "DEFEAT")
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundStyle(playerWon ? .cyan : .pink)
                    .shadow(color: playerWon ? .cyan : .pink, radius: 20)

                HStack(spacing: 32) {
                    VStack {
                        Text("Players")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(.gray)
                        Text("\(state.playerScore)")
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .foregroundStyle(.cyan)
                    }

                    Text("-")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.gray)

                    VStack {
                        Text("AI")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(.gray)
                        Text("\(state.aiScore)")
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .foregroundStyle(.pink)
                    }
                }

                Button(action: onExit) {
                    Text("EXIT")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .stroke(.white, lineWidth: 2)
                        )
                }
                .padding(.top, 20)
            }
        }
    }
}

// MARK: - Preview

#Preview("Horde Defense Game") {
    let coordinator = GameCoordinator()
    coordinator.launchHordeDefense()
    return HordeDefenseGameView()
        .environment(coordinator)
}
