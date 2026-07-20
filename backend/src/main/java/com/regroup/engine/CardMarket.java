package com.regroup.engine;

import java.util.ArrayList;
import java.util.List;

/** The three face-up card slots (A/B/C) backed by a Deck: taking a slot shifts the rest down and refills from the deck. */
public class CardMarket {

    private final Deck deck;
    private final List<Card> faceUp = new ArrayList<>(Slot.values().length);

    public CardMarket(Deck deck) {
        this.deck = deck;
        refill();
    }

    /** The card currently shown at slot, or null if the deck ran dry before this slot could be filled. */
    public Card cardAt(Slot slot) {
        return slot.ordinal() < faceUp.size() ? faceUp.get(slot.ordinal()) : null;
    }

    /** Removes the card at slot, shifts the remaining face-up cards down to fill the gap, and refills from the deck. */
    public Card take(Slot slot) {
        Card taken = cardAt(slot);
        if (taken == null) {
            throw new IllegalStateException("No card at slot " + slot);
        }
        faceUp.remove(slot.ordinal());
        refill();
        return taken;
    }

    /** Draws the top card of the deck directly; free, and doesn't touch the face-up slots. */
    public Card takeFaceDown() {
        return deck.draw();
    }

    /** True once no face-up cards remain; since slots are refilled from the deck, this also implies the deck is empty. */
    public boolean isExhausted() {
        return faceUp.isEmpty();
    }

    /** How many face-up slots currently hold a card (at most 3). */
    public int filledSlotCount() {
        return faceUp.size();
    }

    private void refill() {
        while (faceUp.size() < Slot.values().length && !deck.isEmpty()) {
            faceUp.add(deck.draw());
        }
    }
}
