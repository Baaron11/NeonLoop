/**
 * NeonMaterials - Premium Material Definitions for Sci-Fi Aesthetic
 *
 * Provides reusable material styles for:
 * - Playfield surfaces (with roughness variation)
 * - Metallic rails (glossy with specular)
 * - Neon emissive edges (glowing)
 * - Reflective surfaces (fake screen-space reflections)
 *
 * All materials are designed to work with the lighting system.
 */

import SwiftUI

// MARK: - Material Definitions

/// Material type for consistent styling
enum NeonMaterial {
    case surface        // Dark matte surface with subtle texture
    case metal          // Glossy metallic rails and trim
    case emissive       // Glowing neon elements
    case glass          // Transparent with fresnel reflection
    case holographic    // Iridescent/color-shifting
}

// MARK: - Surface Material

/// Dark playfield surface with subtle roughness variation
struct SurfaceMaterial: View {
    let width: CGFloat
    let height: CGFloat
    let baseColor: Color
    let cornerRadius: CGFloat

    @Environment(\.visualConfig) private var config

    init(
        width: CGFloat,
        height: CGFloat,
        baseColor: Color = Color(white: 0.08),
        cornerRadius: CGFloat = 8
    ) {
        self.width = width
        self.height = height
        self.baseColor = baseColor
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        ZStack {
            // Base color
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(baseColor)

            // Roughness variation (subtle noise pattern)
            if config.surfaceDetailEnabled {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        // Simulated roughness via subtle gradient noise
                        LinearGradient(
                            colors: [
                                Color(white: 0.06),
                                Color(white: 0.10),
                                Color(white: 0.07),
                                Color(white: 0.09),
                                Color(white: 0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .opacity(0.5)

                // Additional micro-texture
                Canvas { context, size in
                    // Draw subtle surface variation
                    let cellSize: CGFloat = 30
                    for x in stride(from: 0, to: size.width, by: cellSize) {
                        for y in stride(from: 0, to: size.height, by: cellSize) {
                            let brightness = CGFloat.random(in: 0.02...0.05)
                            let rect = CGRect(x: x, y: y, width: cellSize, height: cellSize)
                            context.fill(
                                Path(rect),
                                with: .color(Color(white: brightness))
                            )
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .blendMode(.overlay)
                .opacity(0.3)
            }

            // Subtle reflection gradient (from lighting)
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.02),
                            .clear,
                            .clear,
                            .black.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .frame(width: width, height: height)
    }
}

// MARK: - Metal Material

/// Glossy metallic appearance for rails and trim
struct MetalMaterial: View {
    let gradient: [Color]
    let lineWidth: CGFloat
    let cornerRadius: CGFloat

    @Environment(\.visualConfig) private var config

    init(
        colors: [Color] = [.cyan, .purple],
        lineWidth: CGFloat = 3,
        cornerRadius: CGFloat = 12
    ) {
        self.gradient = colors
        self.lineWidth = lineWidth
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        ZStack {
            // Base metal stroke
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    LinearGradient(
                        colors: gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: lineWidth
                )

            // Specular highlight (glossy reflection)
            if config.specularHighlightsEnabled {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.6 * config.specularIntensity),
                                .clear,
                                .clear,
                                .white.opacity(0.2 * config.specularIntensity)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: lineWidth * 0.5
                    )
                    .blur(radius: 0.5)
            }
        }
    }
}

// MARK: - Emissive Material

/// Glowing neon material for edges and accents
struct EmissiveMaterial: View {
    let color: Color
    let lineWidth: CGFloat
    let cornerRadius: CGFloat
    let pulseAnimation: Bool

    @Environment(\.visualConfig) private var config
    @State private var isPulsing = false

    init(
        color: Color,
        lineWidth: CGFloat = 2,
        cornerRadius: CGFloat = 12,
        pulseAnimation: Bool = false
    ) {
        self.color = color
        self.lineWidth = lineWidth
        self.cornerRadius = cornerRadius
        self.pulseAnimation = pulseAnimation
    }

    var body: some View {
        let glowMultiplier = config.emissiveGlowRadius

        ZStack {
            // Outer glow (bloom simulation)
            if config.emissiveGlowEnabled {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(color.opacity(0.3), lineWidth: lineWidth * 4)
                    .blur(radius: 12 * glowMultiplier)
                    .scaleEffect(isPulsing ? 1.05 : 1.0)

                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(color.opacity(0.5), lineWidth: lineWidth * 2)
                    .blur(radius: 6 * glowMultiplier)
            }

            // Core emissive line
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(color, lineWidth: lineWidth)
                .shadow(color: color.opacity(0.8), radius: 4 * glowMultiplier)
        }
        .onAppear {
            if pulseAnimation {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
        }
    }
}

// MARK: - Glass Material

/// Transparent glass-like material with fresnel effect
struct GlassMaterial: View {
    let cornerRadius: CGFloat
    let tint: Color
    let opacity: CGFloat

    @Environment(\.visualConfig) private var config

    init(
        cornerRadius: CGFloat = 12,
        tint: Color = .white,
        opacity: CGFloat = 0.1
    ) {
        self.cornerRadius = cornerRadius
        self.tint = tint
        self.opacity = opacity
    }

    var body: some View {
        ZStack {
            // Base glass fill
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(tint.opacity(opacity))

            // Fresnel edge (brighter at edges)
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.3),
                            .white.opacity(0.1),
                            .white.opacity(0.05),
                            .white.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )

            // Reflection highlight
            if config.reflectionsEnabled {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.15),
                                .clear,
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .center
                        )
                    )
            }
        }
    }
}

// MARK: - Premium Ball Material

/// High-quality ball rendering with proper PBR-like appearance
struct PremiumBallMaterial: View {
    let radius: CGFloat
    let color: Color
    let isEmissive: Bool
    let isCueBall: Bool

    @Environment(\.visualConfig) private var config

    init(
        radius: CGFloat,
        color: Color,
        isEmissive: Bool = true,
        isCueBall: Bool = false
    ) {
        self.radius = radius
        self.color = color
        self.isEmissive = isEmissive
        self.isCueBall = isCueBall
    }

    var body: some View {
        let highlightOffset = CGPoint(x: -0.3, y: -0.3)

        ZStack {
            // Emissive glow (for player balls)
            if isEmissive && config.emissiveGlowEnabled {
                Circle()
                    .fill(color.opacity(0.4))
                    .frame(width: radius * 3, height: radius * 3)
                    .blur(radius: 6 * config.emissiveGlowRadius)
            }

            // Contact shadow
            if config.shadowsEnabled {
                Ellipse()
                    .fill(.black.opacity(config.shadowOpacity))
                    .frame(width: radius * 2.2, height: radius * 1.2)
                    .offset(x: 2, y: 4)
                    .blur(radius: config.shadowBlurRadius)
            }

            // Ball body with gradient
            Circle()
                .fill(ballGradient(highlightOffset: highlightOffset))
                .frame(width: radius * 2, height: radius * 2)
                .shadow(color: color.opacity(isEmissive ? 0.6 : 0.3), radius: 4)

            // Surface detail (subtle roughness)
            if config.surfaceDetailEnabled && !isCueBall {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.clear, color.opacity(0.1), .clear],
                            center: .center,
                            startRadius: radius * 0.3,
                            endRadius: radius * 0.8
                        )
                    )
                    .frame(width: radius * 2, height: radius * 2)
            }

            // Primary specular highlight
            if config.specularHighlightsEnabled {
                Circle()
                    .fill(.white.opacity(0.8 * config.specularIntensity))
                    .frame(width: radius * 0.5, height: radius * 0.5)
                    .offset(
                        x: highlightOffset.x * radius,
                        y: highlightOffset.y * radius
                    )
                    .blur(radius: 1)

                // Secondary smaller highlight
                Circle()
                    .fill(.white.opacity(0.95 * config.specularIntensity))
                    .frame(width: radius * 0.25, height: radius * 0.25)
                    .offset(
                        x: highlightOffset.x * radius * 0.8,
                        y: highlightOffset.y * radius * 0.8
                    )
            }

            // Rim light
            if config.rimLightingEnabled {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                .clear,
                                .clear,
                                .white.opacity(0.4 * config.rimLightIntensity)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                    .frame(width: radius * 2, height: radius * 2)
            }

            // Fake reflection (environment)
            if config.reflectionsEnabled {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .cyan.opacity(0.05),
                                .clear,
                                .purple.opacity(0.03)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: radius * 2, height: radius * 2)
            }
        }
    }

    private func ballGradient(highlightOffset: CGPoint) -> RadialGradient {
        let colors: [Color]

        if isCueBall {
            colors = [.white, Color(white: 0.9), Color(white: 0.75)]
        } else {
            colors = [
                color.lighter(by: 0.15),
                color,
                color.darker(by: 0.25)
            ]
        }

        return RadialGradient(
            colors: colors,
            center: UnitPoint(
                x: 0.5 + highlightOffset.x * 0.25,
                y: 0.5 + highlightOffset.y * 0.25
            ),
            startRadius: 0,
            endRadius: radius
        )
    }
}

// MARK: - Rail Neon Border

/// Complete rail/border with metal base and neon glow
struct NeonRailBorder: View {
    let cornerRadius: CGFloat
    let colors: [Color]
    let metalWidth: CGFloat
    let glowWidth: CGFloat

    @Environment(\.visualConfig) private var config

    init(
        cornerRadius: CGFloat = 12,
        colors: [Color] = [.cyan, .purple],
        metalWidth: CGFloat = 3,
        glowWidth: CGFloat = 2
    ) {
        self.cornerRadius = cornerRadius
        self.colors = colors
        self.metalWidth = metalWidth
        self.glowWidth = glowWidth
    }

    var body: some View {
        ZStack {
            // Outer glow (bloom)
            if config.emissiveGlowEnabled {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: colors.map { $0.opacity(0.4) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: metalWidth + 8
                    )
                    .blur(radius: 8 * config.emissiveGlowRadius)
            }

            // Metal rail
            MetalMaterial(
                colors: colors,
                lineWidth: metalWidth,
                cornerRadius: cornerRadius
            )

            // Inner neon edge
            EmissiveMaterial(
                color: colors.first ?? .cyan,
                lineWidth: glowWidth,
                cornerRadius: cornerRadius - 2
            )
            .padding(2)
        }
    }
}

// MARK: - Grid Overlay with Neon

/// Subtle grid pattern for playfield
struct NeonGridOverlay: View {
    let gridSize: CGFloat
    let primaryColor: Color
    let secondaryColor: Color

    @Environment(\.visualConfig) private var config

    init(
        gridSize: CGFloat = 20,
        primaryColor: Color = .cyan,
        secondaryColor: Color = .purple
    ) {
        self.gridSize = gridSize
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
    }

    var body: some View {
        Canvas { context, size in
            let lineOpacity: CGFloat = config.surfaceDetailEnabled ? 0.08 : 0.05

            // Vertical lines
            for x in stride(from: gridSize, to: size.width, by: gridSize) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(primaryColor.opacity(lineOpacity)), lineWidth: 0.5)
            }

            // Horizontal lines
            for y in stride(from: gridSize, to: size.height, by: gridSize) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(primaryColor.opacity(lineOpacity)), lineWidth: 0.5)
            }

            // Center line (brighter)
            var centerLine = Path()
            centerLine.move(to: CGPoint(x: size.width / 2, y: 0))
            centerLine.addLine(to: CGPoint(x: size.width / 2, y: size.height))
            context.stroke(centerLine, with: .color(secondaryColor.opacity(0.2)), lineWidth: 1)

            // Center circle
            let centerRadius = min(size.width, size.height) * 0.15
            var centerCircle = Path()
            centerCircle.addEllipse(in: CGRect(
                x: size.width / 2 - centerRadius,
                y: size.height / 2 - centerRadius,
                width: centerRadius * 2,
                height: centerRadius * 2
            ))
            context.stroke(centerCircle, with: .color(secondaryColor.opacity(0.2)), lineWidth: 1)
        }
    }
}

// MARK: - Preview

#Preview("Neon Materials") {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 30) {
            // Surface with grid
            SurfaceMaterial(width: 300, height: 100)
                .overlay(NeonGridOverlay())
                .overlay(NeonRailBorder())

            // Balls
            HStack(spacing: 20) {
                PremiumBallMaterial(radius: 20, color: .cyan, isCueBall: false)
                PremiumBallMaterial(radius: 20, color: .pink, isCueBall: false)
                PremiumBallMaterial(radius: 20, color: .white, isCueBall: true)
            }

            // Glass panel
            GlassMaterial(cornerRadius: 12, tint: .cyan)
                .frame(width: 200, height: 60)
        }
    }
    .visualConfig(.high)
}
