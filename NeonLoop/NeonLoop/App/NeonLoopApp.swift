/**
 * NeonLoop - iOS Air Hockey Game
 *
 * Main app entry point using SwiftUI.
 * This app is a port of the web-based Neon Puck air hockey game.
 */

import SwiftUI

@main
struct NeonLoopApp: App {
    @State private var gameCoordinator = GameCoordinator()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(gameCoordinator)
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Content View (Root Navigation)

struct ContentView: View {
    @Environment(GameCoordinator.self) var coordinator

    var body: some View {
        Group {
            switch coordinator.appState {
            case .launcher:
                GameLauncherView()
            case .home:
                HomeView()
            case .lobby:
                LobbyView()
            case .playing:
                ControllerView()
            case .playingTiltTable:
                TiltTableGameView()
            case .placeholderGame(let gameInfo):
                PlaceholderGameView(gameInfo: gameInfo)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: coordinator.appState)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environment(GameCoordinator())
}
