/**
 * HordeDefense Rails - Rail System for Paddle Movement
 *
 * Handles the rail system that paddles move along:
 * - Concentric rings
 * - Radial spokes connecting rings
 * - Junction points where paddles can switch between rings
 */

import Foundation
import SwiftUI

// MARK: - Rail Segment Type

enum RailSegmentType: Equatable {
    case ring(ringIndex: Int)
    case spoke(spokeIndex: Int)
}

// MARK: - Rail Segment

struct RailSegment: Identifiable, Equatable {
    let id: String
    let type: RailSegmentType
    let startPoint: CGPoint
    let endPoint: CGPoint
    // For ring segments, also include arc info
    let arcCenter: CGPoint?
    let arcRadius: CGFloat?
    let startAngle: CGFloat?
    let endAngle: CGFloat?

    /// Check if this is a ring segment
    var isRing: Bool {
        if case .ring = type { return true }
        return false
    }

    /// Check if this is a spoke segment
    var isSpoke: Bool {
        if case .spoke = type { return true }
        return false
    }
}

// MARK: - Junction Point

struct JunctionPoint: Identifiable, Equatable {
    let id: String
    let position: CGPoint
    let ringIndex: Int
    let spokeIndex: Int

    /// Create a rail position for this junction on the ring
    func toRailPosition(config: HordeDefenseConfig) -> RailPosition {
        let spokeAngle = CGFloat(spokeIndex) * (2 * .pi / CGFloat(config.spokeCount))
        return RailPosition.onRing(ringIndex, angle: spokeAngle)
    }
}

// MARK: - Rail System

struct RailSystem {
    let config: HordeDefenseConfig
    let center: CGPoint

    init(config: HordeDefenseConfig) {
        self.config = config
        self.center = CGPoint(x: config.arenaRadius, y: config.arenaRadius)
    }

    // MARK: - Junction Points

    /// Get all junction points (where spokes meet rings)
    func junctionPoints() -> [JunctionPoint] {
        var junctions: [JunctionPoint] = []

        for ringIndex in 0..<config.ringRadii.count {
            let radius = config.ringRadii[ringIndex]

            for spokeIndex in 0..<config.spokeCount {
                let angle = CGFloat(spokeIndex) * (2 * .pi / CGFloat(config.spokeCount))
                let position = CGPoint(
                    x: center.x + cos(angle) * radius,
                    y: center.y + sin(angle) * radius
                )

                junctions.append(JunctionPoint(
                    id: "junction_\(ringIndex)_\(spokeIndex)",
                    position: position,
                    ringIndex: ringIndex,
                    spokeIndex: spokeIndex
                ))
            }
        }

        return junctions
    }

    /// Check if a position is at a junction
    func isAtJunction(_ position: RailPosition) -> Bool {
        return position.isAtJunction(config: config)
    }

    /// Get the nearest junction to a position
    func nearestJunction(to position: RailPosition) -> JunctionPoint? {
        let point = position.toPoint(config: config)
        let junctions = junctionPoints()

        return junctions.min { j1, j2 in
            distance(from: point, to: j1.position) < distance(from: point, to: j2.position)
        }
    }

    // MARK: - Rail Segments

    /// Get all rail segments (for rendering)
    func railSegments() -> [RailSegment] {
        var segments: [RailSegment] = []

        // Add ring segments
        for ringIndex in 0..<config.ringRadii.count {
            let radius = config.ringRadii[ringIndex]

            // Create arcs between spokes
            for spokeIndex in 0..<config.spokeCount {
                let startAngle = CGFloat(spokeIndex) * (2 * .pi / CGFloat(config.spokeCount))
                let endAngle = CGFloat((spokeIndex + 1) % config.spokeCount) * (2 * .pi / CGFloat(config.spokeCount))

                let startPoint = CGPoint(
                    x: center.x + cos(startAngle) * radius,
                    y: center.y + sin(startAngle) * radius
                )
                let endPoint = CGPoint(
                    x: center.x + cos(endAngle) * radius,
                    y: center.y + sin(endAngle) * radius
                )

                segments.append(RailSegment(
                    id: "ring_\(ringIndex)_\(spokeIndex)",
                    type: .ring(ringIndex: ringIndex),
                    startPoint: startPoint,
                    endPoint: endPoint,
                    arcCenter: center,
                    arcRadius: radius,
                    startAngle: startAngle,
                    endAngle: endAngle
                ))
            }
        }

        // Add spoke segments
        for spokeIndex in 0..<config.spokeCount {
            let angle = CGFloat(spokeIndex) * (2 * .pi / CGFloat(config.spokeCount))

            // Inner spoke segment (from center goal edge to first ring)
            let innerStart = CGPoint(
                x: center.x + cos(angle) * (config.centerGoalRadius + 10),
                y: center.y + sin(angle) * (config.centerGoalRadius + 10)
            )
            let innerEnd = CGPoint(
                x: center.x + cos(angle) * config.ringRadii[0],
                y: center.y + sin(angle) * config.ringRadii[0]
            )

            segments.append(RailSegment(
                id: "spoke_\(spokeIndex)_inner",
                type: .spoke(spokeIndex: spokeIndex),
                startPoint: innerStart,
                endPoint: innerEnd,
                arcCenter: nil,
                arcRadius: nil,
                startAngle: nil,
                endAngle: nil
            ))

            // Spoke segments between rings
            for ringIndex in 0..<(config.ringRadii.count - 1) {
                let startRadius = config.ringRadii[ringIndex]
                let endRadius = config.ringRadii[ringIndex + 1]

                let startPoint = CGPoint(
                    x: center.x + cos(angle) * startRadius,
                    y: center.y + sin(angle) * startRadius
                )
                let endPoint = CGPoint(
                    x: center.x + cos(angle) * endRadius,
                    y: center.y + sin(angle) * endRadius
                )

                segments.append(RailSegment(
                    id: "spoke_\(spokeIndex)_\(ringIndex)",
                    type: .spoke(spokeIndex: spokeIndex),
                    startPoint: startPoint,
                    endPoint: endPoint,
                    arcCenter: nil,
                    arcRadius: nil,
                    startAngle: nil,
                    endAngle: nil
                ))
            }
        }

        return segments
    }

    /// Get ring arcs only (for rendering complete rings)
    func ringArcs() -> [(ringIndex: Int, radius: CGFloat)] {
        config.ringRadii.enumerated().map { (index, radius) in
            (ringIndex: index, radius: radius)
        }
    }

    /// Get spoke lines only (for rendering)
    func spokeLines() -> [(spokeIndex: Int, angle: CGFloat, innerRadius: CGFloat, outerRadius: CGFloat)] {
        (0..<config.spokeCount).map { spokeIndex in
            let angle = CGFloat(spokeIndex) * (2 * .pi / CGFloat(config.spokeCount))
            return (
                spokeIndex: spokeIndex,
                angle: angle,
                innerRadius: config.centerGoalRadius + 10,
                outerRadius: config.ringRadii.last ?? config.arenaRadius
            )
        }
    }

    // MARK: - Movement

    /// Move along rail in a direction, returning new position
    func move(from position: RailPosition, direction: RailDirection, distance: CGFloat) -> RailPosition {
        // This delegates to HordeDefenseState's moveAlongRail implementation
        // which is more complete. This is here for protocol conformance.
        var newPosition = position

        if position.isOnSpoke {
            guard let spokeIdx = position.spokeIndex,
                  var progress = position.spokeProgress else {
                return position
            }

            let ringRadius0 = position.ringIndex == 0
                ? config.centerGoalRadius + 10
                : config.ringRadii[max(0, position.ringIndex - 1)]
            let ringRadius1 = position.ringIndex < config.ringRadii.count
                ? config.ringRadii[position.ringIndex]
                : config.arenaRadius
            let spokeLength = ringRadius1 - ringRadius0
            let progressDelta = distance / spokeLength

            switch direction {
            case .inward:
                progress -= progressDelta
                if progress <= 0 {
                    let newRingIndex = max(0, position.ringIndex - 1)
                    let spokeAngle = CGFloat(spokeIdx) * (2 * .pi / CGFloat(config.spokeCount))
                    newPosition = RailPosition.onRing(newRingIndex, angle: spokeAngle)
                } else {
                    newPosition.spokeProgress = progress
                }

            case .outward:
                progress += progressDelta
                if progress >= 1 {
                    let newRingIndex = min(config.ringRadii.count - 1, position.ringIndex)
                    let spokeAngle = CGFloat(spokeIdx) * (2 * .pi / CGFloat(config.spokeCount))
                    newPosition = RailPosition.onRing(newRingIndex, angle: spokeAngle)
                } else {
                    newPosition.spokeProgress = progress
                }

            default:
                break
            }
        } else {
            let ringRadius = position.ringIndex < config.ringRadii.count
                ? config.ringRadii[position.ringIndex]
                : config.arenaRadius
            let circumference = 2 * .pi * ringRadius
            let angleDelta = (distance / circumference) * 2 * .pi

            switch direction {
            case .clockwise:
                newPosition.angle = normalizeAngle(position.angle + angleDelta)

            case .counterClockwise:
                newPosition.angle = normalizeAngle(position.angle - angleDelta)

            default:
                break
            }
        }

        return newPosition
    }

    // MARK: - Collision Detection

    /// Get the closest point on the rail system to a given point
    func closestPointOnRails(to point: CGPoint) -> (point: CGPoint, distance: CGFloat, normal: CGVector)? {
        var closestResult: (point: CGPoint, distance: CGFloat, normal: CGVector)?
        var minDistance = CGFloat.infinity

        // Check rings
        for radius in config.ringRadii {
            let distFromCenter = self.distance(from: center, to: point)
            let distToRing = abs(distFromCenter - radius)

            if distToRing < minDistance {
                minDistance = distToRing

                // Closest point on ring
                let angle = atan2(point.y - center.y, point.x - center.x)
                let closestPoint = CGPoint(
                    x: center.x + cos(angle) * radius,
                    y: center.y + sin(angle) * radius
                )

                // Normal points outward from center if inside ring, inward if outside
                let normalDirection: CGFloat = distFromCenter < radius ? -1 : 1
                let normal = CGVector(
                    dx: cos(angle) * normalDirection,
                    dy: sin(angle) * normalDirection
                )

                closestResult = (closestPoint, distToRing, normal)
            }
        }

        // Check spokes
        for spokeIndex in 0..<config.spokeCount {
            let angle = CGFloat(spokeIndex) * (2 * .pi / CGFloat(config.spokeCount))
            let innerRadius = config.centerGoalRadius + 10
            let outerRadius = config.ringRadii.last ?? config.arenaRadius

            let spokeStart = CGPoint(
                x: center.x + cos(angle) * innerRadius,
                y: center.y + sin(angle) * innerRadius
            )
            let spokeEnd = CGPoint(
                x: center.x + cos(angle) * outerRadius,
                y: center.y + sin(angle) * outerRadius
            )

            let result = closestPointOnLineSegment(point: point, lineStart: spokeStart, lineEnd: spokeEnd)

            if result.distance < minDistance {
                minDistance = result.distance

                // Normal perpendicular to spoke
                let perpAngle = angle + .pi / 2
                let dx = point.x - result.point.x
                let dy = point.y - result.point.y
                let sign: CGFloat = (dx * cos(perpAngle) + dy * sin(perpAngle)) >= 0 ? 1 : -1

                let normal = CGVector(
                    dx: cos(perpAngle) * sign,
                    dy: sin(perpAngle) * sign
                )

                closestResult = (result.point, result.distance, normal)
            }
        }

        return closestResult
    }

    /// Check if a point is inside a rail "wall" (for collision)
    func isInsideRail(point: CGPoint, railThickness: CGFloat) -> (isInside: Bool, normal: CGVector)? {
        guard let closest = closestPointOnRails(to: point) else { return nil }

        let isInside = closest.distance < railThickness / 2
        return (isInside, closest.normal)
    }

    // MARK: - Helper Functions

    private func distance(from p1: CGPoint, to p2: CGPoint) -> CGFloat {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        return sqrt(dx * dx + dy * dy)
    }

    private func closestPointOnLineSegment(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> (point: CGPoint, distance: CGFloat) {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        let lengthSquared = dx * dx + dy * dy

        if lengthSquared == 0 {
            // Line segment is a point
            let d = distance(from: point, to: lineStart)
            return (lineStart, d)
        }

        // Project point onto line
        var t = ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / lengthSquared
        t = max(0, min(1, t)) // Clamp to segment

        let closestPoint = CGPoint(
            x: lineStart.x + t * dx,
            y: lineStart.y + t * dy
        )

        let d = distance(from: point, to: closestPoint)
        return (closestPoint, d)
    }
}

// MARK: - Rail Rendering Helpers

extension RailSystem {
    /// Create a Path for a ring arc
    func ringPath(ringIndex: Int) -> Path {
        var path = Path()
        let radius = config.ringRadii[ringIndex]

        path.addArc(
            center: center,
            radius: radius,
            startAngle: .zero,
            endAngle: .degrees(360),
            clockwise: false
        )

        return path
    }

    /// Create a Path for a spoke
    func spokePath(spokeIndex: Int) -> Path {
        var path = Path()
        let angle = CGFloat(spokeIndex) * (2 * .pi / CGFloat(config.spokeCount))
        let innerRadius = config.centerGoalRadius + 10
        let outerRadius = config.ringRadii.last ?? config.arenaRadius

        let start = CGPoint(
            x: center.x + cos(angle) * innerRadius,
            y: center.y + sin(angle) * innerRadius
        )
        let end = CGPoint(
            x: center.x + cos(angle) * outerRadius,
            y: center.y + sin(angle) * outerRadius
        )

        path.move(to: start)
        path.addLine(to: end)

        return path
    }

    /// Create a Path for the center goal
    func centerGoalPath() -> Path {
        var path = Path()
        path.addArc(
            center: center,
            radius: config.centerGoalRadius,
            startAngle: .zero,
            endAngle: .degrees(360),
            clockwise: false
        )
        return path
    }

    /// Create a Path for the outer arena boundary
    func outerBoundaryPath() -> Path {
        var path = Path()
        path.addArc(
            center: center,
            radius: config.arenaRadius,
            startAngle: .zero,
            endAngle: .degrees(360),
            clockwise: false
        )
        return path
    }

    /// Create a Path for an enemy goal arc
    func enemyGoalPath(goal: EnemyGoal) -> Path {
        var path = Path()
        let radius = config.arenaRadius

        path.addArc(
            center: center,
            radius: radius,
            startAngle: .radians(goal.startAngle),
            endAngle: .radians(goal.endAngle),
            clockwise: false
        )

        return path
    }
}
