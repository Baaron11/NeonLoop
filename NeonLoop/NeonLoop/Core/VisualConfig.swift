/**
 * VisualConfig - Quality Settings for Cinematic Effects
 *
 * Provides a unified configuration for all visual effects with three quality tiers:
 * - Low: Minimal effects for older devices (iPhone SE, base iPad)
 * - Medium: Balanced effects for mid-range devices (iPhone 12, iPad Air)
 * - High: Full effects for flagship devices (iPhone 14 Pro, iPad Pro)
 *
 * All effects are designed to maintain 60fps on their target devices.
 */

import SwiftUI

// MARK: - Visual Quality Level

enum VisualQuality: String, CaseIterable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var id: String { rawValue }

    /// Auto-detect quality based on device capabilities
    static var automatic: VisualQuality {
        // Use ProcessInfo to estimate device capability
        let processorCount = ProcessInfo.processInfo.processorCount
        let memory = ProcessInfo.processInfo.physicalMemory

        // High: 6+ cores and 6GB+ RAM (iPhone 14 Pro, iPad Pro)
        if processorCount >= 6 && memory >= 6_000_000_000 {
            return .high
        }
        // Medium: 4+ cores and 4GB+ RAM (iPhone 12, iPad Air)
        else if processorCount >= 4 && memory >= 4_000_000_000 {
            return .medium
        }
        // Low: Everything else
        return .low
    }
}

// MARK: - Visual Configuration

struct VisualConfig {
    let quality: VisualQuality

    // MARK: - Post-Processing (Cinematic Look)

    /// Enable ACES-inspired tonemapping color adjustments
    var tonemappingEnabled: Bool {
        quality != .low
    }

    /// Bloom intensity (0 = off, 1 = full)
    var bloomIntensity: CGFloat {
        switch quality {
        case .low: return 0.3
        case .medium: return 0.6
        case .high: return 0.8
        }
    }

    /// Bloom blur radius
    var bloomRadius: CGFloat {
        switch quality {
        case .low: return 8
        case .medium: return 12
        case .high: return 16
        }
    }

    /// Vignette intensity (0 = off, 1 = strong)
    var vignetteIntensity: CGFloat {
        switch quality {
        case .low: return 0.2
        case .medium: return 0.35
        case .high: return 0.45
        }
    }

    /// Film grain intensity (0 = off, 1 = very visible)
    var filmGrainIntensity: CGFloat {
        switch quality {
        case .low: return 0
        case .medium: return 0.03
        case .high: return 0.05
        }
    }

    /// Chromatic aberration strength (0 = off)
    var chromaticAberrationStrength: CGFloat {
        switch quality {
        case .low: return 0
        case .medium: return 1.0
        case .high: return 2.0
        }
    }

    /// Enable motion blur (expensive, only on high)
    var motionBlurEnabled: Bool {
        quality == .high
    }

    // MARK: - Lighting & Depth

    /// Enable rim lighting effect on objects
    var rimLightingEnabled: Bool {
        quality != .low
    }

    /// Rim light intensity
    var rimLightIntensity: CGFloat {
        switch quality {
        case .low: return 0
        case .medium: return 0.4
        case .high: return 0.6
        }
    }

    /// Enable fake shadows under objects
    var shadowsEnabled: Bool {
        true // Always on, but quality varies
    }

    /// Shadow blur radius
    var shadowBlurRadius: CGFloat {
        switch quality {
        case .low: return 2
        case .medium: return 4
        case .high: return 6
        }
    }

    /// Shadow opacity
    var shadowOpacity: CGFloat {
        switch quality {
        case .low: return 0.3
        case .medium: return 0.4
        case .high: return 0.5
        }
    }

    /// Enable atmospheric haze/fog for depth
    var fogEnabled: Bool {
        quality != .low
    }

    /// Fog intensity (0 = off, 1 = heavy)
    var fogIntensity: CGFloat {
        switch quality {
        case .low: return 0
        case .medium: return 0.1
        case .high: return 0.15
        }
    }

    // MARK: - Materials & Shaders

    /// Enable surface roughness variation
    var surfaceDetailEnabled: Bool {
        quality != .low
    }

    /// Enable specular highlights on metals
    var specularHighlightsEnabled: Bool {
        true
    }

    /// Specular highlight intensity
    var specularIntensity: CGFloat {
        switch quality {
        case .low: return 0.5
        case .medium: return 0.7
        case .high: return 0.9
        }
    }

    /// Enable emissive glow on neon elements
    var emissiveGlowEnabled: Bool {
        true
    }

    /// Emissive glow radius multiplier
    var emissiveGlowRadius: CGFloat {
        switch quality {
        case .low: return 0.6
        case .medium: return 1.0
        case .high: return 1.4
        }
    }

    /// Enable fake reflections
    var reflectionsEnabled: Bool {
        quality == .high
    }

    // MARK: - Energy Effects

    /// Enable ball motion trails
    var trailsEnabled: Bool {
        true
    }

    /// Trail length (number of positions to track)
    var trailLength: Int {
        switch quality {
        case .low: return 5
        case .medium: return 10
        case .high: return 15
        }
    }

    /// Trail opacity
    var trailOpacity: CGFloat {
        switch quality {
        case .low: return 0.3
        case .medium: return 0.5
        case .high: return 0.6
        }
    }

    /// Enable impact sparks on collisions
    var impactSparksEnabled: Bool {
        quality != .low
    }

    /// Number of spark particles
    var sparkParticleCount: Int {
        switch quality {
        case .low: return 0
        case .medium: return 4
        case .high: return 8
        }
    }

    /// Enable camera shake on impacts
    var cameraShakeEnabled: Bool {
        quality != .low
    }

    /// Camera shake intensity
    var cameraShakeIntensity: CGFloat {
        switch quality {
        case .low: return 0
        case .medium: return 2
        case .high: return 4
        }
    }

    /// Enable emissive pulse on hits
    var impactPulseEnabled: Bool {
        true
    }

    // MARK: - HUD

    /// Enable glass/blur panels behind HUD
    var hudBlurEnabled: Bool {
        quality != .low
    }

    /// HUD blur radius
    var hudBlurRadius: CGFloat {
        switch quality {
        case .low: return 0
        case .medium: return 8
        case .high: return 12
        }
    }

    /// Enable HUD animations (timer pulse, score tick)
    var hudAnimationsEnabled: Bool {
        true
    }

    // MARK: - Preset Configurations

    static let low = VisualConfig(quality: .low)
    static let medium = VisualConfig(quality: .medium)
    static let high = VisualConfig(quality: .high)

    /// Auto-detect best quality for current device
    static var automatic: VisualConfig {
        VisualConfig(quality: VisualQuality.automatic)
    }
}

// MARK: - Global Visual Settings

/// Singleton for accessing visual configuration throughout the app
@Observable
final class VisualSettings {
    static let shared = VisualSettings()

    var config: VisualConfig
    var quality: VisualQuality {
        didSet {
            config = VisualConfig(quality: quality)
        }
    }

    private init() {
        let detectedQuality = VisualQuality.automatic
        self.quality = detectedQuality
        self.config = VisualConfig(quality: detectedQuality)
    }

    /// Reset to auto-detected quality
    func resetToAutomatic() {
        quality = VisualQuality.automatic
    }
}

// MARK: - Environment Key

private struct VisualConfigKey: EnvironmentKey {
    static let defaultValue: VisualConfig = .automatic
}

extension EnvironmentValues {
    var visualConfig: VisualConfig {
        get { self[VisualConfigKey.self] }
        set { self[VisualConfigKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    /// Apply visual configuration to the view hierarchy
    func visualConfig(_ config: VisualConfig) -> some View {
        environment(\.visualConfig, config)
    }
}
