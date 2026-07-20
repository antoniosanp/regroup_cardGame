# Regroup — Sound Effects List

Every sound the game needs, grouped by the screen/system that triggers it. Each entry
gives the suggested file name, the exact trigger point in the code, and a description of
the sound's character so the assets can be sourced or produced consistently.

Suggested format: short `.ogg` + `.mp3` fallback, mono, ≤ 200 KB each (music aside).
Style guide: the UI art is wood, parchment and hand-drawn fantasy — sounds should be
organic/tavern-like (wood knocks, paper, coins, leather) rather than digital bleeps.

---

## 1. UI / Menu

| File | Trigger | Description |
|---|---|---|
| `ui-click.ogg` | Any generic button press (`Connect`, `Dismiss`, `Back to lobby`, `Close`, tab switches in `OpponentsModal`) | Soft wooden *tock*, like a knuckle tap on a table. Short (~80 ms), quiet — it plays often. |
| `ui-connect.ogg` | Successful connection / entering the lobby (`OnlineScreen` stage `name → lobby`) | Warm two-note confirmation, e.g. a light string pluck rising. Communicates "you're in". |
| `ui-error.ogg` | Error banner appears (`OnlineScreen` error banner, store `error` set — includes rejected moves from the server) | Dull low thud with a slight buzz, clearly negative but not harsh. Must not be startling since server errors can arrive unprompted. |
| `ui-reconnecting.ogg` | "Connection lost — reconnecting…" banner appears | Muffled descending tone, like a door creaking shut. One-shot when the banner shows, not looped. |
| `ui-modal-open.ogg` | Opponents modal opens (`Match` → `opponent-board-btn` click) | Parchment/paper unrolling swish (~250 ms). |
| `ui-modal-close.ogg` | Opponents modal closes | Reverse of the open: shorter paper swish, slightly lower pitch. |

## 2. Matchmaking

| File | Trigger | Description |
|---|---|---|
| `queue-join.ogg` | Entering the queue (`Find a match` / `Play offline vs bots`) | Single deep drum hit — "the search begins". |
| `match-found.ogg` | Store stage `queue → match` (MATCH_FOUND) | Short fanfare sting (~1.5 s): horn + drum, exciting. This is the most important attention-grabber in the game since the player may be tabbed away. |

## 3. Turn flow & timer

| File | Trigger | Description |
|---|---|---|
| `turn-yours.ogg` | `isMyTurn` becomes true (`TurnTimer` label flips to "Your turn") | Bright single bell/chime. Clearly distinct from `match-found`; players must recognize it instantly. |
| `timer-low-tick.ogg` | Each second while `secondsLeft <= 10` on your own turn (`TurnTimer` `low` state) | Quiet clock *tick*. Played once per second; must be subtle enough to not be annoying for 10 s. |
| `timer-expired.ogg` | Countdown reaches 0 on your turn | Small gong/bell toll — "time's up", mildly negative. |

## 4. Market (`Market.tsx`)

| File | Trigger | Description |
|---|---|---|
| `card-pick.ogg` | `Pick · Free` / `Pick · n coins` succeeds (held card appears) | Crisp single-card slide/flick off a wooden surface. |
| `coin-spend.ogg` | Picking a priced slot (layered on top of `card-pick` when price > 0) | Two or three coins clinking into a pouch. |
| `deck-draw.ogg` | `Draw · Free` from the deck | Card slide plus a slight *thump* of the deck — heavier than `card-pick` because it's face-down/unknown. |
| `pick-denied.ogg` | Clicking a disabled/unaffordable slot (optional — buttons are disabled, so only if hover/press feedback on disabled buttons is added) | Short dry knock, "locked drawer" feel. |

## 5. Hand & board placement (`Match.tsx`, `BoardView.tsx`)

| File | Trigger | Description |
|---|---|---|
| `card-rotate.ogg` | `Rotate 90°` button | Quick paper swivel/whip (~120 ms). Plays repeatedly, keep it light. |
| `card-drag-start.ogg` | `onDragStart` of the held card | Soft paper lift/pinch — the card leaving the table. |
| `card-hover-cell.ogg` | Drag preview lands on a new valid anchor point (`onDragOverPoint`, when `hoverPoint` changes) | Barely-audible tick, like a token sliding one notch. Extremely short and quiet — fires many times per drag. |
| `card-place.ogg` | Successful `place()` (board gains the 4 new points) | Satisfying card *snap* onto wood, with a faint thud. The signature sound of the game — worth the best asset. |
| `card-place-invalid.ogg` | Server rejects the placement (error after a drop) | Muted double-knock, "doesn't fit". Distinct from `ui-error`. |
| `stat-up.ogg` | Own PA/PD/MA/MD/HP increases (`AnimatedNumber` green flash in `PlayerHud`) | Tiny ascending shimmer (~200 ms). |
| `stat-down.ogg` | Own stat decreases (`AnimatedNumber` red flash) | Tiny descending dull note. |

## 6. Battle phase (`BattleStage.tsx`)

| File | Trigger | Description |
|---|---|---|
| `battle-start.ogg` | Battle overlay mounts (`phase === 'BATTLE'`) | War-drum roll + low horn (~1.5 s), sets the mood while the overlay fades in. |
| `attacker-step.ogg` | New attacker phase begins (`setActiveAttackerId`, the 450 ms "register the attacker" pause) | Single heavy footstep / armor clank announcing who attacks. |
| `attack-lunge.ogg` | Attacker square lunge animation starts (the 600 ms translate) | Whoosh, timed so its peak lands mid-lunge (~300 ms in). |
| `hit-impact.ogg` | Damage lands (`totalDamage > 0`, impact flash + damage floater) | Meaty thump/slap with a slight crunch. Pitch-vary ±10% per play so repeated hits don't sound cloned. |
| `hit-impact-chicken.ogg` | Occasional comedy variant of `hit-impact` — see the note below on trigger rate | The same punch with a chicken squawk over it. **Do not** play on every hit. |
| `hit-blocked.ogg` | Attack fully blocked (`totalDamage <= 0`, "0" floater) | Metallic shield *clang*, clearly different from a damaging hit. |
| `hp-tick.ogg` | HP counter tweening down (`AnimatedNumber` on the defender row) | Rapid soft ticking, or skip: a single tick at tween start is enough. Optional — the impact sound may carry this. |
| `heal.ogg` | Heal floaters at battle end (`+n` green floaters, `healedHp > 0`) | Gentle glassy chime with a rising tail, potion-like. |
| `eliminated.ogg` | A row gains the 💀 dead state (`outcomes[].eliminated`) | Low dramatic drum hit + short falling tone. If the eliminated player is *you*, consider a longer, sadder variant `eliminated-self.ogg`. |
| `battle-end.ogg` | `finished` becomes true and the battle log panel shows | Short resolving chord — tension release, transitions back to the board. |
| `battle-skip.ogg` | `Skip animation` clicked | Fast paper riffle (all remaining events resolving at once). Can reuse `ui-click` if budget is tight. |

## 7. Match result (`ResultScreen.tsx`)

| File | Trigger | Description |
|---|---|---|
| `victory.ogg` | Result screen where you are in `winners` | Full triumphant fanfare (2–4 s), horns + drums. The biggest sound in the game. |
| `defeat.ogg` | Result screen where you lost | Somber short phrase (~2 s), minor key, but not humiliating — players see this often. |

## 8. Music & ambience (optional, later)

| File | Trigger | Description |
|---|---|---|
| `music-lobby.ogg` | Name entry / lobby / queue screens | Calm tavern loop (lute, light percussion), 60–90 s seamless loop, low volume. |
| `music-match.ogg` | During TURN phases | Slightly tenser medieval loop; must sit *under* the SFX (side-chain or just −12 dB). |
| `music-battle.ogg` | During BATTLE phase | Percussion-heavy variant of the match loop; crossfade in/out with the overlay. |

---

## Implementation notes

- **All frontend.** The backend never knows about audio; every trigger above is a state
  change already visible in the Zustand store (`onlineStore.ts`) or a local UI event, so a
  small `playSfx(key)` helper in this folder can cover everything.
- **Autoplay policy:** browsers block audio before the first user gesture. The name-entry
  `Connect` click is the natural unlock point — resume/warm the audio context there.
- **Volume tiers:** UI ticks (hover, timer, hp-tick) ≈ 0.3, gameplay actions ≈ 0.6,
  stingers (match-found, victory, eliminated) ≈ 0.9. Ship a mute toggle on the match HUD.
- **`prefers-reduced-motion`:** `BattleStage` already skips animations for these users —
  skip the per-hit battle sounds too and play only `battle-start`/`battle-end`.
- **Priority order if sourcing assets incrementally:**
  1. `card-place`, `card-pick`, `ui-click` (heard constantly)
  2. `hit-impact`, `hit-blocked`, `attack-lunge`, `battle-start`
  3. `turn-yours`, `match-found`, `victory`, `defeat`, `eliminated`
  4. everything else, then music last.

---

## Asset status

Every sound this game ships exists in this folder as `<name>.ogg` + `<name>.mp3` — 34
one-shots (mono, all under 40 KB) plus `music-lobby` (stereo, 6.3 s loop, 125 KB). They were
cut from the sourced clips now parked in `originals/`; nothing was deleted, so any pick can
be revisited by re-cutting from there.

Each source was chosen by measuring the audio (length, attack time, spectral centroid and
whether it rises or falls, tonality, low/high band split) rather than by trusting its file
name. Levels are pre-normalised to the volume tiers above — ticks quietest, stingers
loudest — so the tier multipliers in code still apply on top.

**Resolved differently from the tables above:**

| Entry | Resolution |
|---|---|
| `eliminated-self` | Dropped — play the general `eliminated` for your own death too. |
| `music-match`, `music-battle` | Dropped by decision; the game ships lobby music only. |
| `music-lobby` | A 6.3 s drum loop, not the 60–90 s tavern loop described above. It is a *tense* bed (33% of its energy below 250 Hz), so the "calm lute tavern" wording in section 8 no longer matches what is actually there. |

**Edited rather than straight-cut:**

- `card-place-invalid` — no source contained a double knock, so it is the wooden knock
  played twice, 135 ms apart, second hit at −3 dB.
- `timer-low-tick`, `timer-expired` and `hp-tick` all come from one source clip that turned
  out to be 8 s of clock ticks followed by a bell at 10.8 s; the ticks and the bell were cut
  out separately.
- `battle-skip` is the one crisp flick (t=1.80 s) out of a 13.6 s clip holding four; the
  other three are boomy thumps rather than paper.
- `hit-impact-chicken` is `hit-impact`'s punch with a chicken squawk mixed 50 ms behind it
  at −3 dB. The squawk carries almost nothing below 250 Hz, so layering keeps the punch's
  body intact (low end 27.7% → 22.7%) while the squawk fills 1–4 kHz (26.9% → 33.3%) — at
  −3 dB the two are level in that shared band, so the squawk reads clearly without
  swallowing the hit. Playing the squawk *alone* would not work: with no low end it sounds
  like a whiff rather than a connection.

**Trigger rate for `hit-impact-chicken`:** a 4-player all-vs-all round resolves up to 12
attacks, so firing this on every damaging hit means up to 12 squawks in a row. Use it as a
rare random variant (~1 in 8 hits) or reserve it for a killing blow, which is also where the
joke lands hardest.

**Looping note:** `music-lobby` was encoded without fades or silence trimming and both files
decode to exactly the source's 302 976 samples, so it loops gaplessly. It does carry ~14 ms
of near-silence across the wrap (10 ms head + 4 ms tail) that came with the source; if that
reads as a hiccup, trim the head rather than adding a fade.

16 sourced clips matched nothing and are left unused in `originals/` — including three
chicken recordings, a duplicate of the timer clip, and several near-duplicate
success/notification chimes.
