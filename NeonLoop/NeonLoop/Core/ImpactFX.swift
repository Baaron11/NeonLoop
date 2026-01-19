/**
 * ImpactFX - Impact Effects for Collision Feedback
 *
 * Provides visual feedback for collisions and impacts:
 * - Impact sparks/flash on wall collisions
 * - Camera shake on strong impacts
 * - Emissive pulse on hit targets
 * - Ball flash on collision
 *
 * All effects are designed to be brief and mobile-performant.
 */

import SwiftUI

// MARK: - Impact Event

/// Represents a single impact event for rendering effects
struct ImpactEvent: Identifiable, Equatable {
    let id: UUID
    let position: CGPoint
    let intensity: CGFloat  // 0-1, based on collision force
    let color: Color
    let timestamp: Date
    let type: ImpactType

    enum ImpactType {
        case wall       // Ball hitting rail
        case ball       // Ball-ball collision
        case pocket     // Ball entering pocket
    }

    init(
        position: CGPoint,
        intensity: CGFloat,
        color: Color = .white,
        type: ImpactType = .wall
    ) {
        self.id = UUID()
        self.position = position
        self.intensity = min(1, max(0, intensity))
        self.color = color
        self.timestamp = Date()
        self.type = type
    }

    /// Whether the impact should still be rendered (within animation duration)
    var isActive: Bool {
        Date().timeIntervalSince(timestamp) < 0.4
    }
}

// MARK: - Impact Manager

/// Manages active impact events for rendering
@Observable
final class ImpactFXManager {
    var impacts: [ImpactEvent] = []
    var cameraShakeOffset: CGSize = .zero
    var isShaking: Bool = false

    /// Add a new impact event
    func addImpact(_ impact: ImpactEvent) {
        impacts.append(impact)

        // Cleanup old impacts
        impacts.removeAll { !$0.isActive }

        // Limit max impacts
        if impacts.count > 10 {
            impacts.removeFirst(impacts.count - 10)
        }
    }

    /// Trigger camera shake
    func triggerShake(intensity: CGFloat) {
        guard !isShaking else { return }
        isShaking = true

        // Camera shake will be handled by the view modifier
    }

    /// Clear all effects
    func clear() {
        impacts.removeAll()
        cameraShakeOffset = .zero
        isShaking = false
    }
}

// MARK: - Impact Spark View

/// Renders a single impact spark effect
struct ImpactSparkView: View {
    let impact: ImpactEvent
    @Environment(\.visualConfig) private var config

    @State private var sparkScale: CGFloat = 0.5
    @State private var sparkOpacity: CGFloat = 1.0
    @State private var particleOffsets: [CGSize] = []

    var body: some View {
        if config.impactSparksEnabled {
            ZStack {
                // Central flash
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .white,
                                impact.color,
                                impact.color.opacity(0.5),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 20 * impact.intensity * sparkScale
                        )
                    )
                    .frame(width: 40 * impact.intensity, height: 40 * impact.intensity)
                    .scaleEffect(sparkScale)
                    .opacity(sparkOpacity)

                // Spark particles
                ForEach(0..<config.sparkParticleCount, id: \.self) { index in
                    if index < particleOffsets.count {
                        SparkParticle(color: impact.color, intensity: impact.intensity)
                            .offset(particleOffsets[index])
                            .opacity(sparkOpacity)
                    }
                }
            }
            .position(impact.position)
            .onAppear {
                initializeParticles()
                animateImpact()
            }
        }
    }

    private func initializeParticles() {
        particleOffsets = (0..<config.sparkParticleCount).map { _ in
            CGSize(width: 0, height: 0)
        }

        // Animate particles outward
        for i in 0..<particleOffsets.count {
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 15...35) * impact.intensity

            withAnimation(.easeOut(duration: 0.25)) {
                particleOffsets[i] = CGSize(
                    width: cos(angle) * distance,
                    height: sin(angle) * distance
                )
            }
        }
    }

    private func animateImpact() {
        // Quick expand
        withAnimation(.easeOut(duration: 0.1)) {
            sparkScale = 1.5
        }

        // Fade out
        withAnimation(.easeOut(duration: 0.3).delay(0.05)) {
            sparkScale = 2.0
            sparkOpacity = 0
        }
    }
}

// MARK: - Spark Particle

/// Individual spark particle
struct SparkParticle: View {
    let color: Color
    let intensity: CGFloat

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 3 * intensity, height: 3 * intensity)
            .shadow(color: color, radius: 2)
    }
}

// MARK: - Wall Impact Flash

/// Quick flash effect for wall collisions
struct WallImpactFlash: View {
    let impact: ImpactEvent

    @State private var opacity: CGFloat = 0.8
    @State private var scale: CGFloat = 1.0

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(
                LinearGradient(
                    colors: [impact.color, .white, impact.color],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 30 * impact.intensity, height: 8)
            .scaleEffect(scale)
            .opacity(opacity)
            .position(impact.position)
            .onAppear {
                withAnimation(.easeOut(duration: 0.15)) {
                    scale = 1.5
                    opacity = 0
                }
            }
    }
}

// MARK: - Ball Collision Flash

/// Brief flash when two balls collide
struct BallCollisionFlash: View {
    let impact: ImpactEvent

    @State private var ringScale: CGFloat = 0.5
    @State private var ringOpacity: CGFloat = 0.8

    var body: some View {
        Circle()
            .stroke(impact.color, lineWidth: 2 * impact.intensity)
            .frame(width: 30, height: 30)
            .scaleEffect(ringScale)
            .opacity(ringOpacity)
            .position(impact.position)
            .onAppear {
                withAnimation(.easeOut(duration: 0.25)) {
                    ringScale = 2.0
                    ringOpacity = 0
                }
            }
    }
}

// MARK: - Pocket Swirl Effect

/// Effect when ball enters pocket
struct PocketSwirlEffect: View {
    let impact: ImpactEvent

    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0
    @State private var opacity: CGFloat = 0.8

    var body: some View {
        ZStack {
            // Swirl ring
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [impact.color, .clear, impact.color.opacity(0.5), .clear],
                        center: .center
                    ),
                    lineWidth: 3
                )
                .frame(width: 40, height: 40)
                .rotationEffect(.degrees(rotation))
                .scaleEffect(scale)
                .opacity(opacity)

            // Center flash
            Circle()
                .fill(impact.color)
                .frame(width: 10, height: 10)
                .scaleEffect(scale)
                .opacity(opacity)
        }
        .position(impact.position)
        .onAppear {
            withAnimation(.easeIn(duration: 0.4)) {
                rotation = 180
                scale = 0.2
                opacity = 0
            }
        }
    }
}

// MARK: - Camera Shake Modifier

/// Applies camera shake effect to a view
struct CameraShakeModifier: ViewModifier {
    @Binding var isShaking: Bool
    let intensity: CGFloat

    @State private var offset: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .offset(offset)
            .onChange(of: isShaking) { _, newValue in
                if newValue {
                    animateShake()
                }
            }
    }

    private func animateShake() {
        let shakeDuration: Double = 0.05
        let shakeCount = 4

        Task { @MainActor in
            for i in 0..<shakeCount {
                let factor = CGFloat(shakeCount - i) / CGFloat(shakeCount)
                let randomX = CGFloat.random(in: -intensity...intensity) * factor
                let randomY = CGFloat.random(in: -intensity...intensity) * factor

                withAnimation(.linear(duration: shakeDuration)) {
                    offset = CGSize(width: randomX, height: randomY)
                }

                try? await Task.sleep(nanoseconds: UInt64(shakeDuration * 1_000_000_000))
            }

            // Return to center
            withAnimation(.easeOut(duration: 0.05)) {
                offset = .zero
            }

            isShaking = false
        }
    }
}

extension View {
    /// Apply camera shake effect
    func cameraShake(isShaking: Binding<Bool>, intensity: CGFloat = 4) -> some View {
        modifier(CameraShakeModifier(isShaking: isShaking, intensity: intensity))
    }
}

// MARK: - Hit Pulse Modifier

/// Applies a brief emissive pulse to a view when triggered
struct HitPulseModifier: ViewModifier {
    let color: Color
    @Binding var isHit: Bool

    @State private var pulseOpacity: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0

    func body(content: Content) -> some View {
        ZStack {
            content

            // Pulse overlay
            content
                .foregroundStyle(color)
                .scaleEffect(pulseScale)
                .opacity(pulseOpacity)
                .blendMode(.plusLighter)
        }
        .onChange(of: isHit) { _, newValue in
            if newValue {
                animatePulse()
            }
        }
    }

    private func animatePulse() {
        pulseOpacity = 0.8
        pulseScale = 1.0

        withAnimation(.easeOut(duration: 0.2)) {
            pulseOpacity = 0
            pulseScale = 1.2
        }

        // Reset flag after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isHit = false
        }
    }
}

extension View {
    /// Apply hit pulse effect
    func hitPulse(color: Color, isHit: Binding<Bool>) -> some View {
        modifier(HitPulseModifier(color: color, isHit: isHit))
    }
}

// MARK: - Impact Effects Layer

/// Renders all active impact effects
struct ImpactEffectsLayer: View {
    let impacts: [ImpactEvent]
    @Environment(\.visualConfig) private var config

    var body: some View {
        ZStack {
            ForEach(impacts) { impact in
                switch impact.type {
                case .wall:
                    if config.impactSparksEnabled {
                        ImpactSparkView(impact: impact)
                    } else {
                        WallImpactFlash(impact: impact)
                    }
                case .ball:
                    BallCollisionFlash(impact: impact)
                case .pocket:
                    PocketSwirlEffect(impact: impact)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Danger Pulse (For Timer/Health)

/// Pulsing danger indicator (e.g., low timer)
struct DangerPulse: View {
    let isActive: Bool
    let color: Color

    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: CGFloat = 0.5

    var body: some View {
        Circle()
            .fill(color.opacity(pulseOpacity))
            .scaleEffect(pulseScale)
            .opacity(isActive ? 1 : 0)
            .onAppear {
                if isActive {
                    startPulsing()
                }
            }
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    startPulsing()
                }
            }
    }

    private func startPulsing() {
        withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
            pulseScale = 1.3
            pulseOpacity = 0.8
        }
    }
}

// MARK: - Preview

#Preview("Impact Effects") {
    ZStack {
        Color.black.ignoresSafeArea()

        ImpactEffectsLayer(impacts: [
            ImpactEvent(position: CGPoint(x: 100, y: 200), intensity: 0.8, color: .cyan, type: .wall),
            ImpactEvent(position: CGPoint(x: 200, y: 300), intensity: 0.6, color: .pink, type: .ball),
            ImpactEvent(position: CGPoint(x: 300, y: 200), intensity: 1.0, color: .red, type: .pocket)
        ])
    }
    .visualConfig(.high)
}
