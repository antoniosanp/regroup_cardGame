package com.regroup.engine;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.util.Random;
import org.junit.jupiter.api.Test;

class CardMarketTest {

    private static Deck deckOf(int cards) {
        return new Deck(new CardFactory(new Random(1)).createCards(1).subList(0, cards));
    }

    @Test
    void pricesMatchSlotPosition() {
        assertEquals(0, Slot.A.price());
        assertEquals(1, Slot.B.price());
        assertEquals(2, Slot.C.price());
    }

    @Test
    void fillsAllThreeSlotsOnConstruction() {
        CardMarket market = new CardMarket(deckOf(6));
        assertNotNull(market.cardAt(Slot.A));
        assertNotNull(market.cardAt(Slot.B));
        assertNotNull(market.cardAt(Slot.C));
    }

    @Test
    void takingASlotShiftsTheRestDownAndRefills() {
        Deck deck = deckOf(6);
        CardMarket market = new CardMarket(deck);
        Card originalB = market.cardAt(Slot.B);
        Card originalC = market.cardAt(Slot.C);

        Card taken = market.take(Slot.A);

        assertNotNull(taken);
        assertEquals(originalB, market.cardAt(Slot.A));
        assertEquals(originalC, market.cardAt(Slot.B));
        assertNotNull(market.cardAt(Slot.C));
        assertEquals(2, deck.remaining());
    }

    @Test
    void takeFaceDownDrawsFromDeckWithoutTouchingSlots() {
        Deck deck = deckOf(6);
        CardMarket market = new CardMarket(deck);
        Card a = market.cardAt(Slot.A);
        Card b = market.cardAt(Slot.B);
        Card c = market.cardAt(Slot.C);

        Card drawn = market.takeFaceDown();

        assertNotNull(drawn);
        assertEquals(a, market.cardAt(Slot.A));
        assertEquals(b, market.cardAt(Slot.B));
        assertEquals(c, market.cardAt(Slot.C));
        assertEquals(2, deck.remaining());
    }

    @Test
    void takingAnEmptySlotThrows() {
        CardMarket market = new CardMarket(deckOf(0));
        assertThrows(IllegalStateException.class, () -> market.take(Slot.A));
    }

    @Test
    void slotsShrinkAsTheDeckRunsDry() {
        CardMarket market = new CardMarket(deckOf(1));
        assertNotNull(market.cardAt(Slot.A));
        assertNull(market.cardAt(Slot.B));
        assertNull(market.cardAt(Slot.C));

        market.take(Slot.A);
        assertNull(market.cardAt(Slot.A));
    }
}
