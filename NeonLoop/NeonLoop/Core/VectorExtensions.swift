/**
 * VectorExtensions - Shared CGVector and CGPoint Math Extensions
 *
 * Consolidates all vector/point math operations used across multiple games
 * to avoid duplicate extension definitions and ambiguous method errors.
 */

import CoreGraphics

// MARK: - CGVector Extensions

extension CGVector {
    /// The length (magnitude) of the vector
    var magnitude: CGFloat {
        sqrt(dx * dx + dy * dy)
    }

    /// Alias for magnitude (for compatibility)
    var length: CGFloat {
        magnitude
    }

    /// Returns a unit vector in the same direction
    var normalized: CGVector {
        let mag = magnitude
        guard mag > 0 else { return .zero }
        return CGVector(dx: dx / mag, dy: dy / mag)
    }

    /// Returns a new vector scaled by the given factor
    func scaled(by factor: CGFloat) -> CGVector {
        CGVector(dx: dx * factor, dy: dy * factor)
    }

    /// Dot product with another vector
    func dot(_ other: CGVector) -> CGFloat {
        dx * other.dx + dy * other.dy
    }

    /// Vector addition
    static func + (lhs: CGVector, rhs: CGVector) -> CGVector {
        CGVector(dx: lhs.dx + rhs.dx, dy: lhs.dy + rhs.dy)
    }

    /// Vector subtraction
    static func - (lhs: CGVector, rhs: CGVector) -> CGVector {
        CGVector(dx: lhs.dx - rhs.dx, dy: lhs.dy - rhs.dy)
    }
}

// MARK: - CGPoint Extensions

extension CGPoint {
    /// Distance to another point
    func distance(to other: CGPoint) -> CGFloat {
        let dx = other.x - x
        let dy = other.y - y
        return sqrt(dx * dx + dy * dy)
    }

    /// Add a vector to a point
    static func + (lhs: CGPoint, rhs: CGVector) -> CGPoint {
        CGPoint(x: lhs.x + rhs.dx, y: lhs.y + rhs.dy)
    }

    /// Subtract two points to get a vector
    static func - (lhs: CGPoint, rhs: CGPoint) -> CGVector {
        CGVector(dx: lhs.x - rhs.x, dy: lhs.y - rhs.y)
    }
}
