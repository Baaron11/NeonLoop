/**
 * HordeDefense Controller View - Phone Input
 *
 * Provides touch controls for moving paddles along the rail system:
 * - Horizontal slider for moving along current rail (clockwise/counterclockwise)
 * - Up/Down buttons at junctions for switching rings
 * - Mini arena view showing paddle position
 */

import SwiftUI

// MARK: - Controller Area (Embedded in main view)

struct HordeDefenseControllerArea: View {
    let coordinator: HordeDefenseGameCoordinator

    var body: some View {
        let playerId = "player_0" // First player

        VStack(spacing: 16) {
            // Mini arena preview
            HordeDefenseMiniArena(state: coordinator.state, playerId: playerId)
                .frame(height: 80)

            // Control slider and ring switch buttons
            HStack(spacing: 20) {
                // Inward button
                RingSwitchButton(
                    direction: .inward,
                    isEnabled: canSwitchRing(playerId: playerId, goInward: true),
                    action: {
                        coordinator.handlePlayerSwitchRing(playerId: playerId, goInward: true)
                    }
                )

                // Movement slider
                RailSlider(
                    coordinator: coordinator,
                    playerId: playerId
                )

                // Outward button
                RingSwitchButton(
                    direction: .outward,
                    isEnabled: canSwitchRing(playerId: playerId, goInward: false),
                    action: {
                        coordinator.handlePlayerSwitchRing(playerId: playerId, goInward: false)
                    }
                )
            }
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

    private func canSwitchRing(playerId: String, goInward: Bool) -> Bool {
        guard let paddle = coordinator.state.getPlayerPaddle(for: playerId) else { return false }
        guard paddle.position.isAtJunction(config: coordinator.state.config) else { return false }

        if goInward {
            return paddle.position.ringIndex > 0
        } else {
            return paddle.position.ringIndex < coordinator.state.config.ringRadii.count - 1
        }
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

// MARK: - Rail Slider

private struct RailSlider: View {
    let coordinator: HordeDefenseGameCoordinator
    let playerId: String

    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false

    private let sliderWidth: CGFloat = 200
    private let moveSpeed: CGFloat = 4.0

    var body: some View {
        ZStack {
            // Track
            Capsule()
                .fill(Color(white: 0.15))
                .frame(width: sliderWidth, height: 40)
                .overlay(
                    Capsule()
                        .stroke(Color.cyan.opacity(0.5), lineWidth: 2)
                )

            // Direction indicators
            HStack {
                Image(systemName: "chevron.left")
                    .foregroundStyle(.cyan.opacity(isDragging && dragOffset < 0 ? 1 : 0.3))
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.cyan.opacity(isDragging && dragOffset > 0 ? 1 : 0.3))
            }
            .font(.system(size: 16, weight: .bold))
            .padding(.horizontal, 12)
            .frame(width: sliderWidth)

            // Knob
            Circle()
                .fill(Color.cyan)
                .frame(width: 30, height: 30)
                .shadow(color: .cyan.opacity(0.5), radius: 8)
                .offset(x: clampedOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            isDragging = true
                            dragOffset = value.translation.width

                            // Move paddle based on drag direction
                            let direction: RailDirection = dragOffset > 0 ? .clockwise : .counterClockwise
                            let distance = abs(dragOffset) / 50 * moveSpeed
                            coordinator.handlePlayerMove(playerId: playerId, direction: direction, distance: distance)
                        }
                        .onEnded { _ in
                            isDragging = false
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                dragOffset = 0
                            }
                        }
                )
        }
    }

    private var clampedOffset: CGFloat {
        let maxOffset = sliderWidth / 2 - 20
        return max(-maxOffset, min(maxOffset, dragOffset * 0.3))
    }
}

// MARK: - Ring Switch Button

private struct RingSwitchButton: View {
    let direction: RailDirection
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: direction == .inward ? "arrow.up" : "arrow.down")
                    .font(.system(size: 20, weight: .bold))

                Text(direction == .inward ? "IN" : "OUT")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(isEnabled ? .cyan : .gray.opacity(0.3))
            .frame(width: 50, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: 0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isEnabled ? Color.cyan.opacity(0.5) : Color.gray.opacity(0.2), lineWidth: 2)
                    )
            )
        }
        .disabled(!isEnabled)
    }
}

// MARK: - Standalone Controller View (for multiplayer)

struct HordeDefenseControllerView: View {
    @Environment(GameCoordinator.self) var mainCoordinator
    let playerId: String

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

                        // Control slider and ring switch buttons
                        HStack(spacing: 20) {
                            RingSwitchButton(
                                direction: .inward,
                                isEnabled: canSwitchRing(goInward: true, coordinator: coordinator),
                                action: {
                                    coordinator.handlePlayerSwitchRing(playerId: playerId, goInward: true)
                                }
                            )

                            RailSlider(
                                coordinator: coordinator,
                                playerId: playerId
                            )

                            RingSwitchButton(
                                direction: .outward,
                                isEnabled: canSwitchRing(goInward: false, coordinator: coordinator),
                                action: {
                                    coordinator.handlePlayerSwitchRing(playerId: playerId, goInward: false)
                                }
                            )
                        }

                        Text("Drag to move along rail")
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

    private func canSwitchRing(goInward: Bool, coordinator: HordeDefenseGameCoordinator) -> Bool {
        guard let paddle = coordinator.state.getPlayerPaddle(for: playerId) else { return false }
        guard paddle.position.isAtJunction(config: coordinator.state.config) else { return false }

        if goInward {
            return paddle.position.ringIndex > 0
        } else {
            return paddle.position.ringIndex < coordinator.state.config.ringRadii.count - 1
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
