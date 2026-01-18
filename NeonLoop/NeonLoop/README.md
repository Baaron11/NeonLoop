# NeonLoop - iOS Air Hockey Game

A SwiftUI-based air hockey game ported from the web prototype "Neon Puck".

## Project Setup

Since this scaffold doesn't include a full `.xcodeproj`, you'll need to create the Xcode project manually.

### Option 1: Create New Xcode Project

1. Open Xcode
2. Create a new project: **File → New → Project**
3. Select **App** under iOS
4. Configure:
   - Product Name: `NeonLoop`
   - Team: Your Apple Developer Team
   - Organization Identifier: `com.yourcompany`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Uncheck "Include Tests" (for now)

5. After creating, delete the default `ContentView.swift` and `NeonLoopApp.swift`

6. Add all Swift files from this directory:
   - **App/**: `NeonLoopApp.swift`
   - **Core/**: `GameTypes.swift`, `GameRules.swift`, `MatchState.swift`, `GameCoordinator.swift`, `AIOpponent.swift`
   - **Views/**: `HomeView.swift`, `LobbyView.swift`, `ControllerView.swift`
   - **Input/**: `InputRouter.swift`, `GameControllerManager.swift`
   - **Network/**: `PeerSession.swift`, `NetMessages.swift`

7. Organize files into groups matching the folder structure

### Option 2: Swift Package

You can also create a Swift Package:

```bash
cd NeonLoop
swift package init --type executable --name NeonLoop
```

Then add the source files and update `Package.swift`.

## Required Capabilities

Add these capabilities in Xcode:

1. **Background Modes** (optional, for multiplayer)
   - Uses Bluetooth LE accessories
   - Acts as a Bluetooth LE accessory

2. **Wireless Accessory Configuration** (for MultipeerConnectivity)

## Info.plist Entries

Add these to your `Info.plist`:

```xml
<!-- MultipeerConnectivity -->
<key>NSLocalNetworkUsageDescription</key>
<string>NeonLoop uses local networking for multiplayer games.</string>

<key>NSBonjourServices</key>
<array>
    <string>_neonloop-game._tcp</string>
    <string>_neonloop-game._udp</string>
</array>

<!-- Game Controller -->
<key>GCSupportsControllerUserInteraction</key>
<true/>
```

## Building and Running

1. Select a target device (iPhone/iPad simulator or real device)
2. Press **Cmd + R** to build and run

## Architecture

```
NeonLoop/
├── App/
│   └── NeonLoopApp.swift          # App entry point
├── Core/
│   ├── GameTypes.swift            # Data models (Position, Velocity, GameState, etc.)
│   ├── GameRules.swift            # Physics and collision logic
│   ├── MatchState.swift           # Observable game state
│   ├── GameCoordinator.swift      # Game loop and orchestration
│   └── AIOpponent.swift           # AI paddle logic
├── Views/
│   ├── HomeView.swift             # Main menu
│   ├── LobbyView.swift            # Multiplayer lobby
│   └── ControllerView.swift       # Game screen with table and controls
├── Input/
│   ├── InputRouter.swift          # Unified input handling
│   └── GameControllerManager.swift # MFi/PS/Xbox controller support
└── Network/
    ├── PeerSession.swift          # MultipeerConnectivity wrapper
    └── NetMessages.swift          # Network message types
```

## Game Modes

### Single Player
- Play against AI with three difficulty levels (Easy, Medium, Hard)
- AI uses prediction-based movement

### Local Multiplayer (WIP)
- Host-authoritative architecture
- Uses MultipeerConnectivity for local Wi-Fi/Bluetooth
- Room codes for easy joining

## Features

- **Neon visual style** with glow effects
- **Dynamic play area** - divider shifts when you score
- **Stuck puck detection** - auto-boost if puck stops moving
- **Haptic feedback** on hits and goals
- **Game controller support** for MFi, PlayStation, and Xbox controllers

## MVP Milestones

### Milestone 1: Local Single-Device (Current)
- [x] Project scaffold
- [x] Core game types
- [x] Physics engine
- [x] AI opponent
- [x] Touch input
- [x] SwiftUI views
- [ ] Testing and polish

### Milestone 2: Local Multiplayer
- [x] MultipeerConnectivity setup
- [x] Network message types
- [ ] Host-authoritative game loop
- [ ] Input synchronization
- [ ] Lobby UI completion

### Milestone 3: External Display
- [ ] AirPlay detection
- [ ] Second-screen game view
- [ ] Controller-only device view

## Differences from Web Version

| Feature | Web | iOS |
|---------|-----|-----|
| Rendering | SVG/React | SwiftUI Canvas |
| Game Loop | requestAnimationFrame | CADisplayLink |
| Audio | Web Audio API | AVAudioEngine (TBD) |
| Networking | Supabase Realtime | MultipeerConnectivity |
| Input | DOM events | UIKit gestures + GameController |

## License

MIT
