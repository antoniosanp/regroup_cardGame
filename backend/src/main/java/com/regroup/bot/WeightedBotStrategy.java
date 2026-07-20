package com.regroup.bot;

import com.regroup.engine.Board;
import com.regroup.engine.Card;
import com.regroup.engine.MatchEngine;
import com.regroup.engine.Slot;

import java.util.IdentityHashMap;
import java.util.Random;
import java.util.function.ToDoubleFunction;

/**
 * Shared brain of the three personalities: pick the card whose best simulated placement scores
 * highest (minus its coin price), then play that placement. Subclasses only supply the per-turn
 * scoring function. The scorer and the per-card best moves are rolled once in {@link #choosePick}
 * and reused by {@link #choosePlacement}, so a turn's pick and placement always agree.
 */
public abstract class WeightedBotStrategy implements BotStrategy {

    protected final Random rng;

    private ToDoubleFunction<MoveEvaluator.EvaluatedMove> turnScorer;
    private final IdentityHashMap<Card, MoveEvaluator.EvaluatedMove> bestByCard = new IdentityHashMap<>();

    protected WeightedBotStrategy(Random rng) {
        this.rng = rng;
    }

    /** This turn's scoring function; where the personality lives (dice roll, weights, opponent analysis). */
    protected abstract ToDoubleFunction<MoveEvaluator.EvaluatedMove> rollScorer(MatchEngine engine, int seat);

    @Override
    public final PickChoice choosePick(MatchEngine engine, int seat) {
        turnScorer = rollScorer(engine, seat);
        bestByCard.clear();
        Board board = engine.player(seat).board();
        int coins = engine.player(seat).cn();

        PickChoice bestChoice = null;
        double bestScore = Double.NEGATIVE_INFINITY;
        for (Slot slot : Slot.values()) {
            Card card = engine.marketCard(slot);
            int price = engine.isFinalRound() ? 0 : slot.price();
            if (card == null || coins < price) {
                continue;
            }
            MoveEvaluator.EvaluatedMove best = MoveEvaluator.best(MoveEvaluator.evaluateAll(board, card), turnScorer, rng);
            bestByCard.put(card, best);
            // Coins cap at 2 and buy future flexibility, so a paid slot must beat the free options by a margin.
            double score = turnScorer.applyAsDouble(best) - price * BotTuning.COIN_COST_PENALTY;
            if (score > bestScore) {
                bestScore = score;
                bestChoice = PickChoice.market(slot);
            }
        }
        if (engine.deckRemaining() > 0 && BotTuning.DECK_EXPECTED_VALUE > bestScore) {
            bestChoice = PickChoice.DECK;
        }
        return bestChoice;
    }

    @Override
    public final Placement choosePlacement(MatchEngine engine, int seat, Card held) {
        MoveEvaluator.EvaluatedMove cached = bestByCard.get(held);
        if (cached != null) {
            return cached.placement();
        }
        // Deck draws are unknown at pick time (and tests may call this standalone): evaluate now.
        if (turnScorer == null) {
            turnScorer = rollScorer(engine, seat);
        }
        var moves = MoveEvaluator.evaluateAll(engine.player(seat).board(), held);
        return MoveEvaluator.best(moves, turnScorer, rng).placement();
    }
}
