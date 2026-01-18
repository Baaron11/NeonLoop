/**
 * TiltTable Controller View - Phone Input View
 *
 * The input view for players on their phones.
 * Supports two input methods:
 * 1. Device Tilt: Using CoreMotion to detect phone orientation
 * 2. Swipe/Drag: Swipe left/right on screen to move avatar
 *
 * Shows a visual representation of the player's position on the ring.
 */

import SwiftUI
import CoreMotion

struct TiltTableControllerView: View {
    let state: TiltTableState
    let playerId: String
    let onMove: (CGFloat) -> Void  // Delta angle to move
    let onExit: () -> Void

    @StateObject private var motionManager = TiltMotionManager()
    @State private var lastDragX: CGFloat = 0
    @State private var inputMode: InputMode = .swipe

    enum InputMode: String, CaseIterable {
        case swipe = "Swipe"
        case tilt = "Tilt"

        var icon: String {
            switch self {
            case .swipe: return "hand.draw"
            case .tilt: return "iphone.gen3.radiowaves.left.and.right"
            }
        }
    }

    private var currentPlayer: TiltTablePlayer? {
        state.players.first { $0.id == playerId }
    }

    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()

            // Grid pattern
            ControllerGridBackground()

            VStack(spacing: 0) {
                // Header with player info and input toggle
                headerView
                    .padding(.top, 16)

                Spacer()

                // Mini table view showing player position
                miniTableView
                    .frame(width: 280, height: 280)

                Spacer()

                // Instructions
                instructionsView
                    .padding(.bottom, 20)

                // Input area (full width for gestures)
                inputArea
                    .frame(height: 180)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
            }

            // Countdown overlay
            if case .countdown(let count) = state.phase {
                ControllerCountdownOverlay(count: count)
            }

            // Result overlay
            if case .complete = state.phase, let result = state.result {
                ControllerResultOverlay(result: result, onExit: onExit)
            }
        }
        .onAppear {
            if inputMode == .tilt {
                motionManager.startMonitoring()
            }
        }
        .onDisappear {
            motionManager.stopMonitoring()
        }
        .onChange(of: inputMode) { _, newMode in
            if newMode == .tilt {
                motionManager.startMonitoring()
            } else {
                motionManager.stopMonitoring()
            }
        }
        .onChange(of: motionManager.roll) { _, newRoll in
            if inputMode == .tilt && state.phase.isActive {
                // Convert device roll to movement
                // Roll ranges from about -0.5 to 0.5 for comfortable tilting
                let movement = newRoll * 0.05  // Scale down for smooth movement
                onMove(movement)
            }
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            // Exit button
            Button(action: onExit) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.gray)
            }

            Spacer()

            // Player indicator
            if let player = currentPlayer {
                HStack(spacing: 8) {
                    Circle()
                        .fill(player.color)
                        .frame(width: 16, height: 16)
                    Text("P\(player.displayNumber)")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(player.color)
                }
            }

            Spacer()

            // Input mode toggle
            Menu {
                ForEach(InputMode.allCases, id: \.self) { mode in
                    Button {
                        inputMode = mode
                    } label: {
                        Label(mode.rawValue, systemImage: mode.icon)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: inputMode.icon)
                    Text(inputMode.rawValue)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                }
                .foregroundStyle(.cyan)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .stroke(.cyan.opacity(0.5), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Mini Table View

    private var miniTableView: some View {
        ZStack {
            // Table background
            Circle()
                .fill(Color(white: 0.1))
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.pink.opacity(0.5), .cyan.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )

            // Player ring
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                .padding(20)

            // Holes (simplified)
            ForEach(state.holes) { hole in
                let pos = hole.position(config: state.config)
                let scale: CGFloat = 0.7

                Circle()
                    .fill(hole.isPlugged ? .gray.opacity(0.2) : hole.holeType.color.opacity(0.3))
                    .frame(width: 20, height: 20)
                    .position(
                        x: 140 + pos.x * scale,
                        y: 140 + pos.y * scale
                    )
            }

            // Other players (dimmed)
            ForEach(state.players.filter { $0.id != playerId }) { player in
                let pos = player.position(config: state.config)
                let scale: CGFloat = 0.7

                Circle()
                    .fill(player.color.opacity(0.3))
                    .frame(width: 16, height: 16)
                    .position(
                        x: 140 + pos.x * scale,
                        y: 140 + pos.y * scale
                    )
            }

            // Current player (highlighted)
            if let player = currentPlayer {
                let pos = player.position(config: state.config)
                let scale: CGFloat = 0.7

                ZStack {
                    Circle()
                        .fill(player.color.opacity(0.4))
                        .frame(width: 40, height: 40)
                        .blur(radius: 8)

                    Circle()
                        .fill(player.color)
                        .frame(width: 24, height: 24)

                    Text("P\(player.displayNumber)")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.black)
                }
                .position(
                    x: 140 + pos.x * scale,
                    y: 140 + pos.y * scale
                )
            }

            // Ball (if playing)
            if state.phase.isActive {
                let scale: CGFloat = 0.7

                Circle()
                    .fill(.white)
                    .frame(width: 12, height: 12)
                    .shadow(color: .white.opacity(0.5), radius: 4)
                    .position(
                        x: 140 + state.ball.position.x * scale,
                        y: 140 + state.ball.position.y * scale
                    )
            }

            // Tilt indicator arrow
            if state.tableTilt.magnitude > 0.01 {
                let tiltScale: CGFloat = 100
                Arrow()
                    .stroke(.pink, lineWidth: 2)
                    .frame(width: 30, height: 30)
                    .rotationEffect(.radians(atan2(state.tableTilt.dy, state.tableTilt.dx)))
                    .offset(
                        x: state.tableTilt.dx * tiltScale,
                        y: state.tableTilt.dy * tiltScale
                    )
                    .opacity(Double(state.tableTilt.magnitude) * 2)
            }
        }
    }

    // MARK: - Instructions View

    private var instructionsView: some View {
        VStack(spacing: 8) {
            Text(inputMode == .swipe ? "SWIPE LEFT/RIGHT" : "TILT PHONE LEFT/RIGHT")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(.cyan)

            Text("Move around the ring to tilt the table")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.gray)
        }
    }

    // MARK: - Input Area

    private var inputArea: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(white: 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                currentPlayer?.color.opacity(0.3) ?? .cyan.opacity(0.3),
                                lineWidth: 2
                            )
                    )

                // Direction indicators
                HStack {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.gray.opacity(0.3))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.gray.opacity(0.3))
                }
                .padding(.horizontal, 30)

                // Center dot
                Circle()
                    .fill(currentPlayer?.color ?? .cyan)
                    .frame(width: 20, height: 20)
                    .opacity(0.5)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard inputMode == .swipe, state.phase.isActive else { return }

                        let deltaX = value.translation.width - lastDragX
                        lastDragX = value.translation.width

                        // Convert horizontal drag to angular movement
                        // Negative because dragging right should move clockwise (negative angle)
                        let angularDelta = -deltaX * 0.008
                        onMove(angularDelta)
                    }
                    .onEnded { _ in
                        lastDragX = 0
                    }
            )
        }
    }
}

// MARK: - Arrow Shape

private struct Arrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        // Arrow pointing right
        path.move(to: CGPoint(x: 0, y: height * 0.5))
        path.addLine(to: CGPoint(x: width * 0.7, y: height * 0.5))
        path.move(to: CGPoint(x: width * 0.5, y: height * 0.2))
        path.addLine(to: CGPoint(x: width, y: height * 0.5))
        path.addLine(to: CGPoint(x: width * 0.5, y: height * 0.8))

        return path
    }
}

// MARK: - Motion Manager

class TiltMotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    @Published var roll: CGFloat = 0  // Left/right tilt

    func startMonitoring() {
        guard motionManager.isDeviceMotionAvailable else { return }

        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let motion = motion, error == nil else { return }

            // Roll is rotation around the axis pointing out of the screen
            // When holding phone in portrait, tilting left/right changes roll
            self?.roll = motion.attitude.roll
        }
    }

    func stopMonitoring() {
        motionManager.stopDeviceMotionUpdates()
        roll = 0
    }
}

// MARK: - Grid Background

private struct ControllerGridBackground: View {
    var body: some View {
        Canvas { context, size in
            let gridSize: CGFloat = 30

            for x in stride(from: 0, through: size.width, by: gridSize) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(.cyan.opacity(0.05)), lineWidth: 0.5)
            }

            for y in stride(from: 0, through: size.height, by: gridSize) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(.cyan.opacity(0.05)), lineWidth: 0.5)
            }
        }
    }
}

// MARK: - Countdown Overlay

private struct ControllerCountdownOverlay: View {
    let count: Int

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("GET READY")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(.gray)
                    .tracking(4)

                Text(count > 0 ? "\(count)" : "GO!")
                    .font(.system(size: 100, weight: .bold, design: .monospaced))
                    .foregroundStyle(count > 0 ? .white : .cyan)
                    .shadow(color: (count > 0 ? Color.white : .cyan).opacity(0.8), radius: 20)
            }
        }
    }
}

// MARK: - Result Overlay

private struct ControllerResultOverlay: View {
    let result: TiltTableHole
    let onExit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: resultIcon)
                    .font(.system(size: 50))
                    .foregroundStyle(result.holeType.color)
                    .shadow(color: result.holeType.color.opacity(0.8), radius: 15)

                Text(result.label.uppercased())
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(result.holeType.color)
                    .multilineTextAlignment(.center)

                Text(resultDescription)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.gray)

                Button(action: onExit) {
                    Text("Continue")
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(result.holeType.color)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)
            }
            .padding(40)
        }
    }

    private var resultIcon: String {
        switch result.holeType {
        case .game: return "gamecontroller.fill"
        case .goodModifier: return "star.fill"
        case .badModifier: return "exclamationmark.triangle.fill"
        }
    }

    private var resultDescription: String {
        switch result.holeType {
        case .game: return "This game will be played next"
        case .goodModifier: return "A bonus has been applied"
        case .badModifier: return "A penalty has been applied"
        }
    }
}

// MARK: - Preview

#Preview {
    let state = TiltTableState()
    state.setupPlayers(count: 2)
    state.phase = .playing

    return TiltTableControllerView(
        state: state,
        playerId: "player_0",
        onMove: { _ in },
        onExit: {}
    )
}
