/**
 * Home View - Main Menu
 *
 * The first screen users see when launching the app.
 * Provides options to start single player or multiplayer games.
 */

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var coordinator: GameCoordinator
    @State private var selectedMode: GameMode = .oneVsOne
    @State private var selectedDifficulty: Difficulty = .medium
    @State private var showModeSheet = false
    @State private var showDifficultySheet = false

    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()

            // Grid pattern
            GridBackground()

            VStack(spacing: 40) {
                Spacer()

                // Title
                VStack(spacing: 8) {
                    Text("NEONLOOP")
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundStyle(.cyan)
                        .shadow(color: .cyan.opacity(0.8), radius: 10)
                        .shadow(color: .cyan.opacity(0.5), radius: 20)

                    Text("AIR HOCKEY ARENA")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(.gray)
                        .tracking(4)
                }

                // Animated puck
                AnimatedPuck()
                    .frame(width: 80, height: 80)

                Spacer()

                // Menu buttons
                VStack(spacing: 16) {
                    // Single Player
                    MenuButton(
                        title: "Single Player",
                        icon: "cpu",
                        color: .cyan
                    ) {
                        showDifficultySheet = true
                    }

                    // Multiplayer
                    MenuButton(
                        title: "Multiplayer",
                        icon: "wifi",
                        color: .pink
                    ) {
                        coordinator.goToLobby()
                    }
                }
                .padding(.horizontal, 40)

                Spacer()

                // Footer
                Text("Touch or tilt to control")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.gray.opacity(0.5))
                    .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $showDifficultySheet) {
            DifficultySelectionView { difficulty in
                showDifficultySheet = false
                coordinator.startSinglePlayerGame(difficulty: difficulty, mode: selectedMode)
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Menu Button

struct MenuButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))

                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
            }
            .foregroundStyle(isPressed ? color.opacity(0.7) : color)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color, lineWidth: 2)
                    .shadow(color: color.opacity(0.5), radius: 8)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Difficulty Selection

struct DifficultySelectionView: View {
    let onSelect: (Difficulty) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                ForEach(Difficulty.allCases, id: \.self) { difficulty in
                    DifficultyButton(difficulty: difficulty) {
                        onSelect(difficulty)
                    }
                }
            }
            .padding()
            .navigationTitle("Select Difficulty")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct DifficultyButton: View {
    let difficulty: Difficulty
    let action: () -> Void

    private var color: Color {
        switch difficulty {
        case .easy: return .green
        case .medium: return .yellow
        case .hard: return .red
        }
    }

    var body: some View {
        Button(action: action) {
            HStack {
                Text(difficulty.displayName)
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))

                Spacer()

                Image(systemName: "bolt.fill")
                    .opacity(difficulty == .hard ? 1 : difficulty == .medium ? 0.6 : 0.3)
            }
            .foregroundStyle(color)
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Animated Puck

struct AnimatedPuck: View {
    @State private var glowIntensity: Double = 0.5

    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(.cyan.opacity(0.2 * glowIntensity))
                .blur(radius: 20)

            // Middle ring
            Circle()
                .fill(.cyan.opacity(0.4 * glowIntensity))
                .padding(8)

            // Inner puck
            Circle()
                .fill(.cyan)
                .padding(16)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowIntensity = 1.0
            }
        }
    }
}

// MARK: - Grid Background

struct GridBackground: View {
    var body: some View {
        Canvas { context, size in
            let gridSize: CGFloat = 40
            let lineWidth: CGFloat = 0.5

            // Vertical lines
            for x in stride(from: 0, through: size.width, by: gridSize) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(.cyan.opacity(0.1)), lineWidth: lineWidth)
            }

            // Horizontal lines
            for y in stride(from: 0, through: size.height, by: gridSize) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(.cyan.opacity(0.1)), lineWidth: lineWidth)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    HomeView()
        .environmentObject(GameCoordinator())
}
