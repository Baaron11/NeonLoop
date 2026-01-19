/**
 * BilliardDodge Settings View - Game Configuration UI
 *
 * Allows players to customize game settings:
 * - Number of cue balls (1-3)
 * - Number of obstacle balls (0-5)
 * - Visual quality (Low/Medium/High)
 */

import SwiftUI

// MARK: - Settings View

struct BilliardDodgeSettingsView: View {
    @Binding var cueBallCount: Int
    @Binding var obstacleBallCount: Int
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Visual Quality Setting
                        VisualQualitySection()

                        // Cue Ball Count Setting
                        SettingSection(
                            title: "CUE BALLS",
                            subtitle: "Number of cue balls the CPU controls",
                            value: $cueBallCount,
                            range: 1...3,
                            color: .white
                        )

                        // Obstacle Ball Count Setting
                        SettingSection(
                            title: "OBSTACLES",
                            subtitle: "Static balls that get in the way",
                            value: $obstacleBallCount,
                            range: 0...5,
                            color: Color(white: 0.5)
                        )

                        // Preview Section
                        SettingsPreview(
                            cueBallCount: cueBallCount,
                            obstacleBallCount: obstacleBallCount
                        )

                        Spacer(minLength: 40)
                    }
                    .padding(.top, 24)
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("Game Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDismiss()
                    }
                    .foregroundStyle(.purple)
                }
            }
        }
    }
}

// MARK: - Visual Quality Section

private struct VisualQualitySection: View {
    @State private var selectedQuality: VisualQuality = VisualSettings.shared.quality

    var body: some View {
        VStack(spacing: 12) {
            // Header
            VStack(spacing: 4) {
                Text("VISUAL QUALITY")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .tracking(2)

                Text("Higher quality uses more GPU power")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.gray)
            }

            // Quality options
            HStack(spacing: 12) {
                ForEach(VisualQuality.allCases) { quality in
                    QualityOptionButton(
                        quality: quality,
                        isSelected: selectedQuality == quality
                    ) {
                        selectedQuality = quality
                        VisualSettings.shared.quality = quality
                    }
                }
            }

            // Effect indicators
            VStack(spacing: 6) {
                QualityEffectRow(label: "Bloom", enabledAt: [.low, .medium, .high], current: selectedQuality)
                QualityEffectRow(label: "Vignette", enabledAt: [.low, .medium, .high], current: selectedQuality)
                QualityEffectRow(label: "Film Grain", enabledAt: [.medium, .high], current: selectedQuality)
                QualityEffectRow(label: "Motion Trails", enabledAt: [.low, .medium, .high], current: selectedQuality)
                QualityEffectRow(label: "Impact FX", enabledAt: [.medium, .high], current: selectedQuality)
                QualityEffectRow(label: "Motion Blur", enabledAt: [.high], current: selectedQuality)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [.cyan.opacity(0.4), .purple.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - Quality Option Button

private struct QualityOptionButton: View {
    let quality: VisualQuality
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: qualityIcon)
                    .font(.system(size: 20))
                    .foregroundStyle(qualityColor)

                Text(quality.rawValue)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(isSelected ? .white : .gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? qualityColor.opacity(0.2) : Color(white: 0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? qualityColor : Color.clear, lineWidth: 2)
                    )
            )
        }
    }

    private var qualityIcon: String {
        switch quality {
        case .low: return "bolt"
        case .medium: return "sparkles"
        case .high: return "wand.and.stars"
        }
    }

    private var qualityColor: Color {
        switch quality {
        case .low: return .green
        case .medium: return .cyan
        case .high: return .purple
        }
    }
}

// MARK: - Quality Effect Row

private struct QualityEffectRow: View {
    let label: String
    let enabledAt: [VisualQuality]
    let current: VisualQuality

    var body: some View {
        let isEnabled = enabledAt.contains(current)

        HStack {
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(isEnabled ? .white.opacity(0.8) : .gray.opacity(0.5))

            Spacer()

            Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 12))
                .foregroundStyle(isEnabled ? .green : .gray.opacity(0.3))
        }
    }
}

// MARK: - Setting Section

private struct SettingSection: View {
    let title: String
    let subtitle: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            // Header
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .tracking(2)

                Text(subtitle)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.gray)
            }

            // Stepper buttons
            HStack(spacing: 20) {
                // Decrease button
                StepperButton(
                    systemImage: "minus",
                    color: color,
                    isEnabled: value > range.lowerBound
                ) {
                    if value > range.lowerBound {
                        value -= 1
                    }
                }

                // Value display
                ZStack {
                    Circle()
                        .stroke(color.opacity(0.5), lineWidth: 2)
                        .frame(width: 60, height: 60)

                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 56, height: 56)

                    Text("\(value)")
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundStyle(color)
                }
                .shadow(color: color.opacity(0.3), radius: 8)

                // Increase button
                StepperButton(
                    systemImage: "plus",
                    color: color,
                    isEnabled: value < range.upperBound
                ) {
                    if value < range.upperBound {
                        value += 1
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Stepper Button

private struct StepperButton: View {
    let systemImage: String
    let color: Color
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(isEnabled ? color : color.opacity(0.3))
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Color(white: 0.12))
                        .overlay(
                            Circle()
                                .stroke(color.opacity(isEnabled ? 0.5 : 0.2), lineWidth: 1)
                        )
                )
        }
        .disabled(!isEnabled)
    }
}

// MARK: - Settings Preview

private struct SettingsPreview: View {
    let cueBallCount: Int
    let obstacleBallCount: Int

    var body: some View {
        VStack(spacing: 12) {
            Text("PREVIEW")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.gray)
                .tracking(2)

            // Mini table preview
            ZStack {
                // Table background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(white: 0.1))
                    .frame(width: 200, height: 100)

                // Table border
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        LinearGradient(
                            colors: [.cyan.opacity(0.6), .purple.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 200, height: 100)

                // Cue balls (left side)
                HStack(spacing: 4) {
                    ForEach(0..<cueBallCount, id: \.self) { index in
                        Circle()
                            .fill(.white)
                            .frame(width: 12, height: 12)
                            .shadow(color: .white.opacity(0.5), radius: 4)
                    }
                }
                .position(x: 50, y: 50)

                // Obstacle balls (center)
                HStack(spacing: 6) {
                    ForEach(0..<obstacleBallCount, id: \.self) { index in
                        Circle()
                            .fill(Color(white: 0.5))
                            .frame(width: 10, height: 10)
                            .overlay(
                                Circle()
                                    .stroke(Color(white: 0.4), lineWidth: 2)
                                    .frame(width: 6, height: 6)
                            )
                    }
                }
                .position(x: 100, y: 50)

                // Player ball (right side)
                Circle()
                    .fill(.cyan)
                    .frame(width: 12, height: 12)
                    .shadow(color: .cyan.opacity(0.5), radius: 4)
                    .position(x: 150, y: 50)
            }

            // Difficulty indicator
            HStack(spacing: 8) {
                Image(systemName: difficultyIcon)
                    .foregroundStyle(difficultyColor)

                Text(difficultyText)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(difficultyColor)
            }
            .padding(.top, 8)
        }
    }

    private var difficultyIcon: String {
        let total = cueBallCount + obstacleBallCount
        if total <= 1 {
            return "star"
        } else if total <= 3 {
            return "star.leadinghalf.filled"
        } else {
            return "star.fill"
        }
    }

    private var difficultyColor: Color {
        let total = cueBallCount + obstacleBallCount
        if total <= 1 {
            return .green
        } else if total <= 3 {
            return .yellow
        } else {
            return .red
        }
    }

    private var difficultyText: String {
        let total = cueBallCount + obstacleBallCount
        if total <= 1 {
            return "STANDARD"
        } else if total <= 3 {
            return "CHALLENGING"
        } else {
            return "CHAOS MODE"
        }
    }
}

// MARK: - Preview

#Preview("Billiard Dodge Settings") {
    BilliardDodgeSettingsView(
        cueBallCount: .constant(2),
        obstacleBallCount: .constant(3),
        onDismiss: {}
    )
}
