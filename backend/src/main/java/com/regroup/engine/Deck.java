package com.regroup.engine;

import java.util.ArrayDeque;
import java.util.Deque;
import java.util.List;
import java.util.NoSuchElementException;
import java.util.Random;

/** The face-down draw pile: an ordered stack of already-shuffled cards drawn from the top. Composition lives in CardFactory. Per the game rules, a game can end when this pile runs out, so callers should check isEmpty() rather than relying on draw() to signal exhaustion. */
public class Deck {

    /** Default number of 8-card units in a standard deck: 14 units = 112 cards. */
    public static final int DEFAULT_UNITS = 14;

    private final Deque<Card> drawPile;

    /** cards is the draw order, top of the pile first; already shuffled by the caller. */
    public Deck(List<Card> cards) {
        this.drawPile = new ArrayDeque<>(cards);
    }

    /** A standard shuffled deck: a 4-player game draws one card per player-turn plus three to seed the A/B/C slots, so 112 cards comfortably covers a full game. */
    public static Deck standard(Random random) {
        return new Deck(new CardFactory(random).createCards(DEFAULT_UNITS));
    }

    /** Removes and returns the top card; throws if the pile is empty, since that's a game-ending condition rather than an error to swallow silently — check isEmpty() first. */
    public Card draw() {
        Card card = drawPile.poll();
        if (card == null) {
            throw new NoSuchElementException("Draw pile is empty");
        }
        return card;
    }

    public boolean isEmpty() {
        return drawPile.isEmpty();
    }

    public int remaining() {
        return drawPile.size();
    }
}
