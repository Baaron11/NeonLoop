/**
 * BilliardDodge View - TV/Main Display
 *
 * The main visual display for the Billiard Dodge game.
 * Shows:
 * - Full billiard table with neon aesthetic
 * - All player balls with P1/P2/P3/P4 labels
 * - Cue ball position
 * - CPU shot preview line (dotted)
 * - Each player's planned move preview (fainter lines)
 * - Round counter and countdown timer
 * - Player status (Aiming.../Ready/OUT)
 * - Pockets with glowing edges
 */

import SwiftUI

// MARK: - Header View

struct BilliardDodgeHeader: View {
    let state: BilliardDodgeState

    var body: some View {
        HStack {
            // Round counter
            VStack(alignment: .leading, spacing: 4) {
                Text("ROUND")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.gray)
                    .tracking(2)

                Text("\(state.currentRound)/\(state.totalRounds)")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundStyle(.purple)
                    .shadow(color: .purple.opacity(0.5), radius: 4)
            }

            Spacer()

            // Player statuses
            HStack(spacing: 16) {
                ForEach(state.balls) { ball in
                    PlayerStatusBadge(
                        ball: ball,
                        status: state.statusForPlayer(ball.playerId ?? "")
                    )
                }
            }

            Spacer()

            // Countdown timer (when aiming)
            VStack(alignment: .trailing, spacing: 4) {
                Text("TIME")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.gray)
                    .tracking(2)

                if case .countdown(let remaining) = state.phase {
                    Text(String(format: "%.1f", remaining))
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundStyle(remaining < 2 ? .red : .cyan)
                        .shadow(color: (remaining < 2 ? Color.red : .cyan).opacity(0.5), radius: 4)
                } else {
                    Text("--")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundStyle(.gray)
                }
            }
        }
    }
}

// MARK: - Player Status Badge

struct PlayerStatusBadge: View {
    let ball: BilliardBall
    let status: PlayerStatus

    var body: some View {
        VStack(spacing: 4) {
            // Player ball indicator
            Circle()
                .fill(ball.isEliminated ? .gray.opacity(0.3) : ball.color)
                .frame(width: 16, height: 16)
                .overlay(
                    Circle()
                        .stroke(ball.color.opacity(0.5), lineWidth: 1)
                )
                .shadow(color: ball.isEliminated ? .clear : ball.color.opacity(0.5), radius: 4)

            // Status text
            Text(status.rawValue)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(statusColor)
        }
    }

    private var statusColor: Color {
        switch status {
        case .aiming: return .yellow
        case .ready: return .green
        case .eliminated: return .red
        case .waiting: return .gray
        }
    }
}

// MARK: - Table View

struct BilliardDodgeTableView: View {
    let state: BilliardDodgeState

    var body: some View {
        GeometryReader { geometry in
            let config = state.config
            let aspectRatio = config.tableWidth / config.tableHeight
            let availableWidth = geometry.size.width
            let availableHeight = geometry.size.height

            // Calculate size to fit while maintaining aspect ratio
            let tableWidth: CGFloat
            let tableHeight: CGFloat

            if availableWidth / availableHeight > aspectRatio {
                // Height constrained
                tableHeight = availableHeight
                tableWidth = tableHeight * aspectRatio
            } else {
                // Width constrained
                tableWidth = availableWidth
                tableHeight = tableWidth / aspectRatio
            }

            let scaleX = tableWidth / config.tableWidth
            let scaleY = tableHeight / config.tableHeight

            ZStack {
                // Table surface
                BilliardTableSurface(config: config)
                    .frame(width: tableWidth, height: tableHeight)

                // Pockets
                ForEach(Array(state.pockets.enumerated()), id: \.offset) { _, pocket in
                    BilliardPocketView(position: pocket, config: config)
                        .position(
                            x: pocket.x * scaleX,
                            y: pocket.y * scaleY
                        )
                }

                // CPU shot preview line (during aiming phase)
                if state.phase.isAimingPhase || state.phase.isActive {
                    CPUShotPreview(
                        state: state,
                        scaleX: scaleX,
                        scaleY: scaleY
                    )
                }

                // Player move previews (during aiming phase)
                if state.phase.isAimingPhase {
                    ForEach(state.balls.filter { !$0.isEliminated }) { ball in
                        if let playerId = ball.playerId,
                           let move = state.playerMoves[playerId],
                           move.force > 0 {
                            PlayerMovePreview(
                                ball: ball,
                                move: move,
                                config: config,
                                scaleX: scaleX,
                                scaleY: scaleY
                            )
                        }
                    }
                }

                // Cue ball
                if !state.cueBall.isPocketed {
                    BilliardBallView(ball: state.cueBall, config: config)
                        .position(
                            x: state.cueBall.position.x * scaleX,
                            y: state.cueBall.position.y * scaleY
                        )
                }

                // Player balls
                ForEach(state.balls.filter { !$0.isPocketed && !$0.isEliminated }) { ball in
                    BilliardBallView(ball: ball, config: config)
                        .position(
                            x: ball.position.x * scaleX,
                            y: ball.position.y * scaleY
                        )
                }

                // Eliminated player balls (shown faded)
                ForEach(state.balls.filter { $0.isEliminated }) { ball in
                    BilliardBallView(ball: ball, config: config, isEliminated: true)
                        .position(
                            x: ball.position.x * scaleX,
                            y: ball.position.y * scaleY
                        )
                        .opacity(0.3)
                }
            }
            .frame(width: tableWidth, height: tableHeight)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }
}

// MARK: - Table Surface

struct BilliardTableSurface: View {
    let config: BilliardDodgeConfig

    var body: some View {
        ZStack {
            // Table felt (dark charcoal, not green)
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.1))

            // Inner playing area
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(white: 0.08))
                .padding(8)

            // Rail glow
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [.cyan.opacity(0.8), .purple.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .blur(radius: 4)

            // Rail border
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [.cyan, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )

            // Subtle grid pattern on table
            BilliardTableGrid(config: config)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(8)
        }
    }
}

struct BilliardTableGrid: View {
    let config: BilliardDodgeConfig

    var body: some View {
        Canvas { context, size in
            let gridSize: CGFloat = 20

            // Vertical lines
            for x in stride(from: gridSize, to: size.width, by: gridSize) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(.cyan.opacity(0.05)), lineWidth: 0.5)
            }

            // Horizontal lines
            for y in stride(from: gridSize, to: size.height, by: gridSize) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(.cyan.opacity(0.05)), lineWidth: 0.5)
            }

            // Center line
            var centerLine = Path()
            centerLine.move(to: CGPoint(x: size.width / 2, y: 0))
            centerLine.addLine(to: CGPoint(x: size.width / 2, y: size.height))
            context.stroke(centerLine, with: .color(.cyan.opacity(0.15)), lineWidth: 1)

            // Center circle
            let centerRadius: CGFloat = min(size.width, size.height) * 0.15
            var centerCircle = Path()
            centerCircle.addEllipse(in: CGRect(
                x: size.width / 2 - centerRadius,
                y: size.height / 2 - centerRadius,
                width: centerRadius * 2,
                height: centerRadius * 2
            ))
            context.stroke(centerCircle, with: .color(.cyan.opacity(0.15)), lineWidth: 1)
        }
    }
}

// MARK: - Pocket View

struct BilliardPocketView: View {
    let position: CGPoint
    let config: BilliardDodgeConfig

    @State private var pulseAnimation = false

    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(.black)
                .frame(width: config.pocketRadius * 2.5, height: config.pocketRadius * 2.5)
                .blur(radius: 8)

            // Pocket hole
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.black, Color(white: 0.05)],
                        center: .center,
                        startRadius: 0,
                        endRadius: config.pocketRadius
                    )
                )
                .frame(width: config.pocketRadius * 2, height: config.pocketRadius * 2)

            // Pocket ring glow
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.red.opacity(0.8), .orange.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: config.pocketRadius * 2, height: config.pocketRadius * 2)
                .blur(radius: 2)
                .scaleEffect(pulseAnimation ? 1.1 : 1.0)

            // Pocket ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.red, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
                .frame(width: config.pocketRadius * 2, height: config.pocketRadius * 2)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
    }
}

// MARK: - Ball View

struct BilliardBallView: View {
    let ball: BilliardBall
    let config: BilliardDodgeConfig
    var isEliminated: Bool = false

    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(ball.color.opacity(0.4))
                .frame(width: config.ballRadius * 3, height: config.ballRadius * 3)
                .blur(radius: 6)

            // Ball shadow
            Ellipse()
                .fill(.black.opacity(0.4))
                .frame(width: config.ballRadius * 2.2, height: config.ballRadius * 1.2)
                .offset(x: 2, y: 4)
                .blur(radius: 3)

            // Ball body
            Circle()
                .fill(
                    RadialGradient(
                        colors: ball.playerId == nil
                            ? [.white, Color(white: 0.85), Color(white: 0.7)] // Cue ball
                            : [ball.color, ball.color.opacity(0.8), ball.color.opacity(0.6)], // Player ball
                        center: .init(x: 0.35, y: 0.3),
                        startRadius: 0,
                        endRadius: config.ballRadius
                    )
                )
                .frame(width: config.ballRadius * 2, height: config.ballRadius * 2)
                .shadow(color: ball.color.opacity(0.6), radius: 4)

            // Specular highlight
            Circle()
                .fill(.white.opacity(0.8))
                .frame(width: config.ballRadius * 0.5, height: config.ballRadius * 0.5)
                .offset(x: -config.ballRadius * 0.3, y: -config.ballRadius * 0.3)

            // Label for player balls
            if ball.playerId != nil {
                Text(ball.displayLabel)
                    .font(.system(size: config.ballRadius * 0.8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.black.opacity(0.7))
            }
        }
    }
}

// MARK: - CPU Shot Preview

struct CPUShotPreview: View {
    let state: BilliardDodgeState
    let scaleX: CGFloat
    let scaleY: CGFloat

    var body: some View {
        let trajectory = BilliardDodgePhysics.predictTrajectory(
            from: state.cueBall.position,
            angle: state.cpuShot.angle,
            power: state.cpuShot.power,
            config: state.config,
            maxPoints: 40,
            maxBounces: 2
        )

        Canvas { context, size in
            guard trajectory.count > 1 else { return }

            // Draw dashed line
            var path = Path()
            path.move(to: CGPoint(
                x: trajectory[0].x * scaleX,
                y: trajectory[0].y * scaleY
            ))

            for point in trajectory.dropFirst() {
                path.addLine(to: CGPoint(
                    x: point.x * scaleX,
                    y: point.y * scaleY
                ))
            }

            context.stroke(
                path,
                with: .color(.white.opacity(0.6)),
                style: StrokeStyle(lineWidth: 2, dash: [8, 4])
            )

            // Draw arrow head at end
            if let lastPoint = trajectory.last, trajectory.count > 1 {
                let secondLast = trajectory[trajectory.count - 2]
                let angle = atan2(
                    lastPoint.y - secondLast.y,
                    lastPoint.x - secondLast.x
                )

                let arrowSize: CGFloat = 8
                let arrowPoint = CGPoint(
                    x: lastPoint.x * scaleX,
                    y: lastPoint.y * scaleY
                )

                var arrowPath = Path()
                arrowPath.move(to: arrowPoint)
                arrowPath.addLine(to: CGPoint(
                    x: arrowPoint.x - arrowSize * cos(angle - .pi / 6),
                    y: arrowPoint.y - arrowSize * sin(angle - .pi / 6)
                ))
                arrowPath.move(to: arrowPoint)
                arrowPath.addLine(to: CGPoint(
                    x: arrowPoint.x - arrowSize * cos(angle + .pi / 6),
                    y: arrowPoint.y - arrowSize * sin(angle + .pi / 6)
                ))

                context.stroke(arrowPath, with: .color(.white.opacity(0.6)), lineWidth: 2)
            }
        }
    }
}

// MARK: - Player Move Preview

struct PlayerMovePreview: View {
    let ball: BilliardBall
    let move: PlayerMove
    let config: BilliardDodgeConfig
    let scaleX: CGFloat
    let scaleY: CGFloat

    var body: some View {
        let trajectory = BilliardDodgePhysics.predictTrajectory(
            from: ball.position,
            angle: move.angle,
            power: move.force * 0.7, // Players move slower
            config: config,
            maxPoints: 20,
            maxBounces: 1
        )

        Canvas { context, size in
            guard trajectory.count > 1 else { return }

            var path = Path()
            path.move(to: CGPoint(
                x: trajectory[0].x * scaleX,
                y: trajectory[0].y * scaleY
            ))

            for point in trajectory.dropFirst() {
                path.addLine(to: CGPoint(
                    x: point.x * scaleX,
                    y: point.y * scaleY
                ))
            }

            // Fainter line than CPU shot
            context.stroke(
                path,
                with: .color(ball.color.opacity(move.isLocked ? 0.8 : 0.4)),
                style: StrokeStyle(lineWidth: move.isLocked ? 2 : 1.5, dash: [4, 2])
            )
        }
    }
}

// MARK: - Countdown Overlay

struct BilliardDodgeCountdownOverlay: View {
    let remaining: Double

    var body: some View {
        // Only show large countdown for last 3 seconds
        if remaining <= 3 {
            Text(remaining > 0 ? "\(Int(ceil(remaining)))" : "GO!")
                .font(.system(size: 120, weight: .bold, design: .monospaced))
                .foregroundStyle(remaining > 1 ? .white : .cyan)
                .shadow(color: (remaining > 1 ? Color.white : .cyan).opacity(0.8), radius: 20)
                .transition(.scale.combined(with: .opacity))
        }
    }
}

// MARK: - Round Result Overlay

struct BilliardDodgeResultOverlay: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 48, weight: .bold, design: .monospaced))
            .foregroundStyle(resultColor)
            .shadow(color: resultColor.opacity(0.8), radius: 15)
            .transition(.scale.combined(with: .opacity))
    }

    private var resultColor: Color {
        if message.contains("POCKETED") {
            return .red
        } else if message.contains("SCRATCH") {
            return .orange
        } else {
            return .green
        }
    }
}

// MARK: - Game Over Overlay

struct BilliardDodgeGameOverOverlay: View {
    let won: Bool
    let state: BilliardDodgeState
    let onExit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Result icon
                Image(systemName: won ? "trophy.fill" : "xmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(won ? .yellow : .red)
                    .shadow(color: (won ? Color.yellow : .red).opacity(0.8), radius: 15)

                // Result text
                Text(won ? "SURVIVED!" : "ELIMINATED")
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundStyle(won ? .green : .red)
                    .shadow(color: (won ? Color.green : .red).opacity(0.8), radius: 10)

                // Stats
                VStack(spacing: 8) {
                    Text("Rounds: \(state.currentRound)/\(state.totalRounds)")
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundStyle(.gray)

                    Text("Players Remaining: \(state.activePlayerCount)")
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundStyle(.gray)
                }

                // Exit button
                Button(action: onExit) {
                    Text("Continue")
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.black)
                        .frame(width: 200, height: 50)
                        .background(won ? Color.green : Color.purple)
                        .cornerRadius(12)
                }
                .padding(.top, 20)
            }
            .padding(40)
        }
    }
}

// MARK: - Preview

#Preview("Billiard Dodge Table") {
    let state = BilliardDodgeState(playerCount: 2)
    state.setupPlayers(count: 2)
    state.phase = .countdown(remaining: 3.5)
    state.cpuShot = CPUShot(angle: 0.5, power: 0.7, targetBallId: "ball_0")

    return VStack {
        BilliardDodgeHeader(state: state)
            .padding()

        BilliardDodgeTableView(state: state)
            .frame(height: 300)
            .padding()
    }
    .background(Color.black)
}
