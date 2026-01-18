/**
 * Input Router - Unified Input Handling
 *
 * Normalizes input from various sources:
 * - Touch/gesture input
 * - Hardware game controllers (MFi, PS, Xbox)
 * - Keyboard (for debugging on macOS)
 *
 * Outputs normalized Position or InputState that can be used by the game.
 */

import Foundation
import CoreGraphics
import Combine

// MARK: - Input Source

enum InputSource {
    case touch
    case gameController
    case keyboard
}

// MARK: - Input Event

struct InputEvent {
    let source: InputSource
    let timestamp: TimeInterval
    let position: Position?
    let direction: InputState?
    let action: InputAction?
}

enum InputAction {
    case pause
    case confirm
    case cancel
}

// MARK: - Input Router

final class InputRouter: ObservableObject {
    // MARK: - Properties

    @Published private(set) var currentInput: InputEvent?

    // Callbacks
    var onPositionInput: ((Position) -> Void)?
    var onDirectionInput: ((InputState) -> Void)?
    var onActionInput: ((InputAction) -> Void)?

    // Game controller manager
    private var controllerManager: GameControllerManager?

    // Keyboard state (for debugging)
    private var keyboardState = InputState()

    // MARK: - Initialization

    init() {
        setupControllerSupport()
    }

    // MARK: - Setup

    private func setupControllerSupport() {
        controllerManager = GameControllerManager { [weak self] direction in
            self?.handleDirectionInput(direction, source: .gameController)
        } onAction: { [weak self] action in
            self?.handleActionInput(action)
        }
    }

    // MARK: - Touch Input

    func handleTouchInput(position: Position) {
        let event = InputEvent(
            source: .touch,
            timestamp: Date.timeIntervalSinceReferenceDate,
            position: position,
            direction: nil,
            action: nil
        )
        currentInput = event
        onPositionInput?(position)
    }

    func handleTouchEnded() {
        currentInput = nil
    }

    // MARK: - Direction Input

    func handleDirectionInput(_ direction: InputState, source: InputSource = .keyboard) {
        let event = InputEvent(
            source: source,
            timestamp: Date.timeIntervalSinceReferenceDate,
            position: nil,
            direction: direction,
            action: nil
        )
        currentInput = event
        onDirectionInput?(direction)
    }

    // MARK: - Action Input

    func handleActionInput(_ action: InputAction) {
        let event = InputEvent(
            source: .gameController,
            timestamp: Date.timeIntervalSinceReferenceDate,
            position: nil,
            direction: nil,
            action: action
        )
        currentInput = event
        onActionInput?(action)
    }

    // MARK: - Keyboard Input (macOS/Catalyst)

    #if targetEnvironment(macCatalyst) || os(macOS)
    func handleKeyDown(_ key: String) {
        switch key.lowercased() {
        case "w", "arrowup":
            keyboardState.up = true
        case "s", "arrowdown":
            keyboardState.down = true
        case "a", "arrowleft":
            keyboardState.left = true
        case "d", "arrowright":
            keyboardState.right = true
        case " ":
            handleActionInput(.pause)
            return
        case "escape":
            handleActionInput(.cancel)
            return
        case "return", "enter":
            handleActionInput(.confirm)
            return
        default:
            return
        }
        handleDirectionInput(keyboardState, source: .keyboard)
    }

    func handleKeyUp(_ key: String) {
        switch key.lowercased() {
        case "w", "arrowup":
            keyboardState.up = false
        case "s", "arrowdown":
            keyboardState.down = false
        case "a", "arrowleft":
            keyboardState.left = false
        case "d", "arrowright":
            keyboardState.right = false
        default:
            return
        }
        handleDirectionInput(keyboardState, source: .keyboard)
    }
    #endif
}

// MARK: - Direction to Position Conversion

extension InputRouter {
    /// Convert direction input to paddle position delta
    func directionToPositionDelta(_ direction: InputState, speed: CGFloat = 8) -> Position {
        var dx: CGFloat = 0
        var dy: CGFloat = 0

        if direction.left { dx -= speed }
        if direction.right { dx += speed }
        if direction.up { dy -= speed }
        if direction.down { dy += speed }

        // Normalize diagonal movement
        if dx != 0 && dy != 0 {
            let factor = speed / sqrt(dx * dx + dy * dy)
            dx *= factor
            dy *= factor
        }

        return Position(x: dx, y: dy)
    }
}
