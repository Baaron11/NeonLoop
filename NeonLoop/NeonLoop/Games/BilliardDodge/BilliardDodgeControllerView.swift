/**
 * BilliardDodge Controller View - Phone Input (Radial Controller)
 *
 * The input view for players on their phones.
 * Features a radial controller where:
 * - Player drags from center outward
 * - Angle of drag = direction ball will move
 * - Distance from center = force (farther = more power)
 * - Shows a preview line of the trajectory
 * - Tap to lock in, tap again to unlock
 *
 * Layout:
 * ┌─────────────────────────────────────┐
 * │  ROUND 5/12              ⏱️ 4.2s   │
 * ├─────────────────────────────────────┤
 * │     [Mini table view]               │
 * ├─────────────────────────────────────┤
 * │         [Radial Controller]         │
 * │     [LOCKED IN] or [DRAG TO AIM]    │
 * └─────────────────────────────────────┘
 */

import SwiftUI

// MARK: - Controller Area (for integrated game view)

struct BilliardDodgeControllerArea: View {
    let coordinator: BilliardDodgeGameCoordinator
    let playerId: String

    @State private var dragOffset: CGSize = .zero
    @State private var isLocked: Bool = false

    private var currentMove: PlayerMove {
        coordinator.state.playerMoves[playerId] ?? .empty
    }

    private var playerBall: BilliardBall? {
        coordinator.state.playerBall(for: playerId)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Instructions
            Text(instructionText)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(isLocked ? .green : .cyan)

            // Radial controller
            RadialController(
                offset: $dragOffset,
                isLocked: $isLocked,
                color: playerBall?.color ?? .cyan,
                isEnabled: coordinator.state.phase.isAimingPhase
            )
            .frame(width: 200, height: 200)
            .onChange(of: dragOffset) { _, newOffset in
                updateMove(from: newOffset)
            }
            .onChange(of: isLocked) { _, locked in
                if locked {
                    coordinator.lockPlayerMove(playerId: playerId)
                } else {
                    coordinator.unlockPlayerMove(playerId: playerId)
                }
            }

            // Lock status
            HStack(spacing: 8) {
                Circle()
                    .fill(isLocked ? .green : .gray)
                    .frame(width: 8, height: 8)

                Text(isLocked ? "LOCKED IN" : "TAP TO LOCK")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(isLocked ? .green : .gray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .stroke(isLocked ? .green.opacity(0.5) : .gray.opacity(0.3), lineWidth: 1)
            )
        }
    }

    private var instructionText: String {
        if !coordinator.state.phase.isAimingPhase {
            return "WAIT FOR NEXT ROUND"
        }
        if isLocked {
            return "TAP TO ADJUST"
        }
        return "DRAG TO SET ESCAPE DIRECTION"
    }

    private func updateMove(from offset: CGSize) {
        guard coordinator.state.phase.isAimingPhase, !isLocked else { return }

        let maxRadius: CGFloat = 100 // Half of controller size
        let distance = sqrt(offset.width * offset.width + offset.height * offset.height)

        if distance < 10 {
            // Too close to center, no move
            coordinator.handlePlayerMove(playerId: playerId, angle: 0, force: 0)
            return
        }

        let angle = atan2(offset.height, offset.width)
        let force = min(distance / maxRadius, 1.0)

        coordinator.handlePlayerMove(playerId: playerId, angle: angle, force: force)
    }
}

// MARK: - Radial Controller

struct RadialController: View {
    @Binding var offset: CGSize
    @Binding var isLocked: Bool
    let color: Color
    let isEnabled: Bool

    @State private var isDragging = false

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: size / 2, y: size / 2)
            let maxRadius = size / 2 - 10

            ZStack {
                // Outer ring
                Circle()
                    .stroke(color.opacity(isEnabled ? 0.3 : 0.1), lineWidth: 2)

                // Ring graduations (power levels)
                ForEach(1...3, id: \.self) { ring in
                    Circle()
                        .stroke(color.opacity(isEnabled ? 0.15 : 0.05), lineWidth: 1)
                        .frame(
                            width: size * CGFloat(ring) / 4,
                            height: size * CGFloat(ring) / 4
                        )
                }

                // Direction indicators
                ForEach(0..<8) { i in
                    let angle = CGFloat(i) * .pi / 4
                    Rectangle()
                        .fill(color.opacity(isEnabled ? 0.2 : 0.05))
                        .frame(width: 2, height: 15)
                        .offset(y: -maxRadius + 7)
                        .rotationEffect(.radians(angle))
                }

                // Arrow direction indicator (current aim)
                if offset.width != 0 || offset.height != 0 {
                    let angle = atan2(offset.height, offset.width)
                    let distance = sqrt(offset.width * offset.width + offset.height * offset.height)
                    let clampedDistance = min(distance, maxRadius)

                    // Aim line
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.8), color.opacity(0.2)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: clampedDistance, height: 3)
                        .offset(x: clampedDistance / 2, y: 0)
                        .rotationEffect(.radians(angle))

                    // Direction arrow
                    Image(systemName: "arrowtriangle.right.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(color)
                        .offset(
                            x: cos(angle) * clampedDistance,
                            y: sin(angle) * clampedDistance
                        )
                }

                // Center knob
                ZStack {
                    // Glow
                    Circle()
                        .fill(color.opacity(isDragging ? 0.4 : 0.2))
                        .frame(width: 60, height: 60)
                        .blur(radius: 8)

                    // Knob
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    color,
                                    color.opacity(0.8),
                                    color.opacity(0.6)
                                ],
                                center: .init(x: 0.3, y: 0.3),
                                startRadius: 0,
                                endRadius: 25
                            )
                        )
                        .frame(width: 50, height: 50)
                        .shadow(color: color.opacity(0.5), radius: 4)

                    // Knob highlight
                    Circle()
                        .fill(.white.opacity(0.3))
                        .frame(width: 15, height: 15)
                        .offset(x: -10, y: -10)

                    // Lock indicator
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.black.opacity(0.5))
                    }
                }
                .offset(
                    x: isLocked ? offset.width : (isDragging ? offset.width : 0),
                    y: isLocked ? offset.height : (isDragging ? offset.height : 0)
                )
            }
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard isEnabled else { return }

                        // If locked, require tap to unlock first
                        if isLocked {
                            return
                        }

                        isDragging = true
                        let translation = value.translation

                        // Clamp to circle
                        let distance = sqrt(translation.width * translation.width + translation.height * translation.height)
                        if distance > maxRadius {
                            let scale = maxRadius / distance
                            offset = CGSize(
                                width: translation.width * scale,
                                height: translation.height * scale
                            )
                        } else {
                            offset = translation
                        }
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .simultaneousGesture(
                TapGesture()
                    .onEnded {
                        guard isEnabled else { return }
                        isLocked.toggle()
                    }
            )
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.5)
    }
}

// MARK: - Standalone Controller View (for multiplayer phones)

struct BilliardDodgeControllerView: View {
    let state: BilliardDodgeState
    let playerId: String
    let onMove: (CGFloat, CGFloat) -> Void  // angle, force
    let onLock: () -> Void
    let onUnlock: () -> Void
    let onExit: () -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var isLocked: Bool = false

    private var currentPlayer: BilliardBall? {
        state.balls.first { $0.playerId == playerId }
    }

    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()

            // Grid pattern
            ControllerGridBackground()

            VStack(spacing: 0) {
                // Header
                controllerHeader
                    .padding(.top, 16)
                    .padding(.horizontal, 20)

                Spacer()

                // Mini table view
                MiniTableView(state: state, highlightPlayerId: playerId)
                    .frame(width: 280, height: 140)
                    .padding(.vertical, 20)

                Spacer()

                // Instructions
                Text(instructionText)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(isLocked ? .green : .purple)
                    .padding(.bottom, 16)

                // Radial controller
                RadialController(
                    offset: $dragOffset,
                    isLocked: $isLocked,
                    color: currentPlayer?.color ?? .purple,
                    isEnabled: state.phase.isAimingPhase
                )
                .frame(width: 200, height: 200)
                .onChange(of: dragOffset) { _, newOffset in
                    updateMove(from: newOffset)
                }
                .onChange(of: isLocked) { _, locked in
                    if locked {
                        onLock()
                    } else {
                        onUnlock()
                    }
                }

                // Lock status indicator
                lockStatusIndicator
                    .padding(.top, 16)
                    .padding(.bottom, 40)
            }

            // Countdown overlay
            if case .countdown(let remaining) = state.phase, remaining <= 3 {
                ControllerCountdownOverlay(remaining: remaining)
            }

            // Game over overlay
            if case .gameOver(let won) = state.phase {
                ControllerGameOverOverlay(won: won, onExit: onExit)
            }
        }
    }

    // MARK: - Header

    private var controllerHeader: some View {
        HStack {
            // Exit button
            Button(action: onExit) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.gray)
            }

            Spacer()

            // Round info
            VStack(spacing: 2) {
                Text("ROUND \(state.currentRound)/\(state.totalRounds)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.purple)
            }

            Spacer()

            // Timer
            if case .countdown(let remaining) = state.phase {
                Text(String(format: "%.1fs", remaining))
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(remaining < 2 ? .red : .cyan)
            } else {
                Text("--")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(.gray)
            }
        }
    }

    private var instructionText: String {
        if !state.phase.isAimingPhase {
            return "WATCH THE TABLE"
        }
        if isLocked {
            return "TAP TO ADJUST"
        }
        return "DRAG TO SET ESCAPE"
    }

    private var lockStatusIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isLocked ? .green : .gray)
                .frame(width: 8, height: 8)

            Text(isLocked ? "LOCKED IN" : "TAP TO LOCK")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(isLocked ? .green : .gray)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .stroke(isLocked ? .green.opacity(0.5) : .gray.opacity(0.3), lineWidth: 1)
        )
    }

    private func updateMove(from offset: CGSize) {
        guard state.phase.isAimingPhase, !isLocked else { return }

        let maxRadius: CGFloat = 100
        let distance = sqrt(offset.width * offset.width + offset.height * offset.height)

        if distance < 10 {
            onMove(0, 0)
            return
        }

        let angle = atan2(offset.height, offset.width)
        let force = min(distance / maxRadius, 1.0)

        onMove(angle, force)
    }
}

// MARK: - Mini Table View

struct MiniTableView: View {
    let state: BilliardDodgeState
    let highlightPlayerId: String

    var body: some View {
        let config = state.config
        let scaleX: CGFloat = 280 / config.tableWidth
        let scaleY: CGFloat = 140 / config.tableHeight

        ZStack {
            // Table background
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(white: 0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            LinearGradient(
                                colors: [.cyan.opacity(0.5), .purple.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )

            // Pockets (simplified)
            ForEach(Array(state.pockets.enumerated()), id: \.offset) { _, pocket in
                Circle()
                    .fill(.red.opacity(0.4))
                    .frame(width: 8, height: 8)
                    .position(
                        x: pocket.x * scaleX,
                        y: pocket.y * scaleY
                    )
            }

            // CPU shot line (simplified)
            if state.phase.isAimingPhase {
                let startX = state.cueBall.position.x * scaleX
                let startY = state.cueBall.position.y * scaleY
                let endX = startX + cos(state.cpuShot.angle) * 80
                let endY = startY + sin(state.cpuShot.angle) * 80

                Path { path in
                    path.move(to: CGPoint(x: startX, y: startY))
                    path.addLine(to: CGPoint(x: endX, y: endY))
                }
                .stroke(.white.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 2]))
            }

            // Cue ball
            Circle()
                .fill(.white)
                .frame(width: 8, height: 8)
                .position(
                    x: state.cueBall.position.x * scaleX,
                    y: state.cueBall.position.y * scaleY
                )

            // Player balls
            ForEach(state.balls.filter { !$0.isEliminated }) { ball in
                ZStack {
                    // Highlight for current player
                    if ball.playerId == highlightPlayerId {
                        Circle()
                            .fill(ball.color.opacity(0.3))
                            .frame(width: 16, height: 16)
                            .blur(radius: 4)
                    }

                    Circle()
                        .fill(ball.color)
                        .frame(width: 8, height: 8)
                }
                .position(
                    x: ball.position.x * scaleX,
                    y: ball.position.y * scaleY
                )
            }
        }
    }
}

// MARK: - Grid Background

private struct ControllerGridBackground: View {
    var body: some View {
        Canvas { context, size in
            let gridSize: CGFloat = 30

            for x in stride(from: 0, through: size.width, by: gridSize) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(.purple.opacity(0.05)), lineWidth: 0.5)
            }

            for y in stride(from: 0, through: size.height, by: gridSize) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(.purple.opacity(0.05)), lineWidth: 0.5)
            }
        }
    }
}

// MARK: - Controller Countdown Overlay

private struct ControllerCountdownOverlay: View {
    let remaining: Double

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("GET READY")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(.gray)
                    .tracking(4)

                Text(remaining > 0 ? "\(Int(ceil(remaining)))" : "GO!")
                    .font(.system(size: 80, weight: .bold, design: .monospaced))
                    .foregroundStyle(remaining > 0 ? .white : .green)
                    .shadow(color: (remaining > 0 ? Color.white : .green).opacity(0.8), radius: 20)
            }
        }
    }
}

// MARK: - Controller Game Over Overlay

private struct ControllerGameOverOverlay: View {
    let won: Bool
    let onExit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: won ? "trophy.fill" : "xmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(won ? .yellow : .red)
                    .shadow(color: (won ? Color.yellow : .red).opacity(0.8), radius: 15)

                Text(won ? "SURVIVED!" : "ELIMINATED")
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(won ? .green : .red)
                    .multilineTextAlignment(.center)

                Button(action: onExit) {
                    Text("Continue")
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(won ? Color.green : Color.purple)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)
            }
            .padding(40)
        }
    }
}

// MARK: - Preview

#Preview("Radial Controller") {
    struct PreviewWrapper: View {
        @State private var offset: CGSize = .zero
        @State private var isLocked = false

        var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 20) {
                    Text("Angle: \(String(format: "%.2f", atan2(offset.height, offset.width)))")
                        .foregroundStyle(.white)
                    Text("Force: \(String(format: "%.2f", sqrt(offset.width * offset.width + offset.height * offset.height) / 100))")
                        .foregroundStyle(.white)
                    Text("Locked: \(isLocked ? "YES" : "NO")")
                        .foregroundStyle(isLocked ? .green : .gray)

                    RadialController(
                        offset: $offset,
                        isLocked: $isLocked,
                        color: .cyan,
                        isEnabled: true
                    )
                    .frame(width: 200, height: 200)
                }
            }
        }
    }

    return PreviewWrapper()
}

#Preview("Controller View") {
    let state = BilliardDodgeState(playerCount: 2)
    state.setupPlayers(count: 2)
    state.phase = .countdown(remaining: 4.2)
    state.cpuShot = CPUShot(angle: 0.3, power: 0.6, targetBallId: "ball_0")

    return BilliardDodgeControllerView(
        state: state,
        playerId: "player_0",
        onMove: { _, _ in },
        onLock: {},
        onUnlock: {},
        onExit: {}
    )
}
