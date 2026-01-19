/**
 * CinematicOverlay - Post-Processing Effects for Premium Visual Quality
 *
 * Implements cinematic effects in pure SwiftUI:
 * - ACES-inspired tonemapping (simulated via color adjustments)
 * - Subtle bloom for neon emissives
 * - Vignette for focus and cinematic framing
 * - Film grain (very light, animated)
 * - Chromatic aberration (subtle edge distortion)
 *
 * All effects are designed for 60fps performance on mobile.
 */

import SwiftUI

// MARK: - Cinematic Overlay Container

/// Applies all post-processing effects as overlays
struct CinematicOverlay<Content: View>: View {
    @Environment(\.visualConfig) private var config
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            // Base content
            content

            // Post-processing layers (order matters)
            if config.chromaticAberrationStrength > 0 {
                ChromaticAberrationLayer()
            }

            if config.fogEnabled {
                AtmosphericFogLayer()
            }

            if config.vignetteIntensity > 0 {
                VignetteLayer()
            }

            if config.filmGrainIntensity > 0 {
                FilmGrainLayer()
            }
        }
        .modifier(TonemappingModifier())
    }
}

// MARK: - Tonemapping Modifier

/// Simulates ACES tonemapping by adjusting contrast and saturation
/// Since SwiftUI doesn't have direct color grading, we use
/// contrast/saturation/brightness adjustments to approximate the look.
struct TonemappingModifier: ViewModifier {
    @Environment(\.visualConfig) private var config

    func body(content: Content) -> some View {
        if config.tonemappingEnabled {
            content
                // Slight S-curve contrast (darker darks, brighter brights)
                .contrast(1.08)
                // Slight desaturation in shadows, boost in highlights (film look)
                .saturation(1.05)
                // Very subtle warmth
                .brightness(0.01)
        } else {
            content
        }
    }
}

// MARK: - Vignette Layer

/// Creates a radial darkening at screen edges for cinematic focus
struct VignetteLayer: View {
    @Environment(\.visualConfig) private var config

    var body: some View {
        GeometryReader { geo in
            let size = max(geo.size.width, geo.size.height)

            RadialGradient(
                colors: [
                    .clear,
                    .clear,
                    .black.opacity(config.vignetteIntensity * 0.5),
                    .black.opacity(config.vignetteIntensity)
                ],
                center: .center,
                startRadius: size * 0.3,
                endRadius: size * 0.85
            )
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Film Grain Layer

/// Animated noise overlay for subtle film grain effect
struct FilmGrainLayer: View {
    @Environment(\.visualConfig) private var config
    @State private var grainOffset: Double = 0

    // Pre-generated noise pattern offsets for performance
    private let noisePattern: [CGFloat] = (0..<100).map { _ in CGFloat.random(in: 0...1) }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
            Canvas { context, size in
                let grainSize: CGFloat = 3
                let intensity = config.filmGrainIntensity

                // Use time-based seed for animation
                let seed = Int(timeline.date.timeIntervalSinceReferenceDate * 24) % noisePattern.count

                // Draw grain pattern (sparse for performance)
                let cols = Int(size.width / grainSize)
                let rows = Int(size.height / grainSize)

                for row in stride(from: 0, to: rows, by: 2) {
                    for col in stride(from: 0, to: cols, by: 2) {
                        let patternIndex = (row * cols + col + seed) % noisePattern.count
                        let noise = noisePattern[patternIndex]

                        // Only draw brighter noise points (sparse)
                        if noise > 0.7 {
                            let opacity = (noise - 0.7) * intensity * 3
                            let rect = CGRect(
                                x: CGFloat(col) * grainSize,
                                y: CGFloat(row) * grainSize,
                                width: grainSize,
                                height: grainSize
                            )
                            context.fill(
                                Path(rect),
                                with: .color(.white.opacity(opacity))
                            )
                        }
                    }
                }
            }
            .allowsHitTesting(false)
            .blendMode(.overlay)
        }
    }
}

// MARK: - Chromatic Aberration Layer

/// Simulates lens chromatic aberration at screen edges
/// Uses separate color channel offsets (red/blue shift)
struct ChromaticAberrationLayer: View {
    @Environment(\.visualConfig) private var config

    var body: some View {
        GeometryReader { geo in
            let strength = config.chromaticAberrationStrength

            ZStack {
                // Red channel shift (outward)
                LinearGradient(
                    colors: [.red.opacity(0.03 * strength), .clear, .clear, .clear, .red.opacity(0.03 * strength)],
                    startPoint: .leading,
                    endPoint: .trailing
                )

                // Blue channel shift (opposite)
                LinearGradient(
                    colors: [.blue.opacity(0.02 * strength), .clear, .clear, .clear, .blue.opacity(0.02 * strength)],
                    startPoint: .trailing,
                    endPoint: .leading
                )

                // Vertical component
                LinearGradient(
                    colors: [.cyan.opacity(0.02 * strength), .clear, .clear, .clear, .cyan.opacity(0.02 * strength)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .blendMode(.screen)
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Atmospheric Fog Layer

/// Creates subtle depth haze for visual depth separation
struct AtmosphericFogLayer: View {
    @Environment(\.visualConfig) private var config

    var body: some View {
        GeometryReader { geo in
            // Subtle gradient from bottom (closer) to top (further)
            LinearGradient(
                colors: [
                    .clear,
                    Color(white: 0.1).opacity(config.fogIntensity),
                    Color(white: 0.15).opacity(config.fogIntensity * 0.7),
                    .clear
                ],
                startPoint: .bottom,
                endPoint: .top
            )
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Bloom Effect View

/// Creates a bloom/glow effect by rendering content with blur and additive blend
struct BloomEffect<Content: View>: View {
    @Environment(\.visualConfig) private var config
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            // Bloom layer (blurred, additive)
            content
                .blur(radius: config.bloomRadius)
                .opacity(config.bloomIntensity * 0.5)
                .blendMode(.plusLighter)

            // Sharp content on top
            content
        }
    }
}

// MARK: - Neon Glow Modifier

/// Applies a neon glow effect to any view
struct NeonGlowModifier: ViewModifier {
    let color: Color
    let intensity: CGFloat
    @Environment(\.visualConfig) private var config

    func body(content: Content) -> some View {
        let effectiveIntensity = intensity * config.emissiveGlowRadius

        content
            // Inner glow
            .shadow(color: color.opacity(0.9), radius: 2 * effectiveIntensity)
            // Mid glow
            .shadow(color: color.opacity(0.6), radius: 6 * effectiveIntensity)
            // Outer glow (bloom simulation)
            .shadow(color: color.opacity(0.3), radius: 12 * effectiveIntensity)
    }
}

extension View {
    /// Apply neon glow effect
    func neonGlow(_ color: Color, intensity: CGFloat = 1.0) -> some View {
        modifier(NeonGlowModifier(color: color, intensity: intensity))
    }
}

// MARK: - Emissive Pulse Effect

/// Animates an emissive pulse effect (for impacts, hits, etc.)
struct EmissivePulse: View {
    let color: Color
    let isActive: Bool
    let radius: CGFloat

    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: CGFloat = 0.8

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color, color.opacity(0.5), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: radius * pulseScale
                )
            )
            .frame(width: radius * 2 * pulseScale, height: radius * 2 * pulseScale)
            .opacity(isActive ? pulseOpacity : 0)
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    // Reset and animate
                    pulseScale = 1.0
                    pulseOpacity = 0.8

                    withAnimation(.easeOut(duration: 0.3)) {
                        pulseScale = 2.0
                        pulseOpacity = 0
                    }
                }
            }
    }
}

// MARK: - Scanline Effect (Optional Retro Feel)

/// Optional CRT-style scanlines for extra sci-fi aesthetic
struct ScanlineOverlay: View {
    let intensity: CGFloat
    let spacing: CGFloat

    init(intensity: CGFloat = 0.05, spacing: CGFloat = 2) {
        self.intensity = intensity
        self.spacing = spacing
    }

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                for y in stride(from: 0, to: size.height, by: spacing) {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(.black.opacity(intensity)), lineWidth: 0.5)
                }
            }
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Preview

#Preview("Cinematic Effects") {
    CinematicOverlay {
        ZStack {
            Color.black

            // Neon test elements
            VStack(spacing: 30) {
                Circle()
                    .fill(.cyan)
                    .frame(width: 60, height: 60)
                    .neonGlow(.cyan, intensity: 1.0)

                Circle()
                    .fill(.pink)
                    .frame(width: 60, height: 60)
                    .neonGlow(.pink, intensity: 1.0)

                RoundedRectangle(cornerRadius: 8)
                    .stroke(.purple, lineWidth: 3)
                    .frame(width: 200, height: 100)
                    .neonGlow(.purple, intensity: 0.8)
            }
        }
    }
    .visualConfig(.high)
}
