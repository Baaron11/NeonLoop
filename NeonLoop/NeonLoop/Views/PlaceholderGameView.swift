/**
 * Placeholder Game View - Coming Soon Screen
 *
 * Displays a placeholder for games that are not yet implemented.
 * Shows game info, description, and a back button to return to launcher.
 */

import SwiftUI

struct PlaceholderGameView: View {
    @EnvironmentObject var coordinator: GameCoordinator
    let gameInfo: GameInfo

    @State private var pulseAnimation = false
    @State private var glowIntensity: Double = 0.5

    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()

            // Grid pattern
            GridBackground()

            // Animated background glow
            Circle()
                .fill(gameInfo.accentColor.opacity(0.1))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .scaleEffect(pulseAnimation ? 1.3 : 1.0)
                .offset(y: -50)

            VStack(spacing: 0) {
                // Back button header
                HStack {
                    Button {
                        coordinator.goToLauncher()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Games")
                                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        }
                        .foregroundStyle(gameInfo.accentColor)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()

                // Main content
                VStack(spacing: 32) {
                    // Animated icon
                    ZStack {
                        // Outer glow rings
                        ForEach(0..<3) { index in
                            Circle()
                                .stroke(
                                    gameInfo.accentColor.opacity(0.2 - Double(index) * 0.05),
                                    lineWidth: 2
                                )
                                .frame(
                                    width: CGFloat(120 + index * 40),
                                    height: CGFloat(120 + index * 40)
                                )
                                .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                                .animation(
                                    .easeInOut(duration: 2)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(index) * 0.2),
                                    value: pulseAnimation
                                )
                        }

                        // Inner circle with icon
                        ZStack {
                            Circle()
                                .fill(gameInfo.accentColor.opacity(0.15))
                                .frame(width: 100, height: 100)
                                .blur(radius: 10)

                            Circle()
                                .stroke(gameInfo.accentColor.opacity(0.6), lineWidth: 3)
                                .frame(width: 80, height: 80)

                            Image(systemName: gameInfo.iconName)
                                .font(.system(size: 36, weight: .semibold))
                                .foregroundStyle(gameInfo.accentColor)
                                .shadow(color: gameInfo.accentColor.opacity(0.8), radius: 10)
                        }
                    }

                    // Game name
                    VStack(spacing: 8) {
                        Text(gameInfo.name.uppercased())
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .shadow(color: gameInfo.accentColor.opacity(0.5), radius: 10)

                        Text(gameInfo.subtitle)
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundStyle(gameInfo.accentColor)
                            .tracking(2)
                    }

                    // Coming soon badge
                    ComingSoonBadge(color: gameInfo.accentColor)

                    // Description
                    Text(gameInfo.description)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 40)

                    // Game stats
                    HStack(spacing: 32) {
                        StatItem(
                            icon: "person.2.fill",
                            label: "Players",
                            value: "\(gameInfo.minPlayers)-\(gameInfo.maxPlayers)",
                            color: gameInfo.accentColor
                        )

                        StatItem(
                            icon: "hand.tap.fill",
                            label: "Input",
                            value: inputTypeLabel,
                            color: gameInfo.accentColor
                        )
                    }
                }

                Spacer()

                // Footer
                VStack(spacing: 8) {
                    Text("This game is under development")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.gray.opacity(0.6))

                    Button {
                        coordinator.goToLauncher()
                    } label: {
                        Text("Return to Games")
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            .foregroundStyle(gameInfo.accentColor)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(gameInfo.accentColor, lineWidth: 2)
                                    .shadow(color: gameInfo.accentColor.opacity(0.5), radius: 8)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 40)
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowIntensity = 1.0
            }
        }
    }

    private var inputTypeLabel: String {
        switch gameInfo.inputType {
        case .position: return "Position"
        case .vector: return "Vector"
        case .swipeAndTap: return "Swipe"
        case .tilt: return "Tilt"
        }
    }
}

// MARK: - Coming Soon Badge

private struct ComingSoonBadge: View {
    let color: Color
    @State private var shimmerOffset: CGFloat = -200

    var body: some View {
        Text("COMING SOON")
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .tracking(4)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    // Base gradient
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.4), color.opacity(0.2)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    // Border
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(color.opacity(0.6), lineWidth: 1)
                }
            )
            .shadow(color: color.opacity(0.3), radius: 10)
    }
}

// MARK: - Stat Item

private struct StatItem: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color.opacity(0.7))

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)

            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.gray)
                .textCase(.uppercase)
        }
        .frame(width: 80)
    }
}

// MARK: - Preview

#Preview("Horde Defense") {
    PlaceholderGameView(
        gameInfo: NeonLoopGameRegistry.allGames[1]
    )
    .environmentObject(GameCoordinator())
}

#Preview("Billiard Dodge") {
    PlaceholderGameView(
        gameInfo: NeonLoopGameRegistry.allGames[3]
    )
    .environmentObject(GameCoordinator())
}
