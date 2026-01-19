/**
 * Foosball Settings View - Pre-Game Configuration
 *
 * Allows players to configure difficulty, player count, and match format
 * before starting a game.
 */

import SwiftUI

struct FoosballSettingsView: View {
    @Bindable var coordinator: FoosballGameCoordinator
    let onStart: () -> Void

    @State private var selectedDifficulty: FoosballDifficulty
    @State private var selectedPlayerCount: Int
    @State private var selectedMatchFormat: MatchFormatOption

    init(coordinator: FoosballGameCoordinator, onStart: @escaping () -> Void) {
        self.coordinator = coordinator
        self.onStart = onStart
        self._selectedDifficulty = State(initialValue: coordinator.state.difficulty)
        self._selectedPlayerCount = State(initialValue: coordinator.state.playerCount)

        // Convert current match format to option
        let formatOption: MatchFormatOption
        switch coordinator.state.matchFormat {
        case .firstTo(let goals):
            switch goals {
            case 5: formatOption = .firstTo5
            case 7: formatOption = .firstTo7
            case 10: formatOption = .firstTo10
            default: formatOption = .firstTo5
            }
        case .timed(let seconds):
            switch Int(seconds) {
            case 180: formatOption = .timed3
            case 300: formatOption = .timed5
            case 600: formatOption = .timed10
            default: formatOption = .timed5
            }
        }
        self._selectedMatchFormat = State(initialValue: formatOption)
    }

    var body: some View {
        VStack(spacing: 30) {
            // Title
            Text("FOOSBALL")
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .foregroundStyle(.yellow)
                .shadow(color: .yellow.opacity(0.6), radius: 10)

            VStack(spacing: 24) {
                // Difficulty selection
                SettingsSection(title: "DIFFICULTY") {
                    HStack(spacing: 12) {
                        ForEach(FoosballDifficulty.allCases, id: \.self) { difficulty in
                            DifficultyButton(
                                difficulty: difficulty,
                                isSelected: selectedDifficulty == difficulty
                            ) {
                                selectedDifficulty = difficulty
                                coordinator.setDifficulty(difficulty)
                            }
                        }
                    }
                }

                // Player count selection
                SettingsSection(title: "PLAYERS") {
                    HStack(spacing: 12) {
                        ForEach(1...4, id: \.self) { count in
                            PlayerCountButton(
                                count: count,
                                isSelected: selectedPlayerCount == count
                            ) {
                                selectedPlayerCount = count
                                coordinator.setPlayerCount(count)
                            }
                        }
                    }
                }

                // Rod assignment preview
                RodAssignmentPreview(playerCount: selectedPlayerCount)

                // Match format selection
                SettingsSection(title: "MATCH FORMAT") {
                    VStack(spacing: 12) {
                        // First to X
                        HStack(spacing: 12) {
                            ForEach([MatchFormatOption.firstTo5, .firstTo7, .firstTo10], id: \.self) { option in
                                MatchFormatButton(
                                    option: option,
                                    isSelected: selectedMatchFormat == option
                                ) {
                                    selectedMatchFormat = option
                                    coordinator.setMatchFormat(option.toMatchFormat())
                                }
                            }
                        }

                        // Timed
                        HStack(spacing: 12) {
                            ForEach([MatchFormatOption.timed3, .timed5, .timed10], id: \.self) { option in
                                MatchFormatButton(
                                    option: option,
                                    isSelected: selectedMatchFormat == option
                                ) {
                                    selectedMatchFormat = option
                                    coordinator.setMatchFormat(option.toMatchFormat())
                                }
                            }
                        }
                    }
                }
            }

            Spacer()

            // Start button
            Button(action: onStart) {
                Text("START GAME")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 50)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.yellow)
                            .shadow(color: .yellow.opacity(0.5), radius: 10)
                    )
            }
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 30)
        .padding(.top, 40)
    }
}

// MARK: - Match Format Option

private enum MatchFormatOption: String, CaseIterable {
    case firstTo5 = "First to 5"
    case firstTo7 = "First to 7"
    case firstTo10 = "First to 10"
    case timed3 = "3 min"
    case timed5 = "5 min"
    case timed10 = "10 min"

    func toMatchFormat() -> MatchFormat {
        switch self {
        case .firstTo5: return .firstTo(5)
        case .firstTo7: return .firstTo(7)
        case .firstTo10: return .firstTo(10)
        case .timed3: return .timed(180)
        case .timed5: return .timed(300)
        case .timed10: return .timed(600)
        }
    }

    var shortLabel: String {
        switch self {
        case .firstTo5: return "5"
        case .firstTo7: return "7"
        case .firstTo10: return "10"
        case .timed3: return "3m"
        case .timed5: return "5m"
        case .timed10: return "10m"
        }
    }

    var isTimed: Bool {
        switch self {
        case .timed3, .timed5, .timed10: return true
        default: return false
        }
    }
}

// MARK: - Settings Section

private struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.gray)
                .tracking(2)

            content
        }
    }
}

// MARK: - Difficulty Button

private struct DifficultyButton: View {
    let difficulty: FoosballDifficulty
    let isSelected: Bool
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
            Text(difficulty.displayName)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(isSelected ? .black : color)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? color : .clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(color, lineWidth: 2)
                        )
                )
        }
    }
}

// MARK: - Player Count Button

private struct PlayerCountButton: View {
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(count)")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(isSelected ? .black : .cyan)
                .frame(width: 50, height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? .cyan : .clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(.cyan, lineWidth: 2)
                        )
                )
        }
    }
}

// MARK: - Match Format Button

private struct MatchFormatButton: View {
    let option: MatchFormatOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(option.shortLabel)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                Text(option.isTimed ? "timed" : "goals")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
            }
            .foregroundStyle(isSelected ? .black : .white)
            .frame(width: 60, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? .yellow : .clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.yellow.opacity(0.6), lineWidth: isSelected ? 0 : 2)
                    )
            )
        }
    }
}

// MARK: - Rod Assignment Preview

private struct RodAssignmentPreview: View {
    let playerCount: Int

    private var assignments: [(player: String, rods: String)] {
        switch playerCount {
        case 1:
            return [("P1", "All rods (linked)")]
        case 2:
            return [
                ("P1", "Goalie + Defense"),
                ("P2", "Midfield + Attack")
            ]
        case 3:
            return [
                ("P1", "Goalie"),
                ("P2", "Defense + Midfield"),
                ("P3", "Attack")
            ]
        case 4:
            return [
                ("P1", "Goalie"),
                ("P2", "Defense"),
                ("P3", "Midfield"),
                ("P4", "Attack")
            ]
        default:
            return []
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("ROD ASSIGNMENT")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.gray)
                .tracking(2)

            HStack(spacing: 16) {
                ForEach(Array(assignments.enumerated()), id: \.offset) { index, assignment in
                    VStack(spacing: 4) {
                        Text(assignment.player)
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(playerColor(index))

                        Text(assignment.rods)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(white: 0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(.gray.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }

    private func playerColor(_ index: Int) -> Color {
        switch index {
        case 0: return .cyan
        case 1: return .pink
        case 2: return .green
        case 3: return .orange
        default: return .gray
        }
    }
}

// MARK: - Preview

#Preview("Foosball Settings") {
    ZStack {
        Color.black.ignoresSafeArea()
        FoosballSettingsView(
            coordinator: FoosballGameCoordinator(),
            onStart: {}
        )
    }
}
