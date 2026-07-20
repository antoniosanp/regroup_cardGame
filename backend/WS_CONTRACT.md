# WEBSOCKET CONTRACT — "Regroup" online mode

**Authoritative STOMP message contract between the Spring Boot backend and the React
client. Both sides MUST conform. Field names are exact (camelCase JSON).** Modeled on
the `cardGame/` reference project's contract style, adapted to Regroup's actual rules
in `gameRules.md`.

Regroup has **no hidden information** — every player's board and the face-up market
are visible to everyone at all times. Unlike a simultaneous-commit game, this is a
strict turn-order game: one player acts (pick → optional rotate → place) at a time.
That removes the "never reveal before everyone commits" machinery entirely; the only
things to get right are turn order, the battle phase, and elimination.

## Identity (guest, no accounts — no JWT/login)

`POST /api/players` body `{"name": "Alice"}` →
`{"playerId": "<uuid>", "token": "<opaque>", "name": "Alice"}`

Client stores `playerId` + `token`, sends `token` as the STOMP CONNECT header. Same
token reconnecting is recognized as the same player. WebSocket endpoint: `/ws`.

## Client → server (`/app` prefix)

| Destination | Payload | Meaning |
|---|---|---|
| `/app/queue.join` | `{}` | Enter the 4-player queue |
| `/app/queue.joinOffline` | `{}` | Start an offline match immediately: you take seat 0, seats 1-3 are filled by server-driven "easy" AI bots (display names `"Bot 1"`/`"Bot 2"`/`"Bot 3"`). No queue wait. Bots drive the identical `CARD_PICKED`/`CARD_PLACED`/`TURN_START`/etc. broadcasts a human would — no new wire shapes; the client renders their turns like any other player's. |
| `/app/queue.leave` | `{}` | Leave the queue before a match forms |
| `/app/match.{matchId}.pick` | `{"slot":"A"\|"B"\|"C"\|"DECK"}` | Pick a card: A/B/C from the market (priced 0/1/2 coins, or all free during the final round — see below) or the free face-down deck top. Must be this player's turn and no card already held. |
| `/app/match.{matchId}.rotate` | `{}` | Rotate the currently held card 90° clockwise. |
| `/app/match.{matchId}.place` | `{"corner":"TOP_LEFT"\|"TOP_RIGHT"\|"BOTTOM_LEFT"\|"BOTTOM_RIGHT","x":<int>,"y":<int>}` | Place the held card, anchoring `corner` at board point `(x,y)`. Ends the turn. |
| `/app/match.{matchId}.resume` | `{}` | Request a full state snapshot after reconnect. |

## Server → one client (private, `/user/queue/game`)

- `MATCH_FOUND` — `{"type":"MATCH_FOUND","matchId":"...","players":[{"playerId","name","seat"}...4],"yourSeat":<int>}`
- `RESUME_STATE` — full snapshot: `{"type":"RESUME_STATE","matchId":"...","phase":"TURN"|"BATTLE"|"MATCH_OVER","round":<int>,"currentSeat":<int>,"finalRound":bool,"players":[{"playerId","name","seat","alive","stats":{hp,pa,pd,ma,md,cn,hpp}}...],"boards":{"<playerId>":[{"x","y","attribute","rotation"}...]},"market":{"A":Card|null,"B":Card|null,"C":Card|null},"deckRemaining":<int>,"heldCard":Card|null}` (`heldCard` is only present/non-null for the player it belongs to)
- `ERROR` — `{"type":"ERROR","code":"NOT_YOUR_TURN"|"CARD_ALREADY_HELD"|"NO_CARD_HELD"|"INSUFFICIENT_COINS"|"INVALID_PLACEMENT"|"NOT_IN_MATCH"|"BAD_STATE","message":"..."}`

A `Card` is `{"topLeft","topRight","bottomLeft","bottomRight","rotation"}`, each corner
one of the `CornerAttribute` symbols from `gameRules.md` (e.g. `"PA_1"`, `"EMPTY"`).

## Server → match broadcast (public, `/topic/match.{matchId}`)

Since nothing is hidden, broadcasts carry full detail — no separate private/public
split beyond "which player does this concern."

- `ROUND_START` — `{"type":"ROUND_START","round":<int>,"startingSeat":<int>,"finalRound":bool}`
- `TURN_START` — `{"type":"TURN_START","playerId":"...","seat":<int>}`
- `CARD_PICKED` — `{"type":"CARD_PICKED","playerId":"...","slot":"A"|"B"|"C"|"DECK","card":Card,"market":{"A":Card|null,"B":Card|null,"C":Card|null},"deckRemaining":<int>}`. `market`/`deckRemaining` reflect the state *after* the market's shift-and-refill, so clients no longer need to call `.resume` after a market pick to learn the redrawn card (this was a real gap in the original contract — a market pick shifts+refills from the deck, and `CARD_PICKED` didn't use to carry that; it now does).
- `CARD_ROTATED` — `{"type":"CARD_ROTATED","playerId":"...","rotation":"DEG_0"|"DEG_90"|"DEG_180"|"DEG_270"}`
- `CARD_PLACED` — `{"type":"CARD_PLACED","playerId":"...","corner":"...","x":<int>,"y":<int>,"card":Card}`
- `STATS_UPDATED` — `{"type":"STATS_UPDATED","playerId":"...","stats":{hp,pa,pd,ma,md,cn,hpp}}`
- `BATTLE_RESULT` — `{"type":"BATTLE_RESULT","round":<int>,"attacks":[{"attackerId","defenderId","physicalDamage","magicDamage","totalDamage"}...],"outcomes":[{"playerId","hpBefore":<int>,"damageTaken":<int>,"healedHp":<int>,"hpAfter":<int>,"eliminated":bool}...]}`
  - **DEVIATION from the original contract (implemented, flagged for the designer):** the original put `defenderHpAfter`/`eliminated`/`healedHp` *inside each `attacks[]` row*, which is ambiguous under all-vs-all resolution (a defender is hit by several attackers, and `healedHp` is a once-per-player value, not per-attack). Split into two arrays: `attacks[]` = the pure damage instances (the numbers that "fly" between players, all from the shared pre-battle snapshot, in resolution order), and `outcomes[]` = one row per still-alive-at-battle-start player with their `hpBefore` (snapshot), total `damageTaken`, `healedHp` (0 if eliminated; else their `hpp`), final `hpAfter` (possibly negative if eliminated), and `eliminated`. `hpAfter` in `outcomes[]` is the authoritative post-battle hp; derive final hp from `outcomes[]`, not by summing `attacks[]`.
- `PLAYER_ELIMINATED` — `{"type":"PLAYER_ELIMINATED","playerId":"...","finalHp":<int>}`
- `MATCH_RESULT` — `{"type":"MATCH_RESULT","winners":["playerId",...],"reason":"LAST_STANDING"|"DECK_EXHAUSTED"}` (`winners` has >1 entry only on the mutual-kill final-hp tie described below)
- `PLAYER_DISCONNECTED` / `PLAYER_RECONNECTED` — `{"type":"...","playerId":"..."}`

## Battle phase — ruling on an ambiguous rule (read before implementing)

`gameRules.md` says "the player who moved first that round attacks all other
players" (singular attacker, one round), but then notes mutual kills are possible
"in the same round" — which a single-attacker-only-defends-never model cannot
produce. **Ruling**: battle phase is **all-vs-all**, resolved in that round's turn
order starting from the round's first mover — every player attacks every other
still-alive player, with every damage instance computed from the **same pre-battle
stat snapshot** (not updated mid-resolution), so simultaneous mutual kills are
possible and match the "ends with higher (less negative) hp wins the exchange"
tiebreak language. `attacks[]` in `BATTLE_RESULT` lists every attacker→defender pair
in that resolution order. If two or more players are eliminated this way and the
game would otherwise end in a tie for last-player-standing, `MATCH_RESULT.winners`
lists whichever eliminated-this-round player(s) ended with the higher (least
negative) `hp`, per the rule.

This is a judgment call, not something stated outright in `gameRules.md` — flag it
back to the designer; implement against this ruling until told otherwise.

**Battle-animation pause**: after broadcasting `BATTLE_RESULT` (and any
`PLAYER_ELIMINATED`), the server waits `2000ms + 800ms × attacks.length` before
sending the follow-up `ROUND_START` or `MATCH_RESULT`, so clients have time to
play one mini animation per `attacks[]` row (12 rows when all four players are
alive) in resolution order. `attacks[]` includes zero-damage pairs — clients
should render those as blocked hits, not skip them. The engine has already
resolved everything before the pause; only the announcements wait.

## Turn order

Rotation pattern per `gameRules.md`: round 1 starts at seat 0, round 2 at seat 1,
round 3 at seat 2, round 4 at seat 3, round 5 back to seat 0, etc. (`round % 4`).
Within a round, seats act in order starting from that round's starting seat, wrapping
around, **skipping eliminated players**. A round ends once every still-alive player
has placed a card; the battle phase (above) then runs before the next round starts.

## Final round

Checked once, at the start of each round (not mid-round): if the market's face-up
slots plus the deck hold **fewer than 7 cards combined** (i.e. the market can't stay
fully stocked at 3 alongside a 4-card deck buffer), that round is the **final
round**: every market slot is free (`A`/`B`/`C` all cost 0 coins that round only —
`pick` waives the normal price check entirely) and, once that round's placements and
battle phase resolve, the match ends immediately regardless of how many players are
still alive — highest `hp` wins, ties share (`MATCH_RESULT.reason:
"DECK_EXHAUSTED"`), the same as the plain deck-exhaustion case below. (A last-player-
standing or mutual-kill result from that round's battle still takes priority over the
final-round ending, same as it always would.) `ROUND_START` and `RESUME_STATE` both
carry `finalRound` so clients can show free pricing and a "final round" indicator.

## Disconnection & turn timeout

Every turn is capped at **60 seconds**. Disconnect/reconnect only flip a presence
flag and broadcast `PLAYER_DISCONNECTED` / `PLAYER_RECONNECTED` — the match is
**not** paused for either a slow connected player or a disconnected one; both are
covered by the same 60s timer. On expiry, the server auto-plays that seat's turn:
draws the free face-down deck card (`CARD_PICKED` with `slot: "DECK"`) and places it
at the first legal board point (the origin on an empty board, otherwise an arbitrary
existing point on that player's own board, anchored at `TOP_LEFT`) — broadcast as a
normal `CARD_PLACED` + `STATS_UPDATED`, indistinguishable on the wire from a manual
play. If the deck is fully exhausted when the timer fires, the auto-play is skipped
(logged server-side) rather than erroring the match. A reconnecting player (same
token) who beats the timer keeps playing normally; `resume` returns the current
state either way.

## End of game

- **Last player standing**: one player remains alive → they win, `reason:
  "LAST_STANDING"`.
- **Deck exhausted**: the deck and all three market slots are empty when a round
  would otherwise continue → highest `hp` among remaining players wins, ties share
  the win, `reason: "DECK_EXHAUSTED"`.
