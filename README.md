# Regroup

A 4-player online card game: each player builds their own board out of picked
cards, then every round ends in an all-vs-all battle phase based on the stats
their board produces. See `backend/gameRules.md` for the full rules and
`backend/WS_CONTRACT.md` for the exact backend/frontend wire contract.

- `backend/` — Spring Boot 3 (Java 21) game server: rules engine, matchmaking,
  WebSocket/STOMP, guest identity. No accounts/JWT, no database — everything
  lives in memory for the life of the process.
- `frontend/` — React + TypeScript + Vite client (STOMP over WebSocket).

## Requirements

- Java 21 and Maven 3.6+
- Node.js 18+ and npm

## Run locally

Two terminals, from the project root:

```bash
# Terminal 1 — backend (port 8080)
cd backend
mvn spring-boot:run
```

```bash
# Terminal 2 — frontend (port 5173)
cd frontend
npm install
npm run dev
```

Open `http://localhost:5173` in **4 separate tabs or browsers** (Regroup needs
exactly 4 players per match). In each tab, enter a name and join the queue — a
match starts as soon as 4 players are queued.

The frontend talks to the backend via `VITE_BACKEND_URL` (default
`http://localhost:8080`); the STOMP WebSocket URL is derived from it
automatically (`http → ws`, path `/ws`). Override it with a `.env.local` in
`frontend/` (see `frontend/.env.example`) or an env var:

```bash
VITE_BACKEND_URL=http://localhost:8080 npm run dev
```

## How a match works, briefly

- No login: entering a name registers a guest identity (`POST /api/players`)
  and stores an opaque token used to reconnect.
- Everything is public — every player's board, the shared 3-card market, and
  everyone's stats are visible to all players at all times. There's no hidden
  information to protect, unlike a simultaneous-commit card game.
- Turns are strict round-robin: on your turn, pick a card (from the market's
  A/B/C slots — priced 0/1/2 coins — or the free face-down deck), optionally
  rotate it, then place it on your own board. Placing ends your turn.
- Once every living player has placed for the round, the battle phase
  resolves automatically (all-vs-all, see `WS_CONTRACT.md`), and the next
  round begins.
- A turn that goes 30 seconds without a placement is auto-played (free deck
  draw, placed at the first legal spot) so a slow or disconnected player
  never blocks the match.
- The match ends when one player remains, or when cards run low enough to
  trigger the final round (see `gameRules.md`) — in either end-of-cards case,
  the highest-hp player wins, ties share the win.

## Status

Backend and frontend were built together against a shared contract but have
not yet been compiled, built, or run end-to-end — treat this as an untested
first pass. Run both sides locally and work through any build errors or wire
mismatches before relying on it.
