/**
 * Game Controller Manager - Hardware Controller Support
 *
 * Handles MFi, PlayStation, and Xbox controllers via GameController framework.
 * Provides unified input from physical game controllers.
 */

import Foundation
import GameController

final class GameControllerManager {
    // MARK: - Properties

    private var connectedController: GCController?
    private var onDirectionInput: ((InputState) -> Void)?
    private var onActionInput: ((InputAction) -> Void)?

    // Current direction state
    private var currentDirection = InputState()

    // MARK: - Initialization

    init(
        onDirectionInput: @escaping (InputState) -> Void,
        onAction: @escaping (InputAction) -> Void
    ) {
        self.onDirectionInput = onDirectionInput
        self.onActionInput = onAction

        setupControllerNotifications()
        connectToAvailableController()
    }

    // MARK: - Setup

    private func setupControllerNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDidConnect),
            name: .GCControllerDidConnect,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDidDisconnect),
            name: .GCControllerDidDisconnect,
            object: nil
        )
    }

    private func connectToAvailableController() {
        if let controller = GCController.controllers().first {
            setupController(controller)
        }
    }

    @objc private func controllerDidConnect(_ notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        setupController(controller)
    }

    @objc private func controllerDidDisconnect(_ notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        if controller == connectedController {
            connectedController = nil
            currentDirection = InputState()
        }
    }

    // MARK: - Controller Setup

    private func setupController(_ controller: GCController) {
        connectedController = controller

        // Extended gamepad (Xbox, PlayStation, MFi Extended)
        if let extendedGamepad = controller.extendedGamepad {
            setupExtendedGamepad(extendedGamepad)
        }
        // Micro gamepad (Siri Remote, etc.)
        else if let microGamepad = controller.microGamepad {
            setupMicroGamepad(microGamepad)
        }

        print("Game controller connected: \(controller.vendorName ?? "Unknown")")
    }

    private func setupExtendedGamepad(_ gamepad: GCExtendedGamepad) {
        // D-Pad
        gamepad.dpad.valueChangedHandler = { [weak self] _, xValue, yValue in
            self?.handleDPadInput(x: xValue, y: yValue)
        }

        // Left thumbstick (primary movement)
        gamepad.leftThumbstick.valueChangedHandler = { [weak self] _, xValue, yValue in
            self?.handleThumbstickInput(x: xValue, y: yValue)
        }

        // A button (confirm)
        gamepad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                self?.onActionInput?(.confirm)
            }
        }

        // B button (cancel)
        gamepad.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                self?.onActionInput?(.cancel)
            }
        }

        // Menu button (pause)
        gamepad.buttonMenu.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                self?.onActionInput?(.pause)
            }
        }
    }

    private func setupMicroGamepad(_ gamepad: GCMicroGamepad) {
        // D-Pad (touch surface on Siri Remote)
        gamepad.dpad.valueChangedHandler = { [weak self] _, xValue, yValue in
            self?.handleDPadInput(x: xValue, y: yValue)
        }

        // A button
        gamepad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                self?.onActionInput?(.confirm)
            }
        }

        // X button
        gamepad.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                self?.onActionInput?(.cancel)
            }
        }

        // Menu button
        gamepad.buttonMenu.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                self?.onActionInput?(.pause)
            }
        }
    }

    // MARK: - Input Handling

    private func handleDPadInput(x: Float, y: Float) {
        updateDirectionState(x: x, y: y)
    }

    private func handleThumbstickInput(x: Float, y: Float) {
        updateDirectionState(x: x, y: y, deadzone: 0.2)
    }

    private func updateDirectionState(x: Float, y: Float, deadzone: Float = 0.1) {
        var newDirection = InputState()

        if x < -deadzone { newDirection.left = true }
        if x > deadzone { newDirection.right = true }
        if y > deadzone { newDirection.up = true }  // Y is inverted
        if y < -deadzone { newDirection.down = true }

        // Only notify if direction changed
        if newDirection.up != currentDirection.up ||
           newDirection.down != currentDirection.down ||
           newDirection.left != currentDirection.left ||
           newDirection.right != currentDirection.right {
            currentDirection = newDirection
            onDirectionInput?(newDirection)
        }
    }

    // MARK: - Public API

    var isControllerConnected: Bool {
        connectedController != nil
    }

    var controllerName: String? {
        connectedController?.vendorName
    }
}
