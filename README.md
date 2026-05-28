# Ludo Kingdom: Premium Multiplayer Gaming Arena

Ludo Kingdom is a high-performance, real-time multiplayer Ludo platform built using **Node.js, MongoDB, and Socket.io** for the backend, and **Flutter (Riverpod + GoRouter)** for the frontend client.

---

## Technical Stack & Architecture

### Backend Architecture (MVC Pattern)
- **Runtime**: Node.js & Express.js
- **Database**: MongoDB & Mongoose
- **Real-Time Communication**: Socket.io (WebSocket namespaces & rooms)
- **Voice Communication Channel**: LiveKit Server SDK (generates token credentials dynamically)
- **Authentication**: JWT validation with Firebase ID verification fallbacks

### Frontend Client Architecture (Clean Feature-First)
- **Framework**: Flutter (Dart)
- **State Management**: flutter_riverpod (Provider scopes, StateNotifiers)
- **Navigation Routing**: go_router (Deep linking & dynamic routing)
- **Local Persistence**: Hive (Local JSON caches) & SharedPreferences (App settings)
- **Real-Time Audio**: livekit_client (WebRTC audio channels)
- **Visuals**: flutter_animate & Custom painted layouts

---

## Directory Structure

```
c:/Ludo_Game/
├── backend/
│   ├── src/
│   │   ├── config/          # Databases & Livekit / Firebase credentials
│   │   ├── controllers/     # REST Controller handlers (Auth, rewards, etc)
│   │   ├── middlewares/     # JWT Auth checking & suspension filters
│   │   ├── models/          # MongoDB Schema models (User, Room, Match, etc)
│   │   ├── routes/          # REST Endpoint routes mapping
│   │   ├── services/        # Ludo rules engine & AI Bot logic
│   │   └── sockets/         # Sockets matchmaker & turn controllers
│   ├── server.js            # Node HTTP & socket entrypoint
│   └── package.json
└── frontend/
    ├── lib/
    │   ├── core/            # App-wide routing, theme, and API connectors
    │   └── features/        # Feature blocks (Auth, Game board, Rewards, etc)
    └── pubspec.yaml
```

---

## Setup & Running Instructions

### 1. Prerequisites
- [Node.js](https://nodejs.org/) (v16+)
- [MongoDB Server](https://www.mongodb.com/) (running locally or a cloud URI)
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (latest stable version)

### 2. Run the Backend Server
1. Navigate to the backend directory:
   ```bash
   cd backend
   ```
2. Install dependencies:
   ```bash
   npm install
   ```
3. Set up environment variables. Copy the `.env.example` file to `.env`:
   ```bash
   cp .env.example .env
   ```
4. Adjust connection parameters:
   - Ensure `MONGODB_URI` points to your running Mongo instance (defaults to `mongodb://localhost:27017/ludo_db`).
   - `JWT_SECRET` can remain default for local development.
   - For offline/local developer testing, the server automatically bypasses Firebase Admin and LiveKit credentials if left blank, enabling local mocks.
5. Launch in development hot-reload mode:
   ```bash
   npm run dev
   ```

### 3. Run the Flutter Frontend Client
1. Navigate to the frontend directory:
   ```bash
   cd frontend
   ```
2. Verify package installation:
   ```bash
   flutter pub get
   ```
3. Launch the Flutter client on your connected device/simulator:
   ```bash
   flutter run
   ```

---

## Testing Multiplayer Matches & AI Bots (Developer Guide)

To easily verify turn-synchronization, token-killing, and audio toggling:

### 1. Practice Mode (vs AI Bot)
- On the home screen, select **Practice Mode** and tap **Easy**, **Medium**, or **Hard**.
- A local game room starts instantly using the client-side `LudoEngine`.
- Opponent turns are handled by automated heuristics which will roll, decide, and move pawns.

### 2. Multi-Player Online Matches (Local Sockets)
1. Ensure the Node.js backend server is running.
2. Launch two different emulator windows or two different browser windows:
   - Client A: Log in using the **Developer Fast Login** drawer with nickname `Player1`.
   - Client B: Log in using the **Developer Fast Login** drawer with nickname `Player2`.
3. On both client dashboards, click **Quick Match (2 Players)**.
4. The socket server's matchmaking queue will pair both players, deduct the `100` coin entry fee, and start the game room automatically.
5. Test turn rotations, rolling dice, capturing pawns, and message chats!
