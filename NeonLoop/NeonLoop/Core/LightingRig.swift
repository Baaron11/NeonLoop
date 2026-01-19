/**
 * LightingRig - Key/Rim/Ambient Lighting Simulation
 *
 * Implements a three-point lighting strategy in 2D:
 * - Key Light: Main directional light from top-left (creates primary shadows)
 * - Rim Light: Back-edge highlighting to separate objects from background
 * - Ambient Fill: Soft environmental lighting for shadow areas
 *
 * Also includes:
 * - Fake soft shadows under objects
 * - Depth-based fog/haze
 */

import SwiftUI

// MARK: - Light Direction

/// Direction from which light appears to come (affects gradients and shadows)
struct LightDirection {
    let angle: CGFloat  // Radians, 0 = right, π/2 = down
    let elevation: CGFloat  // 0 = horizontal, 1 = directly above

    /// Key light from top-left (classic three-point setup)
    static let keyLight = LightDirection(angle: -.pi * 0.75, elevation: 0.6)

    /// Rim light from bottom-right (opposite of key)
    static let rimLight = LightDirection(angle: .pi * 0.25, elevation: 0.3)

    /// Normalized direction vector for 2D projections
    var direction2D: CGPoint {
        CGPoint(x: cos(angle), y: sin(angle))
    }

    /// Shadow offset based on light direction
    var shadowOffset: CGSize {
        let distance: CGFloat = 4 * (1 - elevation)
        return CGSize(
            width: -cos(angle) * distance,
            height: -sin(angle) * distance
        )
    }
}

// MARK: - Lit Surface Modifier

/// Applies directional lighting to a surface (for 3D-ish appearance)
struct LitSurfaceModifier: ViewModifier {
    let baseColor: Color
    let keyIntensity: CGFloat
    let rimIntensity: CGFloat
    @Environment(\.visualConfig) private var config

    func body(content: Content) -> some View {
        content
            .overlay(
                // Key light gradient (top-left to bottom-right)
                LinearGradient(
                    colors: [
                        .white.opacity(keyIntensity * 0.3),
                        .clear,
                        .black.opacity(0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blendMode(.overlay)
            )
            .overlay(
                // Rim light (edge highlight)
                Group {
                    if config.rimLightingEnabled {
                        RoundedRectangle(cornerRadius: 999)
                            .stroke(
                                LinearGradient(
                                    colors: [.clear, .clear, .white.opacity(rimIntensity * config.rimLightIntensity)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    }
                }
            )
    }
}

extension View {
    /// Apply directional lighting effect
    func litSurface(
        color: Color,
        keyIntensity: CGFloat = 0.5,
        rimIntensity: CGFloat = 0.4
    ) -> some View {
        modifier(LitSurfaceModifier(
            baseColor: color,
            keyIntensity: keyIntensity,
            rimIntensity: rimIntensity
        ))
    }
}

// MARK: - Shadow Blob

/// Fake soft shadow under an object (mobile-friendly alternative to real shadows)
struct ShadowBlob: View {
    let size: CGSize
    let offset: CGSize
    let blurRadius: CGFloat
    let opacity: CGFloat

    @Environment(\.visualConfig) private var config

    init(
        width: CGFloat,
        height: CGFloat? = nil,
        offset: CGSize = CGSize(width: 2, height: 4),
        blurRadius: CGFloat? = nil,
        opacity: CGFloat? = nil
    ) {
        self.size = CGSize(width: width, height: height ?? width * 0.4)
        self.offset = offset
        // Will be overridden by config in body
        self.blurRadius = blurRadius ?? 4
        self.opacity = opacity ?? 0.4
    }

    var body: some View {
        Ellipse()
            .fill(.black.opacity(opacity * config.shadowOpacity / 0.4))
            .frame(width: size.width, height: size.height)
            .blur(radius: config.shadowBlurRadius)
            .offset(offset)
    }
}

// MARK: - Contact Shadow Modifier

/// Adds a contact shadow beneath an object
struct ContactShadowModifier: ViewModifier {
    let width: CGFloat
    let height: CGFloat
    let yOffset: CGFloat
    @Environment(\.visualConfig) private var config

    func body(content: Content) -> some View {
        ZStack {
            // Shadow layer
            if config.shadowsEnabled {
                Ellipse()
                    .fill(.black.opacity(config.shadowOpacity))
                    .frame(width: width, height: height)
                    .blur(radius: config.shadowBlurRadius)
                    .offset(y: yOffset)
            }

            // Content on top
            content
        }
    }
}

extension View {
    /// Add contact shadow beneath view
    func contactShadow(width: CGFloat, height: CGFloat? = nil, yOffset: CGFloat = 4) -> some View {
        modifier(ContactShadowModifier(
            width: width,
            height: height ?? width * 0.35,
            yOffset: yOffset
        ))
    }
}

// MARK: - Ambient Light Overlay

/// Simulates ambient/environment lighting with subtle color tinting
struct AmbientLightOverlay: View {
    let color: Color
    let intensity: CGFloat

    var body: some View {
        color
            .opacity(intensity)
            .blendMode(.softLight)
            .allowsHitTesting(false)
    }
}

// MARK: - Depth Fog Gradient

/// Creates subtle fog/haze for depth separation
/// Objects further back (y = 0) appear slightly hazier
struct DepthFogGradient: View {
    let startOpacity: CGFloat
    let endOpacity: CGFloat
    let color: Color

    @Environment(\.visualConfig) private var config

    init(
        startOpacity: CGFloat = 0.15,
        endOpacity: CGFloat = 0,
        color: Color = Color(white: 0.1)
    ) {
        self.startOpacity = startOpacity
        self.endOpacity = endOpacity
        self.color = color
    }

    var body: some View {
        if config.fogEnabled {
            LinearGradient(
                colors: [
                    color.opacity(startOpacity * config.fogIntensity / 0.15),
                    color.opacity(endOpacity)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Three-Point Light Setup

/// Complete three-point lighting setup as a container
struct ThreePointLighting<Content: View>: View {
    let content: Content
    let keyLightColor: Color
    let ambientColor: Color

    @Environment(\.visualConfig) private var config

    init(
        keyLightColor: Color = .white,
        ambientColor: Color = Color(white: 0.05),
        @ViewBuilder content: () -> Content
    ) {
        self.keyLightColor = keyLightColor
        self.ambientColor = ambientColor
        self.content = content()
    }

    var body: some View {
        ZStack {
            // Ambient fill (very subtle)
            AmbientLightOverlay(color: ambientColor, intensity: 0.1)

            // Main content
            content

            // Key light gradient overlay (top-left illumination)
            LinearGradient(
                colors: [
                    keyLightColor.opacity(0.05),
                    .clear,
                    .clear,
                    .black.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .allowsHitTesting(false)
            .blendMode(.overlay)

            // Depth fog
            if config.fogEnabled {
                DepthFogGradient()
            }
        }
    }
}

// MARK: - Lit Ball View Component

/// A spherical object with proper 3D lighting simulation
struct LitSphere: View {
    let radius: CGFloat
    let baseColor: Color
    let highlightOffset: CGPoint

    @Environment(\.visualConfig) private var config

    init(
        radius: CGFloat,
        color: Color,
        highlightOffset: CGPoint = CGPoint(x: -0.3, y: -0.3)
    ) {
        self.radius = radius
        self.baseColor = color
        self.highlightOffset = highlightOffset
    }

    var body: some View {
        ZStack {
            // Base sphere with gradient lighting
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            baseColor.lighter(by: 0.2),
                            baseColor,
                            baseColor.darker(by: 0.3)
                        ],
                        center: UnitPoint(
                            x: 0.5 + highlightOffset.x * 0.3,
                            y: 0.5 + highlightOffset.y * 0.3
                        ),
                        startRadius: 0,
                        endRadius: radius
                    )
                )
                .frame(width: radius * 2, height: radius * 2)

            // Specular highlight
            if config.specularHighlightsEnabled {
                Circle()
                    .fill(.white.opacity(0.7 * config.specularIntensity))
                    .frame(width: radius * 0.4, height: radius * 0.4)
                    .offset(
                        x: highlightOffset.x * radius * 0.5,
                        y: highlightOffset.y * radius * 0.5
                    )
                    .blur(radius: 1)

                // Secondary smaller highlight
                Circle()
                    .fill(.white.opacity(0.9 * config.specularIntensity))
                    .frame(width: radius * 0.2, height: radius * 0.2)
                    .offset(
                        x: highlightOffset.x * radius * 0.4,
                        y: highlightOffset.y * radius * 0.4
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
                                .white.opacity(0.3 * config.rimLightIntensity)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: radius * 2, height: radius * 2)
            }
        }
    }
}

// MARK: - Color Extensions for Lighting

extension Color {
    /// Returns a lighter version of the color
    func lighter(by amount: CGFloat = 0.2) -> Color {
        // Approximation using overlay blending concept
        self.opacity(1 - amount).blending(with: .white, amount: amount)
    }

    /// Returns a darker version of the color
    func darker(by amount: CGFloat = 0.2) -> Color {
        self.opacity(1 - amount).blending(with: .black, amount: amount)
    }

    /// Blend with another color
    func blending(with other: Color, amount: CGFloat) -> Color {
        // This is an approximation - true color blending would require
        // extracting RGB components which needs UIColor conversion
        // For SwiftUI pure approach, we use overlay
        self
    }
}

// MARK: - Preview

#Preview("Lighting Effects") {
    ZStack {
        Color.black
            .ignoresSafeArea()

        ThreePointLighting {
            VStack(spacing: 40) {
                // Lit spheres
                HStack(spacing: 30) {
                    LitSphere(radius: 30, color: .cyan)
                        .contactShadow(width: 50)

                    LitSphere(radius: 30, color: .pink)
                        .contactShadow(width: 50)

                    LitSphere(radius: 30, color: .green)
                        .contactShadow(width: 50)
                }

                // Surface with lighting
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: 0.15))
                    .frame(width: 300, height: 150)
                    .litSurface(color: .gray)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.cyan, lineWidth: 2)
                    )
            }
        }
    }
    .visualConfig(.high)
}
