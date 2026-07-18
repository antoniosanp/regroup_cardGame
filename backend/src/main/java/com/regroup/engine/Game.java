package com.regroup.engine;

import java.awt.Point;

/** A minimal single-player session: pick a card from the market or deck, rotate it, place it, and see updated stats. */
public class Game {

    private final CardMarket market;
    private final BoardEngine boardEngine = new BoardEngine();
    private final CombatEngine combatEngine = new CombatEngine();
    private final Player player = new Player();

    private Card heldCard;

    public Game(Deck deck) {
        this.market = new CardMarket(deck);
    }

    public Player player() {
        return player;
    }

    public CardMarket market() {
        return market;
    }

    public Card heldCard() {
        return heldCard;
    }

    public boolean hasCardHeld() {
        return heldCard != null;
    }

    /** Takes the card at slot, paying its price in coins; the price is only known to be affordable, never deducted below zero. */
    public Card pick(Slot slot) {
        requireNoCardHeld();
        int price = slot.price();
        if (player.cn() < price) {
            throw new IllegalStateException("Not enough coins for slot " + slot);
        }
        Card card = market.take(slot);
        player.setCn(player.cn() - price);
        heldCard = card;
        return card;
    }

    /** Draws the free top card of the deck directly, without touching the market's face-up slots. */
    public Card pickFaceDown() {
        requireNoCardHeld();
        heldCard = market.takeFaceDown();
        return heldCard;
    }

    public void rotateHeldCard() {
        requireCardHeld();
        boardEngine.rotateCard(heldCard);
    }

    /** Places the held card, anchoring overlapCorner on atPoint, then recalculates stats from the updated board. */
    public void placeHeldCard(CornerPosition overlapCorner, Point atPoint) {
        requireCardHeld();
        boardEngine.placeCard(player.board(), heldCard, overlapCorner, atPoint);
        heldCard = null;
        recalculateStats();
    }

    public void recalculateStats() {
        combatEngine.calculateStats(player.board(), player);
    }

    private void requireCardHeld() {
        if (heldCard == null) {
            throw new IllegalStateException("No card currently held");
        }
    }

    private void requireNoCardHeld() {
        if (heldCard != null) {
            throw new IllegalStateException("A card is already held; place it before picking another");
        }
    }
}
