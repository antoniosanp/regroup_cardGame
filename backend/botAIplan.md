# Bot AI Plan — Advanced Personalities

Plan for replacing the current "easy" bot (uniform-random pick + uniform-random placement in
`MatchService.playBotTurn` / `chooseBotPick` / `randomLegalAnchor`) with three distinct AI
personalities: **Defensive**, **Offensive**, and **Adaptive**.

> **Status: implemented** in `com.regroup.bot` (strategies + `MoveEvaluator` + `BotTuning`), wired
> through `LiveMatch`/`MatchService`, tested in `src/test/java/com/regroup/bot/`. In a 200-match
> headless benchmark each personality beats 3 random bots 100% of the time; the mixed matchup
> (one of each + random) came out Defensive 131 / Adaptive 77 / Offensive 22 / Random 0 wins.

---

## 1. What "picking a stat" actually means in this game

Two rule facts (from `gameRules.md` / `BoardEngine`) drive the whole design:

1. **Stats only count when adjacent.** A `2pa` corner surrounded by non-PA corners contributes
   nothing. So a bot that "picks offense" can't just grab cards with PA symbols — it must also
   **place** them so PA corners end up adjacent to other PA corners.
2. **Placement overwrites.** `BoardEngine.placeCard` stamps all four corners over whatever was
   there. A bad placement can *destroy* an existing adjacency cluster.

Therefore every personality needs the same two-step brain, differing only in its *scoring weights*:

- **Pick step:** evaluate the 3 visible market cards (A free / B 1cn / C 2cn) + the unknown deck.
- **Placement step:** enumerate every legal move for the chosen card — all 4 rotations × 4 overlap
  corners × every existing board point — simulate each on a board copy, recompute the stat totals,
  and keep the placement with the best weighted stat delta.

The simulation gives each candidate move a stat delta vector `Δ = (pa, pd, ma, md, cn, hpp)`; each
personality turns that vector into a single score with its own weights.

## 2. Architecture

New package `com.regroup.bot` (server-side only; nothing crosses the WS contract):

- **`BotStrategy` interface** — two decisions, both pure functions of engine state:
  - `PickChoice choosePick(MatchEngine engine, int seat)` → market slot or DECK.
  - `Placement choosePlacement(MatchEngine engine, int seat, Card held)` → rotation count, overlap
    corner, anchor point.
- **`RandomBotStrategy`** — today's behavior, extracted as-is. Stays as the "easy" difficulty and
  as the fallback when a smarter strategy finds no legal/affordable move.
- **`MoveEvaluator`** (shared helper) — the enumeration + simulation described above. Copies the
  `Board`, applies the candidate via `BoardEngine`, recomputes stats the same way the round-end
  recalculation does, returns the `Δ` vector. All three personalities call this with different
  weight profiles, so the expensive logic is written once.
- **`DefensiveBotStrategy` / `OffensiveBotStrategy` / `AdaptiveBotStrategy`** — thin classes that
  supply weights (and, for Adaptive, read opponents' stats first).

Integration points (small, surgical changes):

- `LiveMatch`: store a `BotStrategy` per bot seat (today it's just `boolean[] bot`).
- `MatchmakingService` / `MatchService.createMatch(..., botSeats)`: assign personalities when the
  offline match is created — e.g. random shuffle of {Defensive, Offensive, Adaptive} across the 3
  bot seats so every offline game has variety.
- `MatchService.playBotTurn`: replace the two `rng.nextInt` decisions with
  `strategy.choosePick(...)` / `strategy.choosePlacement(...)`. Keep the existing human-like delay,
  the lock/re-validation guards, and the turn-timeout fallback exactly as they are.

## 3. The three personalities

### 3.1 Defensive AI — "the turtle"

- **7/10 turns** (`rng.nextInt(10) < 7`): score moves with defensive weights — PD and MD dominate,
  small credit for hpp (healing synergizes with tanking) and cn.
- **Equilibrium rule:** the bot keeps PD and MD balanced, tolerating a configurable max gap of
  **1–3 points** (constant, e.g. `MAX_DEFENSE_GAP = 2`, tuned later within the allowed 1..3 range).
  Implemented as a *dynamic weight*, not a hard filter: whichever of PD/MD is currently **lower**
  on the bot's board gets a boosted weight, and any candidate move that would push
  `|pd − md|` beyond the gap is heavily penalized. So a bot at 5pd/2md strongly prefers MD cards
  until the gap closes.
- **3/10 turns:** fall back to a neutral profile (best overall Δ, any stat) so its board still
  grows attack/economy and it isn't a pure punching-bag that can never win a deck-exhausted
  HP tiebreak. (It can't deal damage without some PA/MA at all — pure defense never eliminates
  anyone.)

### 3.2 Offensive AI — "the berserker"

- **7/10 turns:** offensive weights — PA and MA dominate. Unlike defense, offense does *not* need
  equilibrium: focusing one attack type is actually stronger against a specific victim, but
  spreading across PA+MA is safer against mixed defenses. Compromise: mildly prefer whichever
  attack stat already has the bigger adjacency cluster on its own board (build on strength —
  adjacency rewards concentration).
- **3/10 turns:** neutral profile (as above), which in practice picks up defense/economy/potions
  when they're clearly the best value on the table.

### 3.3 Adaptive AI — "the counter-player"

Before scoring, scan all **alive opponents'** current stats (`engine.player(s).pa()/ma()/pd()/md()`;
these are the post-recalculation values from last round — exactly what the next battle will use):

1. **Threat check (their attack → my defense).** Find the highest attack stat among opponents.
   If an opponent has a *high* attack stat — "high" = `max(opponent pa, ma) >= THREAT_THRESHOLD`
   (start at 3) — prioritize the **matching defense**: high enemy PA → weight PD up;
   high enemy MA → weight MD up. If both are high, weight both defenses proportionally to
   the incoming values (Regroup is a 1-attacks-all game, so total incoming damage per round is the
   *sum* over attackers — compute `Σ max(0, opp.pa − my.pd)` and `Σ max(0, opp.ma − my.md)` and
   defend against the larger expected loss).
2. **Wall check (their defense → my other attack).** Look at the defenses of the opponents the bot
   would attack. If opponents are collectively strong in one defense type — e.g. average PD
   noticeably higher than average MD — weight the **opposite attack type** up: high enemy PD →
   invest in MA; high enemy MD → invest in PA. (Score it as *expected damage dealt*:
   `Σ max(0, my.pa+Δpa − opp.pd)` vs the magic equivalent — this naturally picks the attack that
   penetrates.)
3. **Priority when both fire:** survival first — if the bot's projected incoming damage next
   battle exceeds its current hp (death is possible), the threat rule wins; otherwise the wall
   rule wins. No 7/10 dice for this bot: adaptivity *is* its personality, but keep a small random
   jitter (~10%) on the weights so 3 adaptive bots in one match don't play identically.

### 3.4 Pick evaluation details (all personalities)

- For each visible market card, the pick score = the score of its **best placement** (from
  `MoveEvaluator`) minus a **coin cost penalty** (coins cap at 2 and buy future flexibility, so
  spending them must beat the free option by a margin; on the final round everything is free and
  the penalty is zero).
- The **deck** is unknown: score it as the *expected* value of a random card given the remaining
  deck composition (`CardFactory` defines the distribution) — in practice a precomputed constant
  "average card" score. The deck becomes the rational choice when the visible cards fit the
  personality badly.
- If nothing is affordable/pickable, keep today's behavior: log and let the turn timeout handle it.

## 4. Tuning & configuration

- All magic numbers in one place (`BotTuning` record/constants): the 7/10 probability, defense gap
  (1–3), threat threshold, coin penalty, deck expectation, adaptive jitter.
- Difficulty naming for future UI: Easy = Random, Medium = Defensive/Offensive, Hard = Adaptive.

## 5. Testing plan

1. **Unit tests per strategy** (`backend/src/test/java/com/regroup/bot/`):
   - Defensive: given crafted markets/boards, asserts ≥ PD/MD picks under a seeded RNG over N
     trials (~70% ± tolerance), and that it never lets `|pd − md|` exceed the gap when a
     gap-closing move exists.
   - Offensive: mirror of the above for PA/MA.
   - Adaptive: fixture opponents with 5pa/0ma → bot must weight PD; opponents with high PD, low
     MD → bot must weight MA; both-threats fixture exercises the priority rule.
   - `MoveEvaluator`: placement simulation matches the engine's real recalculation (place the
     chosen move for real, compare stats), and it never chooses a move that overwrites more
     cluster value than it adds when a better square exists.
2. **Simulation harness** (plain JUnit or a `main`): run ~1000 headless matches of each matchup
   (each personality vs 3 random bots; personalities vs each other) directly on `MatchEngine` — no
   WebSocket layer. Success criteria: every advanced bot beats Random significantly (win rate
   well above the 25% baseline), and no personality is degenerate (0% or 100% vs the others).
   Also asserts no `InvalidMoveException` is ever thrown by a strategy (all chosen moves legal).
3. **Manual check:** one offline game from the frontend, watching that the bots' boards visibly
   reflect their personalities (bot names could temporarily include the archetype during dev,
   e.g. "Bot 2 (aggro)").

## 6. Out of scope (deliberately)

- No lookahead/minimax beyond the single-move simulation (one turn of perfect greed is already a
  huge jump over random; multi-turn search can come later behind the same `BotStrategy` interface).
- No card counting of what opponents picked (market is shared, but modeling it adds little at this
  level).
- No changes to the WS contract, timers, or the human turn flow.
