/**
 * HordeDefense Controller View - Phone Input
 *
 * Provides touch controls for moving paddles along the rail system:
 * - Swipe left/right: Move paddle along current rail (clockwise/counterclockwise)
 * - Swipe up/down: Switch rings at junctions (inward/outward)
 * - Mini arena view showing paddle position
 */

import SwiftUI

// MARK: - Swipe Direction

enum SwipeDirection {
    case left, right, up, down
}

// MARK: - Controller Area (Embedded in main view)

struct HordeDefenseControllerArea: View {
    let coordinator: HordeDefenseGameCoordinator

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false

    var body: some View {
        let playerId = "player_0" // First player

        VStack(spacing: 16) {
            // Mini arena preview
            HordeDefenseMiniArena(state: coordinator.state, playerId: playerId)
                .frame(height: 100)

            // Single swipe control area
            SwipeControlArea(
                onSwipe: { direction, magnitude in
                    handleSwipe(playerId: playerId, direction: direction, magnitude: magnitude)
                },
                dragOffset: $dragOffset,
                isDragging: $isDragging
            )
            .frame(height: 80)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func handleSwipe(playerId: String, direction: SwipeDirection, magnitude: CGFloat) {
        switch direction {
        case .left:
            coordinator.handlePlayerMove(playerId: playerId, direction: .counterClockwise, distance: magnitude * 5)
        case .right:
            coordinator.handlePlayerMove(playerId: playerId, direction: .clockwise, distance: magnitude * 5)
        case .up:
            coordinator.handlePlayerSwitchRing(playerId: playerId, goInward: true)
        case .down:
            coordinator.handlePlayerSwitchRing(playerId: playerId, goInward: false)
        }
    }
}

// MARK: - Swipe Control Area

struct SwipeControlArea: View {
    let onSwipe: (SwipeDirection, CGFloat) -> Void
    @Binding var dragOffset: CGSize
    @Binding var isDragging: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                    )

                // Direction indicators
                VStack {
                    Image(systemName: "chevron.up")
                        .foregroundStyle(.cyan.opacity(isDragging && dragOffset.height < -20 ? 1.0 : 0.3))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundStyle(.pink.opacity(isDragging && dragOffset.height > 20 ? 1.0 : 0.3))
                }
                .padding(.vertical, 8)

                HStack {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(.cyan.opacity(isDragging && dragOffset.width < -20 ? 1.0 : 0.3))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.cyan.opacity(isDragging && dragOffset.width > 20 ? 1.0 : 0.3))
                }
                .padding(.horizontal, 16)

                // Center indicator (shows drag position)
                Circle()
                    .fill(Color.cyan)
                    .frame(width: 20, height: 20)
                    .shadow(color: .cyan, radius: isDragging ? 8 : 4)
                    .offset(x: clampedOffset.width, y: clampedOffset.height)

                // Instruction text
                if !isDragging {
                    Text("SWIPE TO MOVE")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.gray)
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        dragOffset = value.translation

                        // Continuous movement while dragging left/right
                        let horizontalThreshold: CGFloat = 10
                        if abs(value.translation.width) > horizontalThreshold {
                            let direction: SwipeDirection = value.translation.width > 0 ? .right : .left
                            let magnitude = min(abs(value.translation.width) / 100, 1.0)
                            onSwipe(direction, magnitude)
                        }
                    }
                    .onEnded { value in
                        isDragging = false

                        // Determine primary swipe direction
                        let horizontal = abs(value.translation.width)
                        let vertical = abs(value.translation.height)
                        let threshold: CGFloat = 30

                        // Vertical swipes for ring switching (only on release)
                        if vertical > horizontal && vertical > threshold {
                            if value.translation.height < 0 {
                                onSwipe(.up, 1.0)
                            } else {
                                onSwipe(.down, 1.0)
                            }
                        }

                        // Reset offset
                        withAnimation(.spring(response: 0.3)) {
                            dragOffset = .zero
                        }
                    }
            )
        }
    }

    private var clampedOffset: CGSize {
        let maxOffset: CGFloat = 30
        return CGSize(
            width: max(-maxOffset, min(maxOffset, dragOffset.width)),
            height: max(-maxOffset, min(maxOffset, dragOffset.height))
        )
    }
}

// MARK: - Mini Arena

private struct HordeDefenseMiniArena: View {
    let state: HordeDefenseState
    let playerId: String

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let scale = size / (state.config.arenaRadius * 2)

            ZStack {
                // Outer ring (simplified)
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    .frame(width: state.config.arenaRadius * 2 * scale,
                           height: state.config.arenaRadius * 2 * scale)

                // Inner rings (simplified)
                ForEach(0..<state.config.ringRadii.count, id: \.self) { ringIndex in
                    let radius = state.config.ringRadii[ringIndex]
                    Circle()
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                        .frame(width: radius * 2 * scale, height: radius * 2 * scale)
                }

                // Spokes (simplified)
                ForEach(0..<state.config.spokeCount, id: \.self) { spokeIndex in
                    let angle = CGFloat(spokeIndex) * (2 * .pi / CGFloat(state.config.spokeCount))
                    let innerRadius = (state.config.centerGoalRadius + 10) * scale
                    let outerRadius = (state.config.ringRadii.last ?? state.config.arenaRadius) * scale
                    let center = state.config.arenaRadius * scale

                    Path { path in
                        path.move(to: CGPoint(
                            x: center + cos(angle) * innerRadius,
                            y: center + sin(angle) * innerRadius
                        ))
                        path.addLine(to: CGPoint(
                            x: center + cos(angle) * outerRadius,
                            y: center + sin(angle) * outerRadius
                        ))
                    }
                    .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                }

                // Center goal
                Circle()
                    .fill(Color.purple.opacity(0.3))
                    .frame(width: state.config.centerGoalRadius * 2 * scale,
                           height: state.config.centerGoalRadius * 2 * scale)

                // Pucks
                ForEach(state.pucks) { puck in
                    if puck.isActive {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 6, height: 6)
                            .position(
                                x: puck.position.x * scale,
                                y: puck.position.y * scale
                            )
                    }
                }

                // Player paddle (highlighted)
                if let paddle = state.getPlayerPaddle(for: playerId) {
                    let position = paddle.position.toPoint(config: state.config)
                    Circle()
                        .fill(Color.cyan)
                        .frame(width: 12, height: 12)
                        .shadow(color: .cyan, radius: 4)
                        .position(
                            x: position.x * scale,
                            y: position.y * scale
                        )
                }

                // AI paddles
                ForEach(state.aiPaddles) { paddle in
                    let position = paddle.position.toPoint(config: state.config)
                    Circle()
                        .fill(Color.pink.opacity(0.5))
                        .frame(width: 8, height: 8)
                        .position(
                            x: position.x * scale,
                            y: position.y * scale
                        )
                }
            }
            .frame(width: size, height: size)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }
}

// MARK: - Standalone Controller View (for multiplayer)

struct HordeDefenseControllerView: View {
    @Environment(GameCoordinator.self) var mainCoordinator
    let playerId: String

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false

    var body: some View {
        if let coordinator = mainCoordinator.hordeDefenseCoordinator {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    // Score display
                    HStack {
                        Text("PLAYERS: \(coordinator.state.playerScore)")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundStyle(.cyan)

                        Spacer()

                        Text("Target: \(coordinator.state.config.targetScore)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.gray)

                        Spacer()

                        Text("AI: \(coordinator.state.aiScore)")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundStyle(.pink)
                    }
                    .padding(.horizontal)

                    Spacer()

                    // Mini arena
                    HordeDefenseMiniArena(state: coordinator.state, playerId: playerId)
                        .frame(height: 200)
                        .padding(.horizontal, 40)

                    Spacer()

                    // Controls
                    VStack(spacing: 16) {
                        // Ring indicator
                        if let paddle = coordinator.state.getPlayerPaddle(for: playerId) {
                            Text("Ring \(paddle.position.ringIndex + 1) of \(coordinator.state.config.ringRadii.count)")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.gray)
                        }

                        // Single swipe control area
                        SwipeControlArea(
                            onSwipe: { direction, magnitude in
                                handleSwipe(coordinator: coordinator, direction: direction, magnitude: magnitude)
                            },
                            dragOffset: $dragOffset,
                            isDragging: $isDragging
                        )
                        .frame(height: 100)
                        .padding(.horizontal)

                        Text("Swipe left/right to move, up/down to switch rings")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.gray.opacity(0.5))
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(white: 0.1))
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
        } else {
            Color.black
                .ignoresSafeArea()
            ProgressView()
                .tint(.green)
        }
    }

    private func handleSwipe(coordinator: HordeDefenseGameCoordinator, direction: SwipeDirection, magnitude: CGFloat) {
        switch direction {
        case .left:
            coordinator.handlePlayerMove(playerId: playerId, direction: .counterClockwise, distance: magnitude * 5)
        case .right:
            coordinator.handlePlayerMove(playerId: playerId, direction: .clockwise, distance: magnitude * 5)
        case .up:
            coordinator.handlePlayerSwitchRing(playerId: playerId, goInward: true)
        case .down:
            coordinator.handlePlayerSwitchRing(playerId: playerId, goInward: false)
        }
    }
}

// MARK: - Preview

#Preview("Controller View") {
    let coordinator = GameCoordinator()
    coordinator.launchHordeDefense()
    return HordeDefenseControllerView(playerId: "player_0")
        .environment(coordinator)
}
