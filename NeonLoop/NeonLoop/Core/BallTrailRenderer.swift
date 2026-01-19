/**
 * BallTrailRenderer - Motion Trails for Fast-Moving Objects
 *
 * Renders subtle energy trails behind balls when moving fast:
 * - Thin, fading trails that follow ball motion
 * - Color-matched to ball color
 * - Velocity-based opacity (faster = more visible)
 *
 * Uses position history tracking for smooth trail rendering.
 */

import SwiftUI

// MARK: - Trail Point

/// A single point in a motion trail
struct TrailPoint: Identifiable {
    let id: UUID
    let position: CGPoint
    let timestamp: Date
    let velocity: CGFloat

    init(position: CGPoint, velocity: CGFloat) {
        self.id = UUID()
        self.position = position
        self.timestamp = Date()
        self.velocity = velocity
    }

    /// Age of the point in seconds
    var age: TimeInterval {
        Date().timeIntervalSince(timestamp)
    }
}

// MARK: - Ball Trail Data

/// Tracks trail data for a single ball
struct BallTrailData: Identifiable {
    let id: String
    let color: Color
    var points: [TrailPoint]

    init(id: String, color: Color) {
        self.id = id
        self.color = color
        self.points = []
    }

    /// Add a new point to the trail
    mutating func addPoint(position: CGPoint, velocity: CGFloat) {
        // Only add points when moving at significant speed
        guard velocity > 0.5 else {
            // Clear trail when stopped
            points.removeAll()
            return
        }

        let point = TrailPoint(position: position, velocity: velocity)
        points.append(point)

        // Remove old points (keep max based on config)
        let maxAge: TimeInterval = 0.3
        points.removeAll { $0.age > maxAge }
    }

    /// Clear all trail points
    mutating func clear() {
        points.removeAll()
    }
}

// MARK: - Trail Manager

/// Manages trails for all balls
@Observable
final class TrailManager {
    var trails: [String: BallTrailData] = [:]

    /// Update trail for a ball
    func updateTrail(
        id: String,
        position: CGPoint,
        velocity: CGVector,
        color: Color
    ) {
        let speed = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)

        if trails[id] == nil {
            trails[id] = BallTrailData(id: id, color: color)
        }

        trails[id]?.addPoint(position: position, velocity: speed)
    }

    /// Clear trail for a ball
    func clearTrail(id: String) {
        trails[id]?.clear()
    }

    /// Clear all trails
    func clearAll() {
        trails.removeAll()
    }
}

// MARK: - Trail Renderer View

/// Renders a single ball's motion trail
struct BallTrailView: View {
    let trail: BallTrailData
    let ballRadius: CGFloat
    let scaleX: CGFloat
    let scaleY: CGFloat

    @Environment(\.visualConfig) private var config

    var body: some View {
        if config.trailsEnabled && trail.points.count > 1 {
            Canvas { context, size in
                let points = trail.points

                // Draw trail as gradient line
                for i in 1..<points.count {
                    let current = points[i]
                    let previous = points[i - 1]

                    // Calculate opacity based on age and velocity
                    let ageFactor = max(0, 1 - (current.age / 0.3))
                    let velocityFactor = min(1, current.velocity / 10)
                    let opacity = ageFactor * velocityFactor * config.trailOpacity

                    // Skip nearly invisible segments
                    guard opacity > 0.05 else { continue }

                    // Draw line segment
                    var path = Path()
                    path.move(to: CGPoint(
                        x: previous.position.x * scaleX,
                        y: previous.position.y * scaleY
                    ))
                    path.addLine(to: CGPoint(
                        x: current.position.x * scaleX,
                        y: current.position.y * scaleY
                    ))

                    // Line width tapers based on age
                    let lineWidth = ballRadius * 0.6 * ageFactor

                    context.stroke(
                        path,
                        with: .color(trail.color.opacity(opacity)),
                        lineWidth: lineWidth
                    )
                }
            }
        }
    }
}

// MARK: - All Trails Layer

/// Renders trails for all tracked balls
struct TrailsLayer: View {
    let trails: [String: BallTrailData]
    let ballRadius: CGFloat
    let scaleX: CGFloat
    let scaleY: CGFloat

    @Environment(\.visualConfig) private var config

    var body: some View {
        if config.trailsEnabled {
            ZStack {
                ForEach(Array(trails.values)) { trail in
                    BallTrailView(
                        trail: trail,
                        ballRadius: ballRadius,
                        scaleX: scaleX,
                        scaleY: scaleY
                    )
                }
            }
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Energy Trail Effect

/// More intense energy trail effect for special moments
struct EnergyTrailEffect: View {
    let points: [CGPoint]
    let color: Color
    let width: CGFloat

    @Environment(\.visualConfig) private var config

    var body: some View {
        if points.count > 1 {
            Canvas { context, size in
                // Draw gradient trail
                var path = Path()
                path.move(to: points[0])

                for point in points.dropFirst() {
                    path.addLine(to: point)
                }

                // Outer glow
                context.stroke(
                    path,
                    with: .color(color.opacity(0.3)),
                    lineWidth: width * 3
                )

                // Core
                context.stroke(
                    path,
                    with: .color(color.opacity(0.8)),
                    lineWidth: width
                )
            }
            .blur(radius: 2)
        }
    }
}

// MARK: - Speed Lines Effect

/// Comic-style speed lines for very fast motion
struct SpeedLinesEffect: View {
    let position: CGPoint
    let velocity: CGVector
    let color: Color
    let intensity: CGFloat

    @Environment(\.visualConfig) private var config

    var body: some View {
        let speed = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)
        let threshold: CGFloat = 8.0

        if speed > threshold && config.trailsEnabled {
            let angle = atan2(velocity.dy, velocity.dx)
            let lineCount = min(5, Int(speed / 3))

            ForEach(0..<lineCount, id: \.self) { index in
                SpeedLine(
                    angle: angle,
                    length: 15 + CGFloat(index) * 5,
                    offset: CGFloat(index) * 8,
                    color: color,
                    opacity: intensity * (1 - CGFloat(index) / CGFloat(lineCount))
                )
                .position(position)
            }
        }
    }
}

/// Individual speed line
struct SpeedLine: View {
    let angle: CGFloat
    let length: CGFloat
    let offset: CGFloat
    let color: Color
    let opacity: CGFloat

    var body: some View {
        Rectangle()
            .fill(color.opacity(opacity))
            .frame(width: length, height: 2)
            .offset(x: -offset - length / 2, y: 0)
            .rotationEffect(.radians(angle))
    }
}

// MARK: - Comet Trail

/// Comet-style trail with particle falloff
struct CometTrail: View {
    let headPosition: CGPoint
    let tailPositions: [CGPoint]
    let color: Color
    let headRadius: CGFloat

    @Environment(\.visualConfig) private var config

    var body: some View {
        if tailPositions.count > 0 {
            ZStack {
                // Tail particles
                ForEach(Array(tailPositions.enumerated()), id: \.offset) { index, position in
                    let factor = 1 - CGFloat(index) / CGFloat(tailPositions.count)
                    let size = headRadius * 0.3 * factor

                    Circle()
                        .fill(color.opacity(factor * config.trailOpacity))
                        .frame(width: size, height: size)
                        .position(position)
                }

                // Connecting glow
                Canvas { context, size in
                    guard tailPositions.count > 1 else { return }

                    var path = Path()
                    path.move(to: headPosition)

                    for pos in tailPositions {
                        path.addLine(to: pos)
                    }

                    context.stroke(
                        path,
                        with: .color(color.opacity(0.2 * config.trailOpacity)),
                        lineWidth: headRadius * 0.5
                    )
                }
                .blur(radius: 3)
            }
            .blendMode(.plusLighter)
        }
    }
}

// MARK: - Motion Blur Simulation

/// Fake motion blur by drawing multiple offset copies
struct MotionBlurEffect<Content: View>: View {
    let velocity: CGVector
    let content: Content
    let blurSteps: Int

    @Environment(\.visualConfig) private var config

    init(
        velocity: CGVector,
        blurSteps: Int = 3,
        @ViewBuilder content: () -> Content
    ) {
        self.velocity = velocity
        self.blurSteps = blurSteps
        self.content = content()
    }

    var body: some View {
        let speed = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)
        let threshold: CGFloat = 5.0

        if config.motionBlurEnabled && speed > threshold {
            let normalizedVelocity = CGVector(
                dx: velocity.dx / speed,
                dy: velocity.dy / speed
            )
            let blurDistance = min(speed * 0.5, 10)

            ZStack {
                // Motion blur copies
                ForEach(0..<blurSteps, id: \.self) { step in
                    let factor = CGFloat(step + 1) / CGFloat(blurSteps + 1)
                    let offset = CGSize(
                        width: -normalizedVelocity.dx * blurDistance * factor,
                        height: -normalizedVelocity.dy * blurDistance * factor
                    )

                    content
                        .offset(offset)
                        .opacity(0.2 * (1 - factor))
                }

                // Sharp original
                content
            }
        } else {
            content
        }
    }
}

// MARK: - Preview

#Preview("Trail Effects") {
    ZStack {
        Color.black.ignoresSafeArea()

        // Sample trails
        EnergyTrailEffect(
            points: [
                CGPoint(x: 50, y: 200),
                CGPoint(x: 100, y: 180),
                CGPoint(x: 150, y: 190),
                CGPoint(x: 200, y: 170),
                CGPoint(x: 250, y: 200)
            ],
            color: .cyan,
            width: 4
        )

        // Speed lines
        SpeedLinesEffect(
            position: CGPoint(x: 200, y: 400),
            velocity: CGVector(dx: 12, dy: -3),
            color: .pink,
            intensity: 0.8
        )

        // Motion blur example
        MotionBlurEffect(velocity: CGVector(dx: 10, dy: 0)) {
            Circle()
                .fill(.green)
                .frame(width: 30, height: 30)
        }
        .position(x: 200, y: 300)
    }
    .visualConfig(.high)
}
