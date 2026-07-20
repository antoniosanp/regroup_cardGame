package com.regroup.bot;

import com.regroup.engine.Board;
import com.regroup.engine.Card;
import com.regroup.engine.CornerPosition;
import com.regroup.engine.MatchEngine;
import com.regroup.engine.Slot;

import java.awt.Point;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;

/** The original "easy" bot: a uniform-random affordable pick and a uniform-random legal placement, never rotating. */
public class RandomBotStrategy implements BotStrategy {

    private final Random rng;

    public RandomBotStrategy(Random rng) {
        this.rng = rng;
    }

    @Override
    public PickChoice choosePick(MatchEngine engine, int seat) {
        List<PickChoice> options = new ArrayList<>();
        if (engine.deckRemaining() > 0) {
            options.add(PickChoice.DECK);
        }
        int coins = engine.player(seat).cn();
        for (Slot slot : Slot.values()) {
            int price = engine.isFinalRound() ? 0 : slot.price();
            if (engine.marketCard(slot) != null && coins >= price) {
                options.add(PickChoice.market(slot));
            }
        }
        return options.isEmpty() ? null : options.get(rng.nextInt(options.size()));
    }

    @Override
    public Placement choosePlacement(MatchEngine engine, int seat, Card held) {
        Board board = engine.player(seat).board();
        Point at;
        if (board.isEmpty()) {
            at = new Point(0, 0);
        } else {
            List<Point> points = new ArrayList<>(board.cells().keySet());
            at = points.get(rng.nextInt(points.size()));
        }
        CornerPosition corner = CornerPosition.values()[rng.nextInt(CornerPosition.values().length)];
        return new Placement(0, corner, at.x, at.y);
    }
}
