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
        let _ = print("📱 [ContentView] body EVALUATED - appState: \(coordinator.appState)")
        let _ = print("📱 [ContentView]   - tiltTableCoordinator: \(coordinator.tiltTableCoordinator != nil ? "EXISTS" : "NIL")")

        Group {
            switch coordinator.appState {
            case .launcher:
                let _ = print("📱 [ContentView]   → Showing GameLauncherView")
                GameLauncherView()
            case .home:
                HomeView()
            case .lobby:
                LobbyView()
            case .playing:
                let _ = print("📱 [ContentView]   → Showing ControllerView (Polygon Hockey)")
                ControllerView()
            case .playingTiltTable:
                let _ = print("📱 [ContentView]   → Showing TiltTableGameView")
                let _ = print("📱 [ContentView]   → tiltTableCoordinator at switch: \(coordinator.tiltTableCoordinator != nil ? "EXISTS" : "NIL")")
                TiltTableGameView()
            case .playingBilliardDodge:
                let _ = print("📱 [ContentView]   → Showing BilliardDodgeGameView")
                let _ = print("📱 [ContentView]   → billiardDodgeCoordinator at switch: \(coordinator.billiardDodgeCoordinator != nil ? "EXISTS" : "NIL")")
                BilliardDodgeGameView()
            case .playingHordeDefense:
                let _ = print("📱 [ContentView]   → Showing HordeDefenseGameView")
                let _ = print("📱 [ContentView]   → hordeDefenseCoordinator at switch: \(coordinator.hordeDefenseCoordinator != nil ? "EXISTS" : "NIL")")
                HordeDefenseGameView()
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
