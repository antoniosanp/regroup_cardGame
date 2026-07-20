package com.regroup.engine;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Random;

/**
 * Produces the initial cards for a game: NORMAL, DOUBLE, PAIR, and EMPTY shapes in a fixed 3:2:2:1 ratio
 * per 8-card unit, with corner position and rotation randomized per card so the deck has no detectable
 * pattern.
 *
 * <p>PAIR is the only shape that repeats a stat category, and per gameRules.md its two matching corners
 * must land <em>diagonally</em> opposite. Adjacent corners of a card are orthogonal neighbours once
 * placed, so an adjacent pair would satisfy {@code CombatEngine}'s adjacency check against itself and
 * score for free; a diagonal pair never self-matches, so the player still has to earn it on the board.
 */
public class CardFactory {

    /** The four non-NONE stat categories, in a fixed order used for even round-robin distribution. */
    private static final List<StatCategory> STATS =
            List.of(StatCategory.PA, StatCategory.PD, StatCategory.MA, StatCategory.MD);

    /** The three "empty" NONE-category corner attributes, cycled across empty cards. */
    private static final List<CornerAttribute> NONE_ATTRS =
            List.of(CornerAttribute.EMPTY, CornerAttribute.HP_POTION_COIN, CornerAttribute.COINS_2);

    static final int NORMAL_PER_UNIT = 3;
    static final int DOUBLE_PER_UNIT = 2;
    static final int PAIR_PER_UNIT = 2;
    static final int EMPTY_PER_UNIT = 1;
    static final int CARDS_PER_UNIT =
            NORMAL_PER_UNIT + DOUBLE_PER_UNIT + PAIR_PER_UNIT + EMPTY_PER_UNIT;

    private final Random random;

    /** random is the shuffle source; pass a seeded Random for reproducible decks in tests. */
    public CardFactory(Random random) {
        this.random = random;
    }

    /** Produces units * 8 cards in the 3:2:2:1 NORMAL:DOUBLE:PAIR:EMPTY ratio, then shuffles them. */
    public List<Card> createCards(int units) {
        if (units < 1) {
            throw new IllegalArgumentException("units must be at least 1, got " + units);
        }

        List<Card> cards = new ArrayList<>(units * CARDS_PER_UNIT);
        int doubleCount = 0;
        int pairCount = 0;
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
            for (int i = 0; i < PAIR_PER_UNIT; i++) {
                // Round-robin the paired category on its own counter, same as doubleCount above.
                StatCategory paired = STATS.get(pairCount % STATS.size());
                // A pair card carries only 3 of the 4 categories; cycle which one sits out on a
                // slower counter so it advances once per full lap of `paired`, keeping every
                // (paired, omitted) combination evenly represented across the deck.
                StatCategory omitted = othersOf(paired).get((pairCount / STATS.size()) % 3);
                cards.add(pairCard(paired, omitted));
                pairCount++;
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

    /** The three stat categories other than category, in STATS order. */
    private static List<StatCategory> othersOf(StatCategory category) {
        List<StatCategory> others = new ArrayList<>(3);
        for (StatCategory cat : STATS) {
            if (cat != category) {
                others.add(cat);
            }
        }
        return others;
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

    /**
     * paired at +2 and +1 on one diagonal, the two categories other than paired and omitted at +1 on
     * the other. The duplicate must stay diagonal (see the class doc), so this is the one shape that
     * cannot use the free-shuffle builder.
     */
    private Card pairCard(StatCategory paired, StatCategory omitted) {
        List<CornerAttribute> pairDiagonal = new ArrayList<>(List.of(plus2(paired), plus1(paired)));
        List<CornerAttribute> otherDiagonal = new ArrayList<>(2);
        for (StatCategory cat : STATS) {
            if (cat != paired && cat != omitted) {
                otherDiagonal.add(plus1(cat));
            }
        }
        return buildCardWithDiagonalPair(pairDiagonal, otherDiagonal);
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

    /**
     * Randomizes which of the four positions each attribute lands on. That alone already makes each
     * card's layout unpredictable, so cards start at DEG_0 — an extra random rotation on top would be
     * purely cosmetic (rotation is a player action during placement, per gameRules.md) and would leave
     * freshly-dealt cards, including ones still sitting in the market, rendered visibly tilted for no
     * reason.
     */
    private Card buildCard(List<CornerAttribute> fourCorners) {
        List<CornerAttribute> shuffled = new ArrayList<>(fourCorners);
        Collections.shuffle(shuffled, random);
        return new Card(shuffled.get(0), shuffled.get(1), shuffled.get(2), shuffled.get(3));
    }

    /**
     * Places two attributes on one diagonal and two on the other, randomizing both which diagonal gets
     * which pair and the order within each. Used for PAIR cards, where a free shuffle could drop the two
     * matching corners next to each other and let them score off one another. The other shapes carry four
     * distinct categories (or three plus a NONE), so no arrangement of theirs can repeat adjacently and
     * they keep using {@link #buildCard}.
     */
    private Card buildCardWithDiagonalPair(
            List<CornerAttribute> pairDiagonal, List<CornerAttribute> otherDiagonal) {
        List<CornerAttribute> pair = new ArrayList<>(pairDiagonal);
        List<CornerAttribute> other = new ArrayList<>(otherDiagonal);
        Collections.shuffle(pair, random);
        Collections.shuffle(other, random);
        // The two diagonals are TL+BR and TR+BL; Card takes (TL, TR, BL, BR).
        return random.nextBoolean()
                ? new Card(pair.get(0), other.get(0), other.get(1), pair.get(1))
                : new Card(other.get(0), pair.get(0), pair.get(1), other.get(1));
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
