/**
 * Game Launcher View - Main Game Selection Menu
 *
 * Displays all available NeonLoop mini-games as selectable cards.
 * Shows which games are playable vs placeholder (coming soon).
 */

import SwiftUI

struct GameLauncherView: View {
    @Environment(GameCoordinator.self) var coordinator
    @State private var selectedGame: GameInfo?
    @State private var showDifficultySheet = false

    private let games = NeonLoopGameRegistry.allGames

    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()

            // Grid pattern
            GridBackground()

            VStack(spacing: 0) {
                // Header
                LauncherHeader()
                    .padding(.top, 20)
                    .padding(.bottom, 24)

                // Game Grid
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Multiplayer button at top
                        MultiplayerButton {
                            coordinator.goToLobby()
                        }
                        .padding(.horizontal, 20)

                        // Game grid
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 16),
                                GridItem(.flexible(), spacing: 16)
                            ],
                            spacing: 16
                        ) {
                            ForEach(games) { game in
                                GameCard(game: game) {
                                    handleGameSelection(game)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .sheet(isPresented: $showDifficultySheet) {
            if let game = selectedGame {
                GameDifficultySheet(game: game) { difficulty in
                    print("🎯 [GameLauncherView] Difficulty selected: \(difficulty) for \(game.id)")
                    showDifficultySheet = false
                    // Add a small delay to ensure the sheet dismissal animation completes
                    // before navigating. This prevents SwiftUI view hierarchy issues.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        print("🎯 [GameLauncherView] Launching game after delay")
                        launchGame(game, difficulty: difficulty)
                    }
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private func handleGameSelection(_ game: GameInfo) {
        if game.isImplemented {
            selectedGame = game
            showDifficultySheet = true
        } else {
            // Launch placeholder view for unimplemented games
            coordinator.launchPlaceholderGame(game)
        }
    }

    private func launchGame(_ game: GameInfo, difficulty: Difficulty) {
        switch game.id {
        case "polygon_hockey":
            coordinator.startSinglePlayerGame(difficulty: difficulty)
        case "tilt_table":
            coordinator.launchTiltTable()
        default:
            // Future: Launch specific games with their own coordinators
            coordinator.startSinglePlayerGame(difficulty: difficulty)
        }
    }
}

// MARK: - Launcher Header

private struct LauncherHeader: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("NEONLOOP")
                .font(.system(size: 42, weight: .bold, design: .monospaced))
                .foregroundStyle(.cyan)
                .shadow(color: .cyan.opacity(0.8), radius: 10)
                .shadow(color: .cyan.opacity(0.5), radius: 20)

            Text("SELECT YOUR GAME")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.gray)
                .tracking(6)
        }
    }
}

// MARK: - Game Card

private struct GameCard: View {
    let game: GameInfo
    let onTap: () -> Void

    @State private var isPressed = false
    @State private var glowAnimation = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Icon
                ZStack {
                    // Glow background
                    Circle()
                        .fill(game.accentColor.opacity(game.isImplemented ? 0.2 : 0.08))
                        .blur(radius: 10)
                        .scaleEffect(glowAnimation && game.isImplemented ? 1.2 : 1.0)

                    // Icon circle
                    Circle()
                        .stroke(game.accentColor.opacity(game.isImplemented ? 0.6 : 0.3), lineWidth: 2)
                        .frame(width: 50, height: 50)

                    Image(systemName: game.iconName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(game.accentColor.opacity(game.isImplemented ? 1.0 : 0.4))
                }
                .frame(width: 60, height: 60)

                // Game name
                Text(game.name)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(game.isImplemented ? .white : .gray)
                    .lineLimit(1)

                // Subtitle
                Text(game.subtitle)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(game.accentColor.opacity(game.isImplemented ? 0.8 : 0.4))
                    .lineLimit(1)

                // Status badge
                StatusBadge(isImplemented: game.isImplemented, color: game.accentColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(white: 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                game.accentColor.opacity(game.isImplemented ? 0.4 : 0.15),
                                lineWidth: game.isImplemented ? 2 : 1
                            )
                    )
            )
            .shadow(color: game.accentColor.opacity(game.isImplemented ? 0.3 : 0.1), radius: 8)
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .onAppear {
            if game.isImplemented {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    glowAnimation = true
                }
            }
        }
    }
}

// MARK: - Status Badge

private struct StatusBadge: View {
    let isImplemented: Bool
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isImplemented ? .green : .orange)
                .frame(width: 6, height: 6)

            Text(isImplemented ? "READY" : "COMING SOON")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(isImplemented ? .green : .orange.opacity(0.8))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill((isImplemented ? Color.green : Color.orange).opacity(0.15))
        )
    }
}

// MARK: - Game Difficulty Sheet

private struct GameDifficultySheet: View {
    let game: GameInfo
    let onSelect: (Difficulty) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Game info header
                VStack(spacing: 8) {
                    Image(systemName: game.iconName)
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(game.accentColor)
                        .shadow(color: game.accentColor.opacity(0.5), radius: 10)

                    Text(game.name)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)

                    Text(game.description)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Player count
                HStack(spacing: 16) {
                    PlayerCountBadge(
                        label: "MIN",
                        count: game.minPlayers,
                        color: game.accentColor
                    )
                    PlayerCountBadge(
                        label: "MAX",
                        count: game.maxPlayers,
                        color: game.accentColor
                    )
                }

                // Difficulty buttons
                VStack(spacing: 12) {
                    ForEach(Difficulty.allCases, id: \.self) { difficulty in
                        DifficultyOptionButton(
                            difficulty: difficulty,
                            accentColor: game.accentColor
                        ) {
                            onSelect(difficulty)
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle("Start Game")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct PlayerCountBadge: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundStyle(color)

            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.gray)
        }
        .frame(width: 60)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

private struct DifficultyOptionButton: View {
    let difficulty: Difficulty
    let accentColor: Color
    let action: () -> Void

    private var difficultyColor: Color {
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
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))

                Spacer()

                // Difficulty indicator dots
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(index < difficultyLevel ? difficultyColor : difficultyColor.opacity(0.2))
                            .frame(width: 8, height: 8)
                    }
                }
            }
            .foregroundStyle(difficultyColor)
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(difficultyColor, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var difficultyLevel: Int {
        switch difficulty {
        case .easy: return 1
        case .medium: return 2
        case .hard: return 3
        }
    }
}

// MARK: - Multiplayer Button

private struct MultiplayerButton: View {
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "wifi")
                    .font(.system(size: 20, weight: .semibold))

                Text("Multiplayer Lobby")
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.pink.opacity(0.6))
            }
            .foregroundStyle(.pink)
            .padding(.horizontal, 20)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.pink.opacity(0.4), lineWidth: 2)
                    )
            )
            .shadow(color: .pink.opacity(0.3), radius: 8)
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

// MARK: - Preview

#Preview {
    GameLauncherView()
        .environment(GameCoordinator())
}
