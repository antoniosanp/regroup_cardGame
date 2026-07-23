package com.regroup.engine;

import java.awt.Point;
import java.util.ArrayList;
import java.util.List;

/**
 * The authoritative four-player engine: four seats sharing one market/deck, a turn-order state machine,
 * per-turn pick/rotate/place, and the round-end all-vs-all battle. Pure Java; the session layer wraps it
 * with a lock and broadcasting.
 */
public class MatchEngine {

    public static final int PLAYER_COUNT = 4;
    public static final int MAX_HP = 30;

    /** If a round would start with fewer than this many cards left across the market and deck combined, it's the final round: every slot is free, and the match ends (highest hp wins) once it's resolved. */
    public static final int FINAL_ROUND_THRESHOLD = 7;

    private final List<Player> players = new ArrayList<>(PLAYER_COUNT);
    private final Deck deck;
    private final CardMarket market;
    private final BoardEngine boardEngine = new BoardEngine();
    private final CombatEngine combatEngine = new CombatEngine();

    private final boolean[] alive = new boolean[PLAYER_COUNT];
    private final boolean[] placedThisRound = new boolean[PLAYER_COUNT];

    private GamePhase phase = GamePhase.WAITING;
    private int round = 0;
    private int startingSeat = 0;
    private int currentSeat = 0;
    private Card heldCard;
    private boolean finalRound;

    public MatchEngine(Deck deck) {
        this.deck = deck;
        this.market = new CardMarket(deck);
        for (int i = 0; i < PLAYER_COUNT; i++) {
            players.add(new Player());
            alive[i] = true;
        }
    }

    /** WAITING -> TURN: opens round 1 with seat 0 to move first. */
    public void start() {
        if (phase != GamePhase.WAITING) {
            throw new InvalidMoveException(InvalidMoveException.Code.BAD_STATE, "Match already started");
        }
        round = 1;
        startingSeat = 0;
        currentSeat = firstAliveFrom(startingSeat);
        java.util.Arrays.fill(placedThisRound, false);
        finalRound = cardsRemaining() < FINAL_ROUND_THRESHOLD;
        phase = GamePhase.TURN;
    }

    /** Cards left to be drawn across the market's face-up slots and the deck combined. */
    private int cardsRemaining() {
        return market.filledSlotCount() + deck.remaining();
    }

    /** Takes the face-up card at slot, paying its price in coins. */
    public Card pickFromMarket(int seat, Slot slot) {
        requireTurn(seat);
        requireNoCardHeld();
        Card card = market.cardAt(slot);
        if (card == null) {
            throw new InvalidMoveException(InvalidMoveException.Code.BAD_STATE, "No card at slot " + slot);
        }
        int price = finalRound ? 0 : slot.price();
        if (players.get(seat).cn() < price) {
            throw new InvalidMoveException(InvalidMoveException.Code.INSUFFICIENT_COINS,
                    "Slot " + slot + " costs " + price + " coins");
        }
        market.take(slot);
        Player player = players.get(seat);
        player.setCn(player.cn() - price);
        heldCard = card;
        return card;
    }

    /** Draws the free top card of the face-down deck. */
    public Card pickFromDeck(int seat) {
        requireTurn(seat);
        requireNoCardHeld();
        if (deck.isEmpty()) {
            throw new InvalidMoveException(InvalidMoveException.Code.BAD_STATE, "Deck is empty");
        }
        heldCard = market.takeFaceDown();
        return heldCard;
    }

    /** Rotates the held card 90 degrees clockwise. */
    public Rotation rotate(int seat) {
        requireTurn(seat);
        requireCardHeld();
        boardEngine.rotateCard(heldCard);
        return heldCard.rotation();
    }

    /** Places the held card anchoring overlapCorner at (x,y), recomputes the seat's stats, and ends the turn. */
    public PlacementResult place(int seat, CornerPosition overlapCorner, int x, int y) {
        requireTurn(seat);
        requireCardHeld();
        Card placed = heldCard;
        heldCard = null;
        try {
            boardEngine.placeCard(players.get(seat).board(), placed, overlapCorner, new Point(x, y));
        } catch (IllegalArgumentException e) {
            throw new InvalidMoveException(InvalidMoveException.Code.INVALID_PLACEMENT, e.getMessage());
        }
        combatEngine.calculateStats(players.get(seat).board(), players.get(seat));
        placedThisRound[seat] = true;

        int next = nextSeatToPlace();
        if (next >= 0) {
            currentSeat = next;
            return new PlacementResult(placed, false, null, null);
        }
        BattleResult battle = endRound();
        MatchOutcome outcome = evaluateEnd(battle);
        if (outcome != null) {
            phase = GamePhase.MATCH_OVER;
        } else {
            startNextRound();
        }
        return new PlacementResult(placed, true, battle, outcome);
    }

    /** Resolves the round's battle: every alive seat attacks every other alive seat from one shared pre-battle snapshot. */
    private BattleResult endRound() {
        phase = GamePhase.BATTLE;
        List<Integer> order = battleOrder();
        for (int seat : order) {
            combatEngine.calculateStats(players.get(seat).board(), players.get(seat));
        }

        int[] hp = new int[PLAYER_COUNT];
        int[] pa = new int[PLAYER_COUNT];
        int[] pd = new int[PLAYER_COUNT];
        int[] ma = new int[PLAYER_COUNT];
        int[] md = new int[PLAYER_COUNT];
        int[] hpp = new int[PLAYER_COUNT];
        for (int seat : order) {
            Player p = players.get(seat);
            hp[seat] = p.hp();
            pa[seat] = p.pa();
            pd[seat] = p.pd();
            ma[seat] = p.ma();
            md[seat] = p.md();
            hpp[seat] = p.hpp();
        }

        List<BattleResult.Attack> attacks = new ArrayList<>();
        int[] damageTaken = new int[PLAYER_COUNT];
        for (int attacker : order) {
            for (int defender : order) {
                if (attacker == defender) {
                    continue;
                }
                int physical = Math.max(pa[attacker] - pd[defender], 0);
                int magic = Math.max(ma[attacker] - md[defender], 0);
                int total = physical + magic;
                attacks.add(new BattleResult.Attack(attacker, defender, physical, magic, total));
                damageTaken[defender] += total;
            }
        }

        List<BattleResult.Outcome> outcomes = new ArrayList<>();
        for (int seat : order) {
            int before = hp[seat];
            int rawAfter = before - damageTaken[seat];
            int healed = 0;
            boolean eliminated = rawAfter < 1;
            int after = rawAfter;
            if (eliminated) {
                alive[seat] = false;
            } else {
                healed = hpp[seat];
                after = Math.min(rawAfter + healed, MAX_HP);
            }
            players.get(seat).setHp(after);
            outcomes.add(new BattleResult.Outcome(seat, before, damageTaken[seat], healed, after, eliminated));
        }
        return new BattleResult(round, attacks, outcomes);
    }

    /** Decides whether the match is over after a battle, and who won; null means play continues. */
    private MatchOutcome evaluateEnd(BattleResult battle) {
        List<Integer> aliveSeats = new ArrayList<>();
        for (int seat = 0; seat < PLAYER_COUNT; seat++) {
            if (alive[seat]) {
                aliveSeats.add(seat);
            }
        }
        if (aliveSeats.size() == 1) {
            return new MatchOutcome(aliveSeats, MatchOutcome.Reason.LAST_STANDING);
        }
        if (aliveSeats.isEmpty()) {
            // Everyone remaining died this round: the least-negative final hp wins the exchange.
            int best = Integer.MIN_VALUE;
            for (BattleResult.Outcome o : battle.outcomes()) {
                if (o.eliminated()) {
                    best = Math.max(best, o.hpAfter());
                }
            }
            List<Integer> winners = new ArrayList<>();
            for (BattleResult.Outcome o : battle.outcomes()) {
                if (o.eliminated() && o.hpAfter() == best) {
                    winners.add(o.seat());
                }
            }
            return new MatchOutcome(winners, MatchOutcome.Reason.LAST_STANDING);
        }
        if (finalRound || market.isExhausted()) {
            int best = Integer.MIN_VALUE;
            for (int seat : aliveSeats) {
                best = Math.max(best, players.get(seat).hp());
            }
            List<Integer> winners = new ArrayList<>();
            for (int seat : aliveSeats) {
                if (players.get(seat).hp() == best) {
                    winners.add(seat);
                }
            }
            return new MatchOutcome(winners, MatchOutcome.Reason.DECK_EXHAUSTED);
        }
        return null;
    }

    private void startNextRound() {
        round++;
        startingSeat = (round - 1) % PLAYER_COUNT;
        java.util.Arrays.fill(placedThisRound, false);
        currentSeat = firstAliveFrom(startingSeat);
        finalRound = cardsRemaining() < FINAL_ROUND_THRESHOLD;
        phase = GamePhase.TURN;
    }

    /** Alive seats in this round's turn order, starting at startingSeat and wrapping. */
    private List<Integer> battleOrder() {
        List<Integer> order = new ArrayList<>();
        for (int i = 0; i < PLAYER_COUNT; i++) {
            int seat = (startingSeat + i) % PLAYER_COUNT;
            if (alive[seat]) {
                order.add(seat);
            }
        }
        return order;
    }

    private int nextSeatToPlace() {
        for (int i = 1; i <= PLAYER_COUNT; i++) {
            int seat = (currentSeat + i) % PLAYER_COUNT;
            if (alive[seat] && !placedThisRound[seat]) {
                return seat;
            }
        }
        return -1;
    }

    private int firstAliveFrom(int seat) {
        for (int i = 0; i < PLAYER_COUNT; i++) {
            int candidate = (seat + i) % PLAYER_COUNT;
            if (alive[candidate]) {
                return candidate;
            }
        }
        return seat;
    }

    private void requireTurn(int seat) {
        if (phase != GamePhase.TURN) {
            throw new InvalidMoveException(InvalidMoveException.Code.BAD_STATE, "Not in a turn phase: " + phase);
        }
        if (seat != currentSeat) {
            throw new InvalidMoveException(InvalidMoveException.Code.NOT_YOUR_TURN, "It is seat " + currentSeat + "'s turn");
        }
    }

    private void requireCardHeld() {
        if (heldCard == null) {
            throw new InvalidMoveException(InvalidMoveException.Code.NO_CARD_HELD, "No card currently held");
        }
    }

    private void requireNoCardHeld() {
        if (heldCard != null) {
            throw new InvalidMoveException(InvalidMoveException.Code.CARD_ALREADY_HELD, "A card is already held");
        }
    }

    public GamePhase phase() {
        return phase;
    }

    public int round() {
        return round;
    }

    public int startingSeat() {
        return startingSeat;
    }

    public int currentSeat() {
        return currentSeat;
    }

    public boolean isFinalRound() {
        return finalRound;
    }

    public List<Player> players() {
        return List.copyOf(players);
    }

    public Player player(int seat) {
        return players.get(seat);
    }

    public boolean isAlive(int seat) {
        return alive[seat];
    }

    public Card heldCard() {
        return heldCard;
    }

    public Card marketCard(Slot slot) {
        return market.cardAt(slot);
    }

    public int deckRemaining() {
        return deck.remaining();
    }
}
