/**
 * NeonLoop - iOS Air Hockey Game
 *
 * Main app entry point using SwiftUI.
 * This app is a port of the web-based Neon Puck air hockey game.
 */

import SwiftUI

@main
struct NeonLoopApp: App {
    @StateObject private var gameCoordinator = GameCoordinator()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gameCoordinator)
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Content View (Root Navigation)

struct ContentView: View {
    @EnvironmentObject var coordinator: GameCoordinator

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
        .environmentObject(GameCoordinator())
}
