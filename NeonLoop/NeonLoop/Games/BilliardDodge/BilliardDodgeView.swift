/**
 * BilliardDodge View - TV/Main Display
 *
 * The main visual display for the Billiard Dodge game with premium cinematic effects:
 * - Full billiard table with neon sci-fi aesthetic
 * - HDR-inspired tonemapping and bloom
 * - Motion trails and impact effects
 * - Three-point lighting simulation
 * - Vignette, film grain, and chromatic aberration
 *
 * All effects respect the VisualQuality setting for performance scaling.
 */

import SwiftUI

// MARK: - Header View (Enhanced)

struct BilliardDodgeHeader: View {
    let state: BilliardDodgeState
    @Environment(\.visualConfig) private var config

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
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(hudBackground)

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
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(hudBackground)

            Spacer()

            // Countdown timer (when aiming)
            VStack(alignment: .trailing, spacing: 4) {
                Text("TIME")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.gray)
                    .tracking(2)

                if case .countdown(let remaining) = state.phase {
                    TimerDisplay(remaining: remaining, config: config)
                } else {
                    Text("--")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundStyle(.gray)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(hudBackground)
        }
    }

    @ViewBuilder
    private var hudBackground: some View {
        if config.hudBlurEnabled {
            RoundedRectangle(cornerRadius: 8)
                .fill(.black.opacity(0.5))
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.ultraThinMaterial)
                        .opacity(0.3)
                )
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(.black.opacity(0.6))
        }
    }
}

// MARK: - Timer Display with Animation

struct TimerDisplay: View {
    let remaining: Double
    let config: VisualConfig

    @State private var isPulsing = false

    var body: some View {
        let isLow = remaining < 2
        let color: Color = isLow ? .red : .cyan

        Text(String(format: "%.1f", remaining))
            .font(.system(size: 24, weight: .bold, design: .monospaced))
            .foregroundStyle(color)
            .shadow(color: color.opacity(0.5), radius: isLow ? 8 : 4)
            .scaleEffect(isPulsing && isLow ? 1.1 : 1.0)
            .onChange(of: remaining) { _, newValue in
                if newValue < 2 && config.hudAnimationsEnabled {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isPulsing = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isPulsing = false
                        }
                    }
                }
            }
    }
}

// MARK: - Player Status Badge (Enhanced)

struct PlayerStatusBadge: View {
    let ball: BilliardBall
    let status: PlayerStatus
    @Environment(\.visualConfig) private var config

    var body: some View {
        VStack(spacing: 4) {
            // Player ball indicator with premium material
            ZStack {
                // Glow for active players
                if !ball.isEliminated && config.emissiveGlowEnabled {
                    Circle()
                        .fill(ball.color.opacity(0.4))
                        .frame(width: 24, height: 24)
                        .blur(radius: 4)
                }

                Circle()
                    .fill(ball.isEliminated ? .gray.opacity(0.3) : ball.color)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .stroke(ball.color.opacity(0.5), lineWidth: 1)
                    )
                    .shadow(color: ball.isEliminated ? .clear : ball.color.opacity(0.6), radius: 4)
            }

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

// MARK: - Main Table View (Enhanced)

struct BilliardDodgeTableView: View {
    let state: BilliardDodgeState
    @State private var trailManager = TrailManager()
    @State private var impactManager = ImpactFXManager()
    @State private var cameraShaking = false
    @Environment(\.visualConfig) private var config

    var body: some View {
        GeometryReader { geometry in
            let config = state.config
            let aspectRatio = config.tableWidth / config.tableHeight
            let availableWidth = geometry.size.width
            let availableHeight = geometry.size.height

            // Calculate size to fit while maintaining aspect ratio
            let isHeightConstrained = availableWidth / availableHeight > aspectRatio
            let tableWidth: CGFloat = isHeightConstrained
                ? availableHeight * aspectRatio
                : availableWidth
            let tableHeight: CGFloat = isHeightConstrained
                ? availableHeight
                : availableWidth / aspectRatio

            let scaleX = tableWidth / config.tableWidth
            let scaleY = tableHeight / config.tableHeight

            // Cinematic wrapper with post-processing
            CinematicOverlay {
                ThreePointLighting {
                    ZStack {
                        // Table surface (premium materials)
                        PremiumTableSurface(config: config)
                            .frame(width: tableWidth, height: tableHeight)

                        // Motion trails layer (behind balls)
                        TrailsLayer(
                            trails: trailManager.trails,
                            ballRadius: config.ballRadius,
                            scaleX: scaleX,
                            scaleY: scaleY
                        )
                        .frame(width: tableWidth, height: tableHeight)

                        // Pockets
                        ForEach(Array(state.pockets.enumerated()), id: \.offset) { _, pocket in
                            PremiumPocketView(position: pocket, config: config)
                                .position(
                                    x: pocket.x * scaleX,
                                    y: pocket.y * scaleY
                                )
                        }

                        // CPU shot preview lines for all cue balls
                        if state.phase.isAimingPhase || state.phase.isActive {
                            ForEach(Array(state.cueBalls.enumerated()), id: \.element.id) { index, cueBall in
                                if !cueBall.isPocketed && index < state.cpuShots.count {
                                    CPUShotPreviewForCueBall(
                                        cueBall: cueBall,
                                        shot: state.cpuShots[index],
                                        config: config,
                                        scaleX: scaleX,
                                        scaleY: scaleY
                                    )
                                }
                            }
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

                        // All cue balls (premium rendering)
                        ForEach(state.cueBalls.filter { !$0.isPocketed }) { cueBall in
                            PremiumBallView(ball: cueBall, config: config, isCueBall: true)
                                .position(
                                    x: cueBall.position.x * scaleX,
                                    y: cueBall.position.y * scaleY
                                )
                        }

                        // Obstacle balls
                        ForEach(state.obstacleBalls) { obstacle in
                            PremiumObstacleBallView(ball: obstacle, config: config)
                                .position(
                                    x: obstacle.position.x * scaleX,
                                    y: obstacle.position.y * scaleY
                                )
                        }

                        // Player balls (premium rendering)
                        ForEach(state.balls.filter { !$0.isPocketed && !$0.isEliminated }) { ball in
                            PremiumBallView(ball: ball, config: config)
                                .position(
                                    x: ball.position.x * scaleX,
                                    y: ball.position.y * scaleY
                                )
                        }

                        // Eliminated player balls (shown faded)
                        ForEach(state.balls.filter { $0.isEliminated }) { ball in
                            PremiumBallView(ball: ball, config: config, isEliminated: true)
                                .position(
                                    x: ball.position.x * scaleX,
                                    y: ball.position.y * scaleY
                                )
                                .opacity(0.3)
                        }

                        // Impact effects layer (on top)
                        ImpactEffectsLayer(impacts: impactManager.impacts)
                            .frame(width: tableWidth, height: tableHeight)
                    }
                }
            }
            .frame(width: tableWidth, height: tableHeight)
            .cameraShake(isShaking: $cameraShaking, intensity: self.config.cameraShakeIntensity)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            .onChange(of: state.phase) { _, newPhase in
                // Update trails when phase changes
                if case .executing = newPhase {
                    // Trails will be updated each frame
                } else if case .roundResult = newPhase {
                    // Clear trails at round end
                    trailManager.clearAll()
                }
            }
            // Update trails based on ball velocities (would normally be in game loop)
            .onReceive(NotificationCenter.default.publisher(for: .billiardPhysicsUpdate)) { _ in
                updateTrails(scaleX: scaleX, scaleY: scaleY)
            }
        }
    }

    private func updateTrails(scaleX: CGFloat, scaleY: CGFloat) {
        // Update trails for all moving balls
        for cueBall in state.cueBalls where !cueBall.isPocketed {
            trailManager.updateTrail(
                id: cueBall.id,
                position: CGPoint(x: cueBall.position.x * scaleX, y: cueBall.position.y * scaleY),
                velocity: cueBall.velocity,
                color: .white
            )
        }

        for ball in state.balls where !ball.isEliminated && !ball.isPocketed {
            trailManager.updateTrail(
                id: ball.id,
                position: CGPoint(x: ball.position.x * scaleX, y: ball.position.y * scaleY),
                velocity: ball.velocity,
                color: ball.color
            )
        }
    }
}

// MARK: - Premium Table Surface

struct PremiumTableSurface: View {
    let config: BilliardDodgeConfig
    @Environment(\.visualConfig) private var visualConfig

    var body: some View {
        ZStack {
            // Base surface with subtle variation
            SurfaceMaterial(
                width: config.tableWidth,
                height: config.tableHeight,
                baseColor: Color(white: 0.08),
                cornerRadius: 12
            )

            // Inner playing area
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(white: 0.06))
                .padding(8)

            // Premium grid overlay
            NeonGridOverlay(
                gridSize: 20,
                primaryColor: .cyan,
                secondaryColor: .purple
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(8)

            // Neon rail border with bloom
            NeonRailBorder(
                cornerRadius: 12,
                colors: [.cyan, .purple],
                metalWidth: 3,
                glowWidth: 2
            )

            // Depth fog at edges
            if visualConfig.fogEnabled {
                DepthFogGradient()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

// MARK: - Premium Pocket View

struct PremiumPocketView: View {
    let position: CGPoint
    let config: BilliardDodgeConfig
    @Environment(\.visualConfig) private var visualConfig

    @State private var pulseAnimation = false

    var body: some View {
        ZStack {
            // Danger glow (pulsing)
            if visualConfig.emissiveGlowEnabled {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.red.opacity(0.4), .orange.opacity(0.2), .clear],
                            center: .center,
                            startRadius: config.pocketRadius * 0.5,
                            endRadius: config.pocketRadius * 2.5
                        )
                    )
                    .frame(width: config.pocketRadius * 5, height: config.pocketRadius * 5)
                    .blur(radius: 8)
                    .scaleEffect(pulseAnimation ? 1.1 : 1.0)
            }

            // Pocket void
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.black, Color(white: 0.03)],
                        center: .center,
                        startRadius: 0,
                        endRadius: config.pocketRadius
                    )
                )
                .frame(width: config.pocketRadius * 2, height: config.pocketRadius * 2)

            // Pocket ring (danger color)
            EmissiveMaterial(
                color: .red,
                lineWidth: 2,
                cornerRadius: config.pocketRadius,
                pulseAnimation: true
            )
            .frame(width: config.pocketRadius * 2, height: config.pocketRadius * 2)
            .clipShape(Circle())
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
    }
}

// MARK: - Premium Ball View

struct PremiumBallView: View {
    let ball: BilliardBall
    let config: BilliardDodgeConfig
    var isCueBall: Bool = false
    var isEliminated: Bool = false
    @Environment(\.visualConfig) private var visualConfig

    var body: some View {
        ZStack {
            // Premium ball material
            PremiumBallMaterial(
                radius: config.ballRadius,
                color: isCueBall ? .white : ball.color,
                isEmissive: !isCueBall && !isEliminated,
                isCueBall: isCueBall
            )

            // Label for player balls
            if ball.playerId != nil {
                Text(ball.displayLabel)
                    .font(.system(size: config.ballRadius * 0.8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.black.opacity(0.7))
            }
        }
    }
}

// MARK: - Premium Obstacle Ball View

struct PremiumObstacleBallView: View {
    let ball: BilliardBall
    let config: BilliardDodgeConfig
    @Environment(\.visualConfig) private var visualConfig

    var body: some View {
        ZStack {
            // Subtle shadow
            if visualConfig.shadowsEnabled {
                Ellipse()
                    .fill(.black.opacity(visualConfig.shadowOpacity))
                    .frame(width: config.ballRadius * 2.2, height: config.ballRadius * 1.2)
                    .offset(x: 2, y: 4)
                    .blur(radius: visualConfig.shadowBlurRadius)
            }

            // Ball body (gray, non-emissive)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(white: 0.55), Color(white: 0.4), Color(white: 0.3)],
                        center: .init(x: 0.35, y: 0.3),
                        startRadius: 0,
                        endRadius: config.ballRadius
                    )
                )
                .frame(width: config.ballRadius * 2, height: config.ballRadius * 2)
                .shadow(color: Color.gray.opacity(0.3), radius: 3)

            // Stripe pattern
            Circle()
                .stroke(
                    Color(white: 0.35),
                    style: StrokeStyle(lineWidth: config.ballRadius * 0.3)
                )
                .frame(width: config.ballRadius * 1.2, height: config.ballRadius * 1.2)
                .rotationEffect(.degrees(45))

            // Specular highlight
            if visualConfig.specularHighlightsEnabled {
                Circle()
                    .fill(.white.opacity(0.5 * visualConfig.specularIntensity))
                    .frame(width: config.ballRadius * 0.5, height: config.ballRadius * 0.5)
                    .offset(x: -config.ballRadius * 0.3, y: -config.ballRadius * 0.3)
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

            // Draw dashed line with glow
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

            // Glow layer
            context.stroke(
                path,
                with: .color(.white.opacity(0.3)),
                style: StrokeStyle(lineWidth: 6, dash: [8, 4])
            )

            // Core line
            context.stroke(
                path,
                with: .color(.white.opacity(0.8)),
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

                context.stroke(arrowPath, with: .color(.white.opacity(0.8)), lineWidth: 2)
            }
        }
    }
}

// MARK: - CPU Shot Preview for Specific Cue Ball

struct CPUShotPreviewForCueBall: View {
    let cueBall: BilliardBall
    let shot: CPUShot
    let config: BilliardDodgeConfig
    let scaleX: CGFloat
    let scaleY: CGFloat

    var body: some View {
        let trajectory = BilliardDodgePhysics.predictTrajectory(
            from: cueBall.position,
            angle: shot.angle,
            power: shot.power,
            config: config,
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

            // Glow layer
            context.stroke(
                path,
                with: .color(.white.opacity(0.2)),
                style: StrokeStyle(lineWidth: 5, dash: [8, 4])
            )

            // Core line
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
            power: move.force * 0.7,
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

            // Glow layer for locked moves
            if move.isLocked {
                context.stroke(
                    path,
                    with: .color(ball.color.opacity(0.3)),
                    style: StrokeStyle(lineWidth: 5, dash: [4, 2])
                )
            }

            // Core line
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
    @Environment(\.visualConfig) private var config

    @State private var scale: CGFloat = 1.0
    @State private var opacity: CGFloat = 1.0

    var body: some View {
        // Only show large countdown for last 3 seconds
        if remaining <= 3 {
            ZStack {
                // Glow background
                if config.emissiveGlowEnabled {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    (remaining > 1 ? Color.white : .cyan).opacity(0.3),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .blur(radius: 20)
                }

                Text(remaining > 0 ? "\(Int(ceil(remaining)))" : "GO!")
                    .font(.system(size: 120, weight: .bold, design: .monospaced))
                    .foregroundStyle(remaining > 1 ? .white : .cyan)
                    .shadow(color: (remaining > 1 ? Color.white : .cyan).opacity(0.8), radius: 20)
                    .scaleEffect(scale)
                    .opacity(opacity)
            }
            .transition(.scale.combined(with: .opacity))
            .onChange(of: Int(ceil(remaining))) { _, _ in
                // Pulse animation on each second
                scale = 1.3
                opacity = 1.0
                withAnimation(.easeOut(duration: 0.3)) {
                    scale = 1.0
                }
            }
        }
    }
}

// MARK: - Round Result Overlay

struct BilliardDodgeResultOverlay: View {
    let message: String
    @Environment(\.visualConfig) private var config

    var body: some View {
        ZStack {
            // Background glow
            if config.emissiveGlowEnabled {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [resultColor.opacity(0.4), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 150
                        )
                    )
                    .frame(width: 300, height: 300)
                    .blur(radius: 30)
            }

            Text(message)
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundStyle(resultColor)
                .shadow(color: resultColor.opacity(0.8), radius: 15)
        }
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

// MARK: - Game Over Overlay (Enhanced)

struct BilliardDodgeGameOverOverlay: View {
    let won: Bool
    let state: BilliardDodgeState
    let onExit: () -> Void
    @Environment(\.visualConfig) private var config

    @State private var showContent = false

    var body: some View {
        ZStack {
            // Dark overlay with blur
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            // Background glow
            if config.emissiveGlowEnabled {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [(won ? Color.yellow : .red).opacity(0.3), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .blur(radius: 50)
            }

            VStack(spacing: 24) {
                // Result icon with glow
                ZStack {
                    if config.emissiveGlowEnabled {
                        Image(systemName: won ? "trophy.fill" : "xmark.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(won ? .yellow : .red)
                            .blur(radius: 20)
                            .opacity(0.5)
                    }

                    Image(systemName: won ? "trophy.fill" : "xmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(won ? .yellow : .red)
                        .shadow(color: (won ? Color.yellow : .red).opacity(0.8), radius: 15)
                }

                // Result text
                Text(won ? "SURVIVED!" : "ELIMINATED")
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundStyle(won ? .green : .red)
                    .shadow(color: (won ? Color.green : .red).opacity(0.8), radius: 10)

                // Stats with glass panel
                VStack(spacing: 8) {
                    Text("Rounds: \(state.currentRound)/\(state.totalRounds)")
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundStyle(.gray)

                    Text("Players Remaining: \(state.activePlayerCount)")
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundStyle(.gray)
                }
                .padding()
                .background(
                    GlassMaterial(cornerRadius: 12, tint: .white, opacity: 0.05)
                )

                // Exit button
                Button(action: onExit) {
                    Text("Continue")
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.black)
                        .frame(width: 200, height: 50)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(won ? Color.green : Color.purple)
                                if config.emissiveGlowEnabled {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(won ? Color.green : Color.purple)
                                        .blur(radius: 10)
                                        .opacity(0.5)
                                }
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.top, 20)
            }
            .padding(40)
            .scaleEffect(showContent ? 1 : 0.8)
            .opacity(showContent ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.5)) {
                showContent = true
            }
        }
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    /// Posted when physics updates (for trail sync)
    static let billiardPhysicsUpdate = Notification.Name("billiardPhysicsUpdate")
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
    .visualConfig(.high)
}
