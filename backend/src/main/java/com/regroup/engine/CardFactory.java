package com.regroup.engine;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Random;

/** Produces the initial cards for a game: NORMAL, DOUBLE, and EMPTY shapes in a fixed 4:2:1 ratio per 7-card unit, with corner position and rotation randomized per card so the deck has no detectable pattern. */
public class CardFactory {

    /** The four non-NONE stat categories, in a fixed order used for even round-robin distribution. */
    private static final List<StatCategory> STATS =
            List.of(StatCategory.PA, StatCategory.PD, StatCategory.MA, StatCategory.MD);

    /** The three "empty" NONE-category corner attributes, cycled across empty cards. */
    private static final List<CornerAttribute> NONE_ATTRS =
            List.of(CornerAttribute.EMPTY, CornerAttribute.HP_POTION_COIN, CornerAttribute.COINS_2);

    static final int NORMAL_PER_UNIT = 4;
    static final int DOUBLE_PER_UNIT = 2;
    static final int EMPTY_PER_UNIT = 1;
    static final int CARDS_PER_UNIT = NORMAL_PER_UNIT + DOUBLE_PER_UNIT + EMPTY_PER_UNIT;

    private final Random random;

    /** random is the shuffle source; pass a seeded Random for reproducible decks in tests. */
    public CardFactory(Random random) {
        this.random = random;
    }

    /** Produces units * 7 cards in the 4:2:1 NORMAL:DOUBLE:EMPTY ratio, then shuffles them. */
    public List<Card> createCards(int units) {
        if (units < 1) {
            throw new IllegalArgumentException("units must be at least 1, got " + units);
        }

        List<Card> cards = new ArrayList<>(units * CARDS_PER_UNIT);
        int doubleCount = 0;
        int emptyCount = 0;

        for (int u = 0; u < units; u++) {
            for (int i = 0; i < NORMAL_PER_UNIT; i++) {
                cards.add(normalCard());
            }
            for (int i = 0; i < DOUBLE_PER_UNIT; i++) {
                // Round-robin the doubled category so no single stat is over-represented.
                cards.add(doubleCard(STATS.get(doubleCount % STATS.size())));
                doubleCount++;
            }
            for (int i = 0; i < EMPTY_PER_UNIT; i++) {
                StatCategory omitted = STATS.get(emptyCount % STATS.size());
                CornerAttribute none = NONE_ATTRS.get(emptyCount % NONE_ATTRS.size());
                cards.add(emptyCard(omitted, none));
                emptyCount++;
            }
        }

        Collections.shuffle(cards, random);
        return cards;
    }

    /** One +1 corner of every stat category. */
    private Card normalCard() {
        return buildCard(List.of(
                CornerAttribute.PA_1, CornerAttribute.PD_1, CornerAttribute.MA_1, CornerAttribute.MD_1));
    }

    /** doubled at +2, the other three categories at +1. */
    private Card doubleCard(StatCategory doubled) {
        List<CornerAttribute> corners = new ArrayList<>(4);
        for (StatCategory cat : STATS) {
            corners.add(cat == doubled ? plus2(cat) : plus1(cat));
        }
        return buildCard(corners);
    }

    /** One NONE-category corner plus +1 corners of the three categories other than omitted. */
    private Card emptyCard(StatCategory omitted, CornerAttribute none) {
        List<CornerAttribute> corners = new ArrayList<>(4);
        corners.add(none);
        for (StatCategory cat : STATS) {
            if (cat != omitted) {
                corners.add(plus1(cat));
            }
        }
        return buildCard(corners);
    }

    /** Randomizes which of the four positions each attribute lands on, then applies a random rotation. */
    private Card buildCard(List<CornerAttribute> fourCorners) {
        List<CornerAttribute> shuffled = new ArrayList<>(fourCorners);
        Collections.shuffle(shuffled, random);
        Card card = new Card(shuffled.get(0), shuffled.get(1), shuffled.get(2), shuffled.get(3));
        int rotations = random.nextInt(4);
        for (int i = 0; i < rotations; i++) {
            card.rotate();
        }
        return card;
    }

    private static CornerAttribute plus1(StatCategory category) {
        return switch (category) {
            case PA -> CornerAttribute.PA_1;
            case PD -> CornerAttribute.PD_1;
            case MA -> CornerAttribute.MA_1;
            case MD -> CornerAttribute.MD_1;
            case NONE -> throw new IllegalArgumentException("NONE has no +1 variant");
        };
    }

    private static CornerAttribute plus2(StatCategory category) {
        return switch (category) {
            case PA -> CornerAttribute.PA_2;
            case PD -> CornerAttribute.PD_2;
            case MA -> CornerAttribute.MA_2;
            case MD -> CornerAttribute.MD_2;
            case NONE -> throw new IllegalArgumentException("NONE has no +2 variant");
        };
    }
}
