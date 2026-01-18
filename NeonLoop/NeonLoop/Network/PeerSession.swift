/**
 * Peer Session - MultipeerConnectivity Wrapper
 *
 * Handles peer-to-peer networking for local multiplayer using
 * MultipeerConnectivity framework (Wi-Fi/Bluetooth).
 *
 * Architecture: Host-authoritative
 * - Host runs the game simulation
 * - Clients send input to host
 * - Host broadcasts state snapshots to clients
 */

import Foundation
import MultipeerConnectivity
import Combine

// MARK: - Peer Session Delegate

protocol PeerSessionDelegate: AnyObject {
    func peerSession(_ session: PeerSession, didReceiveInput input: InputMessage)
    func peerSession(_ session: PeerSession, didReceiveState state: GameState)
    func peerSession(_ session: PeerSession, peerDidJoin peerId: String, name: String)
    func peerSession(_ session: PeerSession, peerDidLeave peerId: String)
    func peerSession(_ session: PeerSession, didChangeState state: PeerSessionState)
}

// MARK: - Session State

enum PeerSessionState {
    case idle
    case hosting
    case joining
    case connected
    case disconnected
}

// MARK: - Peer Session

final class PeerSession: NSObject, ObservableObject {
    // MARK: - Properties

    @Published private(set) var state: PeerSessionState = .idle
    @Published private(set) var connectedPeers: [MCPeerID] = []
    @Published private(set) var isHost: Bool = false

    weak var delegate: PeerSessionDelegate?

    private let serviceType = "neonloop-game"
    private var peerId: MCPeerID!
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    // Room info
    private(set) var roomCode: String?
    private(set) var playerName: String = "Player"

    // MARK: - Initialization

    override init() {
        super.init()
    }

    // MARK: - Setup

    func setup(playerName: String) {
        self.playerName = playerName
        self.peerId = MCPeerID(displayName: playerName)
        self.session = MCSession(
            peer: peerId,
            securityIdentity: nil,
            encryptionPreference: .required
        )
        self.session.delegate = self
    }

    // MARK: - Hosting

    func startHosting(roomCode: String) {
        guard state == .idle else { return }

        self.roomCode = roomCode
        self.isHost = true

        // Start advertising with room code in discovery info
        advertiser = MCNearbyServiceAdvertiser(
            peer: peerId,
            discoveryInfo: ["roomCode": roomCode],
            serviceType: serviceType
        )
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()

        state = .hosting
        delegate?.peerSession(self, didChangeState: .hosting)
    }

    func stopHosting() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        state = .idle
        delegate?.peerSession(self, didChangeState: .idle)
    }

    // MARK: - Joining

    func startBrowsing() {
        guard state == .idle else { return }

        browser = MCNearbyServiceBrowser(peer: peerId, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()

        state = .joining
        delegate?.peerSession(self, didChangeState: .joining)
    }

    func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        browser = nil
        state = .idle
        delegate?.peerSession(self, didChangeState: .idle)
    }

    func joinRoom(host: MCPeerID) {
        browser?.invitePeer(host, to: session, withContext: nil, timeout: 30)
    }

    // MARK: - Disconnecting

    func disconnect() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session.disconnect()

        advertiser = nil
        browser = nil
        connectedPeers = []
        isHost = false
        roomCode = nil
        state = .disconnected
        delegate?.peerSession(self, didChangeState: .disconnected)
    }

    // MARK: - Sending Data

    func sendInput(_ input: InputMessage) {
        guard !connectedPeers.isEmpty else { return }

        do {
            let data = try JSONEncoder().encode(input)
            try session.send(data, toPeers: connectedPeers, with: .reliable)
        } catch {
            print("Failed to send input: \(error)")
        }
    }

    func sendGameState(_ state: GameState) {
        guard isHost && !connectedPeers.isEmpty else { return }

        let message = StateSnapshotMessage(
            senderId: peerId.displayName,
            timestamp: Date.timeIntervalSinceReferenceDate,
            state: state
        )

        do {
            let data = try JSONEncoder().encode(message)
            try session.send(data, toPeers: connectedPeers, with: .unreliable)
        } catch {
            print("Failed to send game state: \(error)")
        }
    }

    func broadcastMinimalSnapshot(_ snapshot: MinimalSnapshot) {
        guard isHost && !connectedPeers.isEmpty else { return }

        do {
            let data = try JSONEncoder().encode(snapshot)
            try session.send(data, toPeers: connectedPeers, with: .unreliable)
        } catch {
            print("Failed to send snapshot: \(error)")
        }
    }
}

// MARK: - MCSessionDelegate

extension PeerSession: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            switch state {
            case .connected:
                if !self.connectedPeers.contains(peerID) {
                    self.connectedPeers.append(peerID)
                }
                self.state = .connected
                self.delegate?.peerSession(self, peerDidJoin: peerID.displayName, name: peerID.displayName)
                self.delegate?.peerSession(self, didChangeState: .connected)

            case .notConnected:
                self.connectedPeers.removeAll { $0 == peerID }
                self.delegate?.peerSession(self, peerDidLeave: peerID.displayName)
                if self.connectedPeers.isEmpty {
                    self.state = self.isHost ? .hosting : .idle
                }

            case .connecting:
                break

            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Try to decode as input message
        if let input = try? JSONDecoder().decode(InputMessage.self, from: data) {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.peerSession(self, didReceiveInput: input)
            }
            return
        }

        // Try to decode as state snapshot
        if let message = try? JSONDecoder().decode(StateSnapshotMessage.self, from: data) {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.peerSession(self, didReceiveState: message.state)
            }
            return
        }

        // Try to decode as minimal snapshot
        if let snapshot = try? JSONDecoder().decode(MinimalSnapshot.self, from: data) {
            // Apply snapshot to local state
            // This would typically be handled by the delegate
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        // Not used
    }

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        // Not used
    }

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        // Not used
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension PeerSession: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Auto-accept invitations when hosting
        invitationHandler(true, session)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("Failed to start advertising: \(error)")
        state = .idle
        delegate?.peerSession(self, didChangeState: .idle)
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension PeerSession: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        // Check if this is the room we're looking for
        if let roomCode = info?["roomCode"], roomCode == self.roomCode {
            joinRoom(host: peerID)
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        // Host went away
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("Failed to start browsing: \(error)")
        state = .idle
        delegate?.peerSession(self, didChangeState: .idle)
    }
}
