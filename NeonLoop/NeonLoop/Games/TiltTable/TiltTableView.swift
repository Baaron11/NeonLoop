/**
 * TiltTable View - TV Display View
 *
 * The main visual display for the Tilt Table game.
 * Shows the circular table from above with:
 * - The metal ball rolling based on tilt
 * - Player avatars positioned around the ring
 * - Holes labeled with game/modifier names
 * - Visual feedback for tilt direction and intensity
 */

import SwiftUI

struct TiltTableView: View {
    let state: TiltTableState
    let onExit: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let scale = size / (state.config.tableRadius * 2.5)  // Leave margin

            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()

                // Grid pattern
                TiltTableGridBackground()

                // Game content centered
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

                    // Countdown overlay
                    if case .countdown(let count) = state.phase {
                        CountdownOverlay(count: count)
                    }

                    // Ball falling animation
                    if case .ballFalling(let holeId) = state.phase {
                        BallFallingOverlay(holeId: holeId, holes: state.holes)
                    }

                    // Game complete overlay
                    if case .complete = state.phase, let result = state.result {
                        GameCompleteOverlay(result: result, onExit: onExit)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)

                // Exit button
                VStack {
                    HStack {
                        Button(action: onExit) {
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
        }
    }
}

// MARK: - Grid Background

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

// MARK: - Tilt Shadow View

struct TiltShadowView: View {
    let tilt: CGVector
    let config: TiltTableConfig

    var body: some View {
        // Show tilt direction as a gradient shadow
        let tiltMagnitude = tilt.magnitude
        let tiltAngle = atan2(tilt.dy, tilt.dx)

        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        .clear,
                        .pink.opacity(Double(tiltMagnitude) * 0.3)
                    ],
                    center: UnitPoint(
                        x: 0.5 - Double(tilt.dx) * 0.3,
                        y: 0.5 - Double(tilt.dy) * 0.3
                    ),
                    startRadius: 0,
                    endRadius: config.tableRadius
                )
            )
            .frame(width: config.tableRadius * 2, height: config.tableRadius * 2)
    }
}

// MARK: - Table Surface View

struct TableSurfaceView: View {
    let config: TiltTableConfig

    var body: some View {
        ZStack {
            // Outer ring glow
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.pink.opacity(0.5), .cyan.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 4
                )
                .frame(width: config.tableRadius * 2, height: config.tableRadius * 2)
                .blur(radius: 4)

            // Table surface
            Circle()
                .fill(Color(white: 0.08))
                .frame(width: config.tableRadius * 2, height: config.tableRadius * 2)

            // Table border
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.pink, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .frame(width: config.tableRadius * 2, height: config.tableRadius * 2)

            // Subtle grid pattern on table
            TableGridPattern(radius: config.tableRadius)

            // Center dot
            Circle()
                .fill(.gray.opacity(0.3))
                .frame(width: 8, height: 8)
        }
    }
}

struct TableGridPattern: View {
    let radius: CGFloat

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let gridSize: CGFloat = 30

            context.clip(to: Path(ellipseIn: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )))

            // Concentric circles
            for r in stride(from: gridSize, through: radius, by: gridSize) {
                var path = Path()
                path.addEllipse(in: CGRect(
                    x: center.x - r,
                    y: center.y - r,
                    width: r * 2,
                    height: r * 2
                ))
                context.stroke(path, with: .color(.cyan.opacity(0.1)), lineWidth: 0.5)
            }

            // Radial lines
            for angle in stride(from: 0.0, to: Double.pi * 2, by: Double.pi / 6) {
                var path = Path()
                path.move(to: center)
                path.addLine(to: CGPoint(
                    x: center.x + cos(angle) * radius,
                    y: center.y + sin(angle) * radius
                ))
                context.stroke(path, with: .color(.cyan.opacity(0.1)), lineWidth: 0.5)
            }
        }
        .frame(width: radius * 2, height: radius * 2)
    }
}

// MARK: - Hole View

struct HoleView: View {
    let hole: TiltTableHole
    let config: TiltTableConfig
    let ball: TiltTableBall

    @State private var pulseAnimation = false

    private var isNearby: Bool {
        let holePos = hole.position(config: config)
        return ball.position.distance(to: holePos) < config.holeCaptureRadius
    }

    // Calculate the angle for positioning the label towards the center
    private var labelAngle: CGFloat {
        hole.angle + .pi  // Point label towards table center
    }

    var body: some View {
        let pos = hole.position(config: config)

        ZStack {
            // Outer glow when ball is nearby
            if isNearby && !hole.isPlugged {
                Circle()
                    .fill(hole.holeType.color.opacity(0.4))
                    .frame(width: config.holeRadius * 3, height: config.holeRadius * 3)
                    .blur(radius: 10)
                    .scaleEffect(pulseAnimation ? 1.3 : 1.0)
            }

            // Hole depth effect (darker inner)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.black.opacity(0.8),
                            hole.isPlugged ? Color.gray.opacity(0.2) : hole.holeType.color.opacity(0.3)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: config.holeRadius
                    )
                )
                .frame(width: config.holeRadius * 2, height: config.holeRadius * 2)

            // Hole ring (border)
            Circle()
                .stroke(
                    hole.isPlugged ? .gray.opacity(0.4) : hole.holeType.color,
                    lineWidth: hole.isPlugged ? 1 : 3
                )
                .frame(width: config.holeRadius * 2, height: config.holeRadius * 2)
                .shadow(color: hole.isPlugged ? .clear : hole.holeType.color.opacity(0.5), radius: 4)

            // X mark for plugged holes
            if hole.isPlugged {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.gray.opacity(0.6))
            }

            // Label (positioned towards table center, inside the table)
            Text(hole.label)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(hole.isPlugged ? .gray.opacity(0.4) : .white.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .offset(
                    x: cos(labelAngle) * (config.holeRadius + 16),
                    y: sin(labelAngle) * (config.holeRadius + 16)
                )
        }
        .position(x: pos.x, y: pos.y)
        .offset(x: config.tableRadius, y: config.tableRadius)  // Center in parent
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
    }
}

// MARK: - Player Avatar View

struct PlayerAvatarView: View {
    let player: TiltTablePlayer
    let config: TiltTableConfig

    var body: some View {
        let pos = player.position(config: config)

        ZStack {
            // Outer glow
            Circle()
                .fill(player.color.opacity(0.3))
                .frame(
                    width: config.playerAvatarRadius * 2.5,
                    height: config.playerAvatarRadius * 2.5
                )
                .blur(radius: 6)

            // Avatar circle
            Circle()
                .fill(player.color)
                .frame(
                    width: config.playerAvatarRadius * 2,
                    height: config.playerAvatarRadius * 2
                )

            // Player number
            Text("P\(player.displayNumber)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.black)
        }
        .position(x: pos.x, y: pos.y)
        .offset(x: config.tableRadius, y: config.tableRadius)
    }
}

// MARK: - Ball View

struct BallView: View {
    let ball: TiltTableBall
    let config: TiltTableConfig

    var body: some View {
        ZStack {
            // Outer glow (cyan tint for neon effect)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .cyan.opacity(0.4),
                            .cyan.opacity(0.2),
                            .clear
                        ],
                        center: .center,
                        startRadius: config.ballRadius * 0.8,
                        endRadius: config.ballRadius * 2.5
                    )
                )
                .frame(width: config.ballRadius * 5, height: config.ballRadius * 5)
                .blur(radius: 6)

            // Shadow underneath the ball
            Ellipse()
                .fill(.black.opacity(0.5))
                .frame(width: config.ballRadius * 2.2, height: config.ballRadius * 1.2)
                .offset(x: 3, y: 6)
                .blur(radius: 4)

            // Ball body (chrome/metallic look with better contrast)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(white: 0.95),      // Bright center
                            Color(white: 0.85),
                            Color(white: 0.7),
                            Color(white: 0.5),       // Darker edge for 3D effect
                            Color(white: 0.4)
                        ],
                        center: .init(x: 0.35, y: 0.3),
                        startRadius: 0,
                        endRadius: config.ballRadius
                    )
                )
                .frame(width: config.ballRadius * 2, height: config.ballRadius * 2)
                .shadow(color: .cyan.opacity(0.6), radius: 8)

            // Metallic ring highlight
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.5), .clear, .white.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: config.ballRadius * 1.8, height: config.ballRadius * 1.8)

            // Primary specular highlight (bright spot)
            Circle()
                .fill(.white.opacity(0.9))
                .frame(width: config.ballRadius * 0.5, height: config.ballRadius * 0.5)
                .offset(x: -config.ballRadius * 0.35, y: -config.ballRadius * 0.35)

            // Secondary highlight (smaller)
            Circle()
                .fill(.white.opacity(0.4))
                .frame(width: config.ballRadius * 0.25, height: config.ballRadius * 0.25)
                .offset(x: config.ballRadius * 0.25, y: config.ballRadius * 0.3)
        }
        .position(x: ball.position.x, y: ball.position.y)
        .offset(x: config.tableRadius, y: config.tableRadius)
    }
}

// MARK: - Countdown Overlay

struct CountdownOverlay: View {
    let count: Int
    @State private var scale: CGFloat = 2.0
    @State private var opacity: Double = 0

    var body: some View {
        Text(count > 0 ? "\(count)" : "GO!")
            .font(.system(size: 120, weight: .bold, design: .monospaced))
            .foregroundStyle(count > 0 ? .white : .cyan)
            .shadow(color: (count > 0 ? Color.white : .cyan).opacity(0.8), radius: 20)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                scale = 2.0
                opacity = 0
                withAnimation(.easeOut(duration: 0.3)) {
                    scale = 1.0
                    opacity = 1.0
                }
            }
            .onChange(of: count) { _, newValue in
                scale = 2.0
                opacity = 0
                withAnimation(.easeOut(duration: 0.3)) {
                    scale = 1.0
                    opacity = 1.0
                }
            }
    }
}

// MARK: - Ball Falling Overlay

struct BallFallingOverlay: View {
    let holeId: String
    let holes: [TiltTableHole]

    private var selectedHole: TiltTableHole? {
        holes.first { $0.id == holeId }
    }

    var body: some View {
        if let hole = selectedHole {
            VStack(spacing: 16) {
                Text(hole.label.uppercased())
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundStyle(hole.holeType.color)
                    .shadow(color: hole.holeType.color.opacity(0.8), radius: 10)
            }
            .transition(.scale.combined(with: .opacity))
        }
    }
}

// MARK: - Game Complete Overlay

struct GameCompleteOverlay: View {
    let result: TiltTableHole
    let onExit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("SELECTED")
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundStyle(.gray)
                    .tracking(4)

                Text(result.label.uppercased())
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundStyle(result.holeType.color)
                    .shadow(color: result.holeType.color.opacity(0.8), radius: 15)
                    .multilineTextAlignment(.center)

                typeLabel

                Button(action: onExit) {
                    Text("Continue")
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.black)
                        .frame(width: 200, height: 50)
                        .background(result.holeType.color)
                        .cornerRadius(12)
                }
                .padding(.top, 20)
            }
            .padding(40)
        }
    }

    private var typeLabel: some View {
        HStack(spacing: 8) {
            Image(systemName: typeIcon)
            Text(typeText)
        }
        .font(.system(size: 14, weight: .medium, design: .monospaced))
        .foregroundStyle(result.holeType.color.opacity(0.8))
    }

    private var typeIcon: String {
        switch result.holeType {
        case .game: return "gamecontroller.fill"
        case .goodModifier: return "plus.circle.fill"
        case .badModifier: return "minus.circle.fill"
        }
    }

    private var typeText: String {
        switch result.holeType {
        case .game: return "NEXT GAME"
        case .goodModifier: return "BONUS"
        case .badModifier: return "PENALTY"
        }
    }
}

// MARK: - Preview

#Preview {
    let state = TiltTableState()
    state.setupPlayers(count: 3)
    state.phase = .playing
    state.ball.position = CGPoint(x: 30, y: -20)

    return TiltTableView(state: state, onExit: {})
}
