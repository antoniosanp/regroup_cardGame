# Game Rules

## Overview

This is a four-player game. Each player has the following stats:

| Stat | Abbreviation | Starting value |
|------|--------------|-----------------|
| Health Points | hp | 30 (max 30) |
| Physical Attack | pa | 0 |
| Physical Defense | pd | 0 |
| Magic Attack | ma | 0 |
| Magic Defense | md | 0 |
| Coins | cn | 0 (max 2) |
| Health Potions | hpp | 0 |

## Cards

Every card is a square with four corners. Each corner can have one of the following properties:

| Symbol | Property |
|--------|----------|
| — | Empty square |
| q | 1 hp potion + 1 coin |
| w | 2 coins |
| e | 1 pa |
| r | 2 pa |
| t | 1 pd |
| y | 2 pd |
| u | 1 ma |
| i | 2 ma |
| o | 1 md |
| p | 2 md |

### Corner composition

A stat category (pa, pd, ma, md) may appear on **at most two** corners of the same card, and when it appears twice those two corners **must be diagonally opposite** — never side by side.

The reason is the adjacency rule below: two corners that sit side by side on a card are orthogonal neighbours once the card is placed, so a side-by-side pair would match *itself* and score the moment the card lands, with no placement skill involved. A diagonal pair only touches at a point, so it never self-matches — the player still has to line it up against neighbouring cards to make it count.

Empty/coin/potion corners have no stat category and are exempt.

### Deck composition

The deck is built from 8-card units, 14 units for a standard 112-card deck:

| Shape | Per unit | Total | Corners |
|-------|----------|-------|---------|
| Normal | 3 | 42 | one +1 corner of each of pa/pd/ma/md |
| Double | 2 | 28 | one category at +2, the other three at +1 |
| Pair | 2 | 28 | one category at +2 **and** +1 on a diagonal, plus two other categories at +1 |
| Empty | 1 | 14 | one empty/coin/potion corner plus three categories at +1 |

Pair is the only shape that repeats a category. Which category is doubled (and which is paired) rotates evenly across pa/pd/ma/md, so no stat is over-represented in the deck.

## Turns

On the first turn, one player is selected to move first (it doesn't matter who). After each round, the first player rotates in a loop, so that every player eventually starts a round:

```
1-2-3-4
2-3-4-1
3-4-1-2
4-1-2-3
1-2-3-4
```

On a player's turn, they choose one of three face-up cards (named A, B, and C), or the top face-down card from the deck:

- Card A: free
- Card B: costs 1 coin
- Card C: costs 2 coins
- Top face-down card from the deck: free

Once a card is picked, the remaining cards shift to fill the open slot. For example, if a player takes the card in position A, the card in B moves to A, the card in C moves to B, and a new card is drawn into C. Prices are updated accordingly — the first card is always free, the second costs 1 coin, and the last costs 2 coins.

Each player's very first move of the game can only be placing their drawn card onto their (otherwise empty) board.

### Placing cards

From the second move onward, when a player picks a new card, it must be placed so that it shares at least one corner with a card already on their board — and the new card is always placed covering that shared corner.

For example, suppose the player has a card on their board with these corners:

```
Q | W
-----
E | R
```

And they draw a card with these corners:

```
T | Y
-----
U | I
```

The player may rotate the new card 90 degrees as many times as they like, but when placing it, it must share a corner with the existing card. For example:

```
    T | Y
   -------
Q | U | I
-----
E | R
```

That placement ends the player's turn. Once every player has moved, the round ends: each player's stats are recalculated, and the battle phase begins.

## Stats Calculation

- Coins (cn) and health potions (hpp) are equal to the number of cn/hpp symbols visible on the player's board.
- For the other properties (pa, pd, ma, md), matching properties must be adjacent to count. For example, if a 1pa corner is adjacent to a 2pa corner, the player gains 3pa total. However, if a 2md corner is adjacent only to non-md corners (e.g. 1cn, 1pa, 1ma, 1pd), that 2md does not count.

## Battle Phase

After stats are calculated, the battle phase begins. The player who moved first that round attacks all other players. Damage is calculated as follows:

- Physical damage: attacker's pa − defender's pd (if negative, treat as 0)
- Magic damage: attacker's ma − defender's md (if negative, treat as 0)

The defending player takes damage. If their hp drops below 1, they lose and take no further part in the game. Otherwise, they recover hp equal to their hpp.

**Note:** Even if a player dies during the battle phase, they still get to attack that round — so it's possible for two players to kill each other in the same round. In the event of such a mutual kill, the player who ends with the higher (less negative) hp wins the exchange. For example, if player one dies at -3hp and player two dies at -5hp, player one wins.

## Final Round

Checked at the start of each round: if the face-up market and the deck together hold
fewer than 7 cards, that round is the **final round** — every market slot (A/B/C) is
free for that round, and once it resolves (placements, then the battle phase), the
game ends immediately: the player with the highest hp wins, ties share the win.

## End of Game

The game ends when only one player remains, the final round (above) resolves, or the deck runs out of cards. In the latter two cases, the player with the highest hp wins.
