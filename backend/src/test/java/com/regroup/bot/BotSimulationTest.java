package com.regroup.bot;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.regroup.engine.Card;
import com.regroup.engine.Deck;
import com.regroup.engine.GamePhase;
import com.regroup.engine.MatchEngine;
import com.regroup.engine.PlacementResult;

import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Random;
import java.util.Set;
import java.util.function.Function;
import org.junit.jupiter.api.Test;

/**
 * Headless full matches straight on MatchEngine (no WebSocket layer), per botAIplan.md section 5.2:
 * every advanced personality must clearly beat random bots, no personality may be degenerate, and —
 * implicitly, since any InvalidMoveException fails the test — every move a strategy chooses is legal.
 */
class BotSimulationTest {

    private static final int MATCHES_PER_MATCHUP = 50;

    /** Plays one match to the end; the winning seats, or empty for the rare wedged no-card corner case. */
    private static Set<Integer> runMatch(Map<Integer, BotStrategy> bySeat, long deckSeed) {
        MatchEngine engine = new MatchEngine(Deck.standard(new Random(deckSeed)));
        engine.start();
        int guard = 0;
        while (engine.phase() == GamePhase.TURN) {
            assertTrue(++guard < 1000, "runaway match");
            int seat = engine.currentSeat();
            BotStrategy strategy = bySeat.get(seat);

            PickChoice pick = strategy.choosePick(engine, seat);
            if (pick == null) {
                // Only legitimate when the deck is dry and the market can't serve this seat (a
                // pre-existing engine corner case when the final round holds fewer cards than
                // players). The live server leaves such a turn to the timeout; here the match
                // simply produces no winner.
                assertEquals(0, engine.deckRemaining(), "a strategy passed while cards remain");
                return Set.of();
            }
            Card held = pick.isDeck() ? engine.pickFromDeck(seat) : engine.pickFromMarket(seat, pick.slot());
            Placement placement = strategy.choosePlacement(engine, seat, held);
            for (int i = 0; i < placement.rotations(); i++) {
                engine.rotate(seat);
            }
            PlacementResult result = engine.place(seat, placement.overlapCorner(),
                    placement.x(), placement.y());
            if (result.roundEnded() && result.outcome() != null) {
                return Set.copyOf(result.outcome().winnerSeats());
            }
        }
        throw new AssertionError("match left the TURN phase without an outcome");
    }

    @Test
    void everyPersonalityBeatsThreeRandomBots() {
        Map<String, Function<Random, BotStrategy>> personalities = new LinkedHashMap<>();
        personalities.put("Defensive", DefensiveBotStrategy::new);
        personalities.put("Offensive", OffensiveBotStrategy::new);
        personalities.put("Adaptive", AdaptiveBotStrategy::new);

        personalities.forEach((name, factory) -> {
            int wins = 0;
            for (int m = 0; m < MATCHES_PER_MATCHUP; m++) {
                Random rng = new Random(1000L * name.hashCode() + m);
                int seatUnderTest = m % MatchEngine.PLAYER_COUNT; // rotate to cancel seat-order bias
                Map<Integer, BotStrategy> bySeat = new HashMap<>();
                for (int seat = 0; seat < MatchEngine.PLAYER_COUNT; seat++) {
                    bySeat.put(seat, seat == seatUnderTest ? factory.apply(rng) : new RandomBotStrategy(rng));
                }
                if (runMatch(bySeat, 555L + m).contains(seatUnderTest)) {
                    wins++;
                }
            }
            // A random seat wins 25% of the time; demand a clear margin above that.
            assertTrue(wins >= (int) (0.32 * MATCHES_PER_MATCHUP),
                    name + " won only " + wins + "/" + MATCHES_PER_MATCHUP + " against random bots");
        });
    }

    @Test
    void noPersonalityIsDegenerateInTheMixedMatchup() {
        String[] archetypes = {"Defensive", "Offensive", "Adaptive", "Random"};
        int[] winsByArchetype = new int[archetypes.length];
        for (int m = 0; m < MATCHES_PER_MATCHUP; m++) {
            Random rng = new Random(9000L + m);
            int offset = m % MatchEngine.PLAYER_COUNT; // rotate archetypes across seats
            Map<Integer, BotStrategy> bySeat = new HashMap<>();
            int[] archetypeAtSeat = new int[MatchEngine.PLAYER_COUNT];
            for (int seat = 0; seat < MatchEngine.PLAYER_COUNT; seat++) {
                int archetype = (seat + offset) % archetypes.length;
                archetypeAtSeat[seat] = archetype;
                bySeat.put(seat, switch (archetype) {
                    case 0 -> new DefensiveBotStrategy(rng);
                    case 1 -> new OffensiveBotStrategy(rng);
                    case 2 -> new AdaptiveBotStrategy(rng);
                    default -> new RandomBotStrategy(rng);
                });
            }
            for (int winner : runMatch(bySeat, 7000L + m)) {
                winsByArchetype[archetypeAtSeat[winner]]++;
            }
        }
        // The three advanced personalities must each win sometimes and never always.
        for (int a = 0; a < 3; a++) {
            assertTrue(winsByArchetype[a] >= 1 && winsByArchetype[a] < MATCHES_PER_MATCHUP,
                    archetypes[a] + " is degenerate: " + winsByArchetype[a] + "/" + MATCHES_PER_MATCHUP
                            + " wins (all: " + java.util.Arrays.toString(winsByArchetype) + ")");
        }
    }
}
