/**
 * Lobby View - Multiplayer Room Management
 *
 * Screen for creating/joining multiplayer rooms and waiting for players.
 * Uses MultipeerConnectivity for local Wi-Fi/Bluetooth multiplayer.
 */

import SwiftUI

struct LobbyView: View {
    @Environment(GameCoordinator.self) var coordinator
    @State private var showHostSheet = false
    @State private var showJoinSheet = false
    @State private var roomCode = ""
    @State private var playerName = "Player"

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                GridBackground()

                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 8) {
                        Text("MULTIPLAYER")
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundStyle(.pink)
                            .shadow(color: .pink.opacity(0.5), radius: 10)

                        Text("Local Wi-Fi / Bluetooth")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(.gray)
                    }
                    .padding(.top, 40)

                    Spacer()

                    // Player name input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Name")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.gray)

                        TextField("Enter name", text: $playerName)
                            .font(.system(size: 18, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(.cyan.opacity(0.5), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 40)

                    // Options
                    VStack(spacing: 16) {
                        // Host Game
                        LobbyButton(
                            title: "Host Game",
                            subtitle: "Create a room",
                            icon: "antenna.radiowaves.left.and.right",
                            color: .cyan
                        ) {
                            showHostSheet = true
                        }

                        // Join Game
                        LobbyButton(
                            title: "Join Game",
                            subtitle: "Enter room code",
                            icon: "qrcode.viewfinder",
                            color: .pink
                        ) {
                            showJoinSheet = true
                        }
                    }
                    .padding(.horizontal, 40)

                    Spacer()

                    // Note about local play
                    VStack(spacing: 4) {
                        Text("All players must be on the same")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.gray.opacity(0.6))
                        Text("Wi-Fi network or within Bluetooth range")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.gray.opacity(0.6))
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        coordinator.goToLauncher()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundStyle(.cyan)
                    }
                }
            }
        }
        .sheet(isPresented: $showHostSheet) {
            HostGameSheet(playerName: playerName) {
                showHostSheet = false
                // TODO: Start hosting with PeerSession
                coordinator.startMultiplayerGame()
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showJoinSheet) {
            JoinGameSheet(roomCode: $roomCode, playerName: playerName) {
                showJoinSheet = false
                // TODO: Join room with PeerSession
                coordinator.startMultiplayerGame()
            }
            .presentationDetents([.medium])
        }
    }
}

// MARK: - Lobby Button

struct LobbyButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .frame(width: 50)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    Text(subtitle)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.gray)
                }

                Spacer()

                Image(systemName: "chevron.right")
            }
            .foregroundStyle(color)
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Host Game Sheet

struct HostGameSheet: View {
    let playerName: String
    let onStart: () -> Void

    @State private var selectedMode: GameMode = .oneVsOne
    @State private var generatedCode = "------"

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Room code display
                VStack(spacing: 8) {
                    Text("Room Code")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(.gray)

                    Text(generatedCode)
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundStyle(.cyan)
                        .tracking(8)
                }
                .padding(.top, 20)

                // Mode selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Game Mode")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(.gray)

                    Picker("Mode", selection: $selectedMode) {
                        ForEach(GameMode.allCases.filter { $0 != .defense }, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Spacer()

                // Start button
                Button(action: onStart) {
                    Text("Start Hosting")
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(.cyan)
                        .cornerRadius(12)
                }
            }
            .padding()
            .navigationTitle("Host Game")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                generateRoomCode()
            }
        }
    }

    private func generateRoomCode() {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        generatedCode = String((0..<6).map { _ in chars.randomElement()! })
    }
}

// MARK: - Join Game Sheet

struct JoinGameSheet: View {
    @Binding var roomCode: String
    let playerName: String
    let onJoin: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Room code input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enter Room Code")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(.gray)

                    TextField("XXXXXX", text: $roomCode)
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.characters)
                        .foregroundStyle(.pink)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.pink.opacity(0.5), lineWidth: 1)
                        )
                }
                .padding(.top, 20)

                Spacer()

                // Join button
                Button(action: onJoin) {
                    Text("Join Room")
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(roomCode.count == 6 ? .pink : .gray)
                        .cornerRadius(12)
                }
                .disabled(roomCode.count != 6)
            }
            .padding()
            .navigationTitle("Join Game")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Preview

#Preview {
    LobbyView()
        .environment(GameCoordinator())
}
