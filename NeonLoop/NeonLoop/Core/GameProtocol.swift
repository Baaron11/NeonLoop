/**
 * Game Protocol - Unified Interface for All NeonLoop Games
 *
 * Defines the common protocol that all mini-games (Polygon Hockey, Horde Defense,
 * Pinball Sabotage, Billiard Dodge, Foosball, Tilt Table) must conform to.
 */

import SwiftUI

// MARK: - Game Input Types

/// The type of input a game expects from players
enum GameInputType: String, Codable, CaseIterable {
    case position       // Air hockey paddle, tilt table avatar - direct position control
    case vector         // Billiard dodge - angle + force selection
    case swipeAndTap    // Foosball - swipe to move rod, double-tap to kick
    case tilt           // Tilt table alternative - device tilt input
}

/// Actual input events sent from players to games
enum GameInput: Equatable {
    case position(CGPoint)
    case vector(angle: CGFloat, force: CGFloat)
    case swipe(delta: CGFloat)
    case doubleTap
    case tilt(x: CGFloat, y: CGFloat)
}

// MARK: - Game Modifiers

/// Modifiers that can alter gameplay (roguelike mutations, power-ups, etc.)
struct GameModifier: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let description: String
    let intensity: Int  // 1-10 scale

    static let none = GameModifier(id: "none", name: "None", description: "No modifier", intensity: 0)

    // Example modifiers for future use
    static let speedBoost = GameModifier(id: "speed_boost", name: "Speed Boost", description: "Everything moves faster", intensity: 5)
    static let giantPuck = GameModifier(id: "giant_puck", name: "Giant Puck", description: "Puck is 2x size", intensity: 3)
    static let multiPuck = GameModifier(id: "multi_puck", name: "Multi-Puck", description: "Multiple pucks in play", intensity: 7)
}

// MARK: - Player

/// Represents a connected player
struct Player: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let teamIndex: Int  // 0 or 1 for team games
    let slotIndex: Int  // Position within team (0-2 for up to 3 per team)

    var displayColor: PlayerColor {
        teamIndex == 0 ? .cyan : .pink
    }
}

enum PlayerColor: String, Codable {
    case cyan
    case pink
    case green
    case orange

    var color: Color {
        switch self {
        case .cyan: return .cyan
        case .pink: return .pink
        case .green: return .green
        case .orange: return .orange
        }
    }
}

// MARK: - Game Info

/// Static information about a game for display in launcher
struct GameInfo: Identifiable {
    let id: String
    let name: String
    let subtitle: String
    let description: String
    let minPlayers: Int
    let maxPlayers: Int
    let inputType: GameInputType
    let isImplemented: Bool
    let iconName: String
    let accentColor: Color
}

// MARK: - Game Registry

/// Central registry of all available games
enum NeonLoopGameRegistry {
    static let allGames: [GameInfo] = [
        GameInfo(
            id: "polygon_hockey",
            name: "Polygon Hockey",
            subtitle: "Air Hockey Arena",
            description: "Classic air hockey with neon style. Defend your goal and score on your opponent.",
            minPlayers: 1,
            maxPlayers: 4,
            inputType: .position,
            isImplemented: true,
            iconName: "circle.hexagonpath",
            accentColor: .cyan
        ),
        GameInfo(
            id: "horde_defense",
            name: "Horde Defense",
            subtitle: "Defend the Core",
            description: "Defend the center goal while scoring on enemy goals. Move along rails to deflect pucks!",
            minPlayers: 1,
            maxPlayers: 3,
            inputType: .position,
            isImplemented: true,
            iconName: "shield.lefthalf.filled",
            accentColor: .green
        ),
        GameInfo(
            id: "pinball_sabotage",
            name: "Pinball Sabotage",
            subtitle: "Be the Ball",
            description: "You ARE the ball! Try to drain before the CPU hits its high score. Sabotage the flippers!",
            minPlayers: 1,
            maxPlayers: 4,
            inputType: .vector,
            isImplemented: false,
            iconName: "circle.dotted",
            accentColor: .orange
        ),
        GameInfo(
            id: "billiard_dodge",
            name: "Billiard Dodge",
            subtitle: "Predict & Escape",
            description: "Survive the CPU's billiard shots! You have 5 seconds to pick your escape vector. Don't get pocketed!",
            minPlayers: 1,
            maxPlayers: 4,
            inputType: .vector,
            isImplemented: true,
            iconName: "arrow.triangle.branch",
            accentColor: .purple
        ),
        GameInfo(
            id: "foosball",
            name: "Foosball",
            subtitle: "Rod Control",
            description: "Distributed rod control with linked movement. Swipe to slide, double-tap to kick!",
            minPlayers: 2,
            maxPlayers: 4,
            inputType: .swipeAndTap,
            isImplemented: false,
            iconName: "rectangle.split.3x1",
            accentColor: .yellow
        ),
        GameInfo(
            id: "tilt_table",
            name: "Tilt Table",
            subtitle: "The Deciding Game",
            description: "Players move around the ring to tilt the table. Guide the ball into the hole to select the next game!",
            minPlayers: 1,
            maxPlayers: 6,
            inputType: .position,
            isImplemented: true,
            iconName: "circle.and.line.horizontal",
            accentColor: .pink
        )
    ]

    static func game(withId id: String) -> GameInfo? {
        allGames.first { $0.id == id }
    }
}

// MARK: - NeonLoop Game Protocol

/// Protocol that all NeonLoop mini-games must conform to
protocol NeonLoopGame: AnyObject {
    /// Unique identifier for this game type
    var gameId: String { get }

    /// Display name of the game
    var gameName: String { get }

    /// Whether this game is fully implemented and playable
    var isImplemented: Bool { get }

    /// Minimum number of players required
    var minPlayers: Int { get }

    /// Maximum number of players supported
    var maxPlayers: Int { get }

    /// The type of input this game expects
    var inputType: GameInputType { get }

    /// Set up the game with the given players and modifiers
    func setup(players: [Player], modifiers: [GameModifier])

    /// Handle input from a specific player
    func handleInput(playerId: String, input: GameInput)

    /// Update game state (called each frame)
    func update(deltaTime: CGFloat)

    /// Check if the game has ended
    var isGameOver: Bool { get }

    /// Get the winning player/team (nil if game not over or tie)
    var winner: Player? { get }
}

// MARK: - Base Game Class (Optional helper)

/// Base class providing common functionality for NeonLoop games
class BaseNeonLoopGame: NeonLoopGame {
    let gameId: String
    let gameName: String
    let isImplemented: Bool
    let minPlayers: Int
    let maxPlayers: Int
    let inputType: GameInputType

    var players: [Player] = []
    var modifiers: [GameModifier] = []
    var isGameOver: Bool = false
    var winner: Player? = nil

    init(
        gameId: String,
        gameName: String,
        isImplemented: Bool,
        minPlayers: Int,
        maxPlayers: Int,
        inputType: GameInputType
    ) {
        self.gameId = gameId
        self.gameName = gameName
        self.isImplemented = isImplemented
        self.minPlayers = minPlayers
        self.maxPlayers = maxPlayers
        self.inputType = inputType
    }

    func setup(players: [Player], modifiers: [GameModifier]) {
        self.players = players
        self.modifiers = modifiers
        self.isGameOver = false
        self.winner = nil
    }

    func handleInput(playerId: String, input: GameInput) {
        // Override in subclasses
    }

    func update(deltaTime: CGFloat) {
        // Override in subclasses
    }
}
