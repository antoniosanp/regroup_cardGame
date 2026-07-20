# Regroup — mobile client (React Native / Expo)

Android/iOS port of the `frontend/` web client. Same backend, same
`WS_CONTRACT.md` STOMP contract, same server-authoritative store — the client
never computes game rules.

## Run it

Start the backend first (`backend/`, listens on :8080), then:

```bash
cd mobile
npm install
npm run android   # Android emulator, or scan the QR with Expo Go on a phone
```

Backend address resolution (`src/online/config.ts`):

- **Android emulator**: uses `10.0.2.2:8080` (the emulator's alias for your machine).
- **Physical phone via Expo Go**: derives your dev machine's LAN IP from the
  Metro bundler host automatically — phone and computer must be on the same
  network, and the backend must listen on `0.0.0.0`.
- **Override**: set `expo.extra.backendUrl` in `app.json`, e.g.
  `"extra": { "backendUrl": "http://192.168.1.50:8080" }`.

## What's different from the web client

- **Placement is tap-driven**, not drag-and-drop: with a held card, choose the
  anchor corner (TL/TR/BL/BR), tap a point on your board to preview, then
  confirm with "Place here".
- **Battle phase is animated** (`src/components/BattleStage.tsx`): each
  attacker's badge lunges at its defender, a physical (⚔️ orange) or magic
  (✦ blue) projectile flies across, the defender shakes and damage numbers
  float up; heals and eliminations play afterwards, followed by the full battle
  log. Every number shown comes from the server's `BATTLE_RESULT` — the
  animation is presentation only.
- Identity persists in AsyncStorage instead of localStorage.
- `src/online/messages.ts` (contract parsing) is byte-identical to the web
  client's copy; keep the two in sync when the contract changes.
