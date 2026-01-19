/**
 * HordeDefense Settings View - Pre-Game Configuration
 *
 * Allows players to configure game settings before starting:
 * - Difficulty level
 * - Number of defenders (player paddles)
 * - Number of attackers (AI paddles)
 * - Number of pucks
 * - Target score
 */

import SwiftUI

// MARK: - Settings Overlay

struct HordeDefenseSettingsOverlay: View {
    let coordinator: HordeDefenseGameCoordinator

    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Title
                Text("HORDE DEFENSE")
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundStyle(.green)
                    .shadow(color: .green.opacity(0.5), radius: 10)

                Text("Configure your game")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.gray)

                Spacer()
                    .frame(height: 20)

                // Settings
                VStack(spacing: 20) {
                    // Difficulty
                    SettingsRow(label: "Difficulty") {
                        SegmentedSelector(
                            options: Difficulty.allCases,
                            selected: coordinator.state.settingsDifficulty,
                            color: .yellow
                        ) { difficulty in
                            coordinator.setDifficulty(difficulty)
                        }
                    }

                    // Defenders
                    SettingsRow(label: "Defenders") {
                        CountSelector(
                            count: coordinator.state.settingsDefenderCount,
                            range: 1...3,
                            color: .cyan
                        ) { count in
                            coordinator.setDefenderCount(count)
                        }
                    }

                    // Attackers
                    SettingsRow(label: "Attackers") {
                        CountSelector(
                            count: coordinator.state.settingsAttackerCount,
                            range: 1...3,
                            color: .pink
                        ) { count in
                            coordinator.setAttackerCount(count)
                        }
                    }

                    // Pucks
                    SettingsRow(label: "Pucks") {
                        CountSelector(
                            count: coordinator.state.settingsPuckCount,
                            range: 1...3,
                            color: .white
                        ) { count in
                            coordinator.setPuckCount(count)
                        }
                    }

                    // Target Score
                    SettingsRow(label: "Target Score") {
                        ScoreSelector(
                            score: coordinator.state.settingsTargetScore,
                            options: [5, 7, 10],
                            color: .green
                        ) { score in
                            coordinator.setTargetScore(score)
                        }
                    }
                }
                .padding(.horizontal, 20)

                Spacer()

                // Start button
                Button(action: {
                    coordinator.startFromSettings()
                }) {
                    Text("START GAME")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 60)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill(.green)
                                .shadow(color: .green.opacity(0.5), radius: 10)
                        )
                }
                .padding(.bottom, 40)
            }
            .padding(.top, 60)
        }
    }
}

// MARK: - Settings Row

private struct SettingsRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)

            Spacer()

            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.1))
        )
    }
}

// MARK: - Segmented Selector

private struct SegmentedSelector: View {
    let options: [Difficulty]
    let selected: Difficulty
    let color: Color
    let onSelect: (Difficulty) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.self) { option in
                Button(action: {
                    onSelect(option)
                }) {
                    Text(option.displayName)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(selected == option ? .black : color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selected == option ? color : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(color, lineWidth: 1)
                                )
                        )
                }
            }
        }
    }
}

// MARK: - Count Selector

private struct CountSelector: View {
    let count: Int
    let range: ClosedRange<Int>
    let color: Color
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(range), id: \.self) { value in
                Button(action: {
                    onSelect(value)
                }) {
                    Text("\(value)")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(count == value ? .black : color)
                        .frame(width: 40, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(count == value ? color : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(color, lineWidth: 1)
                                )
                        )
                }
            }
        }
    }
}

// MARK: - Score Selector

private struct ScoreSelector: View {
    let score: Int
    let options: [Int]
    let color: Color
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.self) { value in
                Button(action: {
                    onSelect(value)
                }) {
                    Text("\(value)")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(score == value ? .black : color)
                        .frame(width: 40, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(score == value ? color : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(color, lineWidth: 1)
                                )
                        )
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Settings Overlay") {
    let coordinator = HordeDefenseGameCoordinator()
    return HordeDefenseSettingsOverlay(coordinator: coordinator)
}
