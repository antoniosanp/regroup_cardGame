package com.regroup.engine;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.awt.Point;
import java.util.ArrayList;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.Random;
import org.junit.jupiter.api.Test;

class CardFactoryTest {

    private List<CornerAttribute> corners(Card card) {
        List<CornerAttribute> result = new ArrayList<>();
        for (CornerPosition position : CornerPosition.values()) {
            result.add(card.at(position));
        }
        return result;
    }

    private long count(List<CornerAttribute> corners, java.util.function.Predicate<CornerAttribute> p) {
        return corners.stream().filter(p).count();
    }

    private static boolean isPlus2(CornerAttribute attr) {
        return attr == CornerAttribute.PA_2 || attr == CornerAttribute.PD_2
                || attr == CornerAttribute.MA_2 || attr == CornerAttribute.MD_2;
    }

    /** Positions a card repeats a stat category on, or empty if it repeats none. */
    private static List<CornerPosition> repeatedCategoryPositions(Card card) {
        Map<StatCategory, List<CornerPosition>> byCategory = new EnumMap<>(StatCategory.class);
        for (CornerPosition position : CornerPosition.values()) {
            StatCategory category = card.at(position).category();
            if (category != StatCategory.NONE) {
                byCategory.computeIfAbsent(category, c -> new ArrayList<>()).add(position);
            }
        }
        for (List<CornerPosition> positions : byCategory.values()) {
            if (positions.size() > 1) {
                return positions;
            }
        }
        return List.of();
    }

    /**
     * Corners are unit points on the board lattice, so Manhattan distance 1 means the two corners are
     * orthogonal neighbours (adjacent) and 2 means they only touch at a point (diagonal).
     */
    private static boolean isDiagonal(CornerPosition a, CornerPosition b) {
        Point pa = a.point();
        Point pb = b.point();
        return Math.abs(pa.x - pb.x) + Math.abs(pa.y - pb.y) == 2;
    }

    @Test
    void everyCardHasFourCornersAndRepeatsAtMostOneCategoryDiagonally() {
        List<Card> cards = new CardFactory(new Random(1)).createCards(5);
        for (Card card : cards) {
            assertEquals(4, corners(card).size());

            Map<StatCategory, Integer> perCategory = new EnumMap<>(StatCategory.class);
            for (CornerAttribute attr : corners(card)) {
                if (attr.category() != StatCategory.NONE) {
                    perCategory.merge(attr.category(), 1, Integer::sum);
                }
            }
            long repeated = perCategory.values().stream().filter(count -> count > 1).count();
            assertTrue(repeated <= 1, "At most one stat category may repeat, found " + repeated);
            for (var entry : perCategory.entrySet()) {
                assertTrue(entry.getValue() <= 2,
                        "A stat category may appear at most twice: " + entry.getKey());
            }

            // The load-bearing invariant: a repeated category must never sit on adjacent corners,
            // or the two would satisfy CombatEngine's adjacency check against each other and score
            // without the player placing the card next to anything.
            List<CornerPosition> repeatedAt = repeatedCategoryPositions(card);
            if (!repeatedAt.isEmpty()) {
                assertEquals(2, repeatedAt.size());
                assertTrue(isDiagonal(repeatedAt.get(0), repeatedAt.get(1)),
                        "Repeated category must be diagonal, was " + repeatedAt);
            }
        }
    }

    @Test
    void noCardHasMoreThanOnePlus2Corner() {
        List<Card> cards = new CardFactory(new Random(2)).createCards(5);
        for (Card card : cards) {
            long plus2 = count(corners(card), CardFactoryTest::isPlus2);
            assertTrue(plus2 <= 1, "At most one +2 corner per card, found " + plus2);
        }
    }

    private enum Shape { NORMAL, DOUBLE, PAIR, EMPTY }

    /** PAIR is checked before DOUBLE: both carry exactly one +2, only PAIR repeats a category. */
    private static Shape shapeOf(Card card) {
        List<CornerAttribute> corners = new ArrayList<>();
        for (CornerPosition position : CornerPosition.values()) {
            corners.add(card.at(position));
        }
        if (corners.stream().anyMatch(a -> a.category() == StatCategory.NONE)) {
            return Shape.EMPTY;
        }
        if (!repeatedCategoryPositions(card).isEmpty()) {
            return Shape.PAIR;
        }
        return corners.stream().anyMatch(CardFactoryTest::isPlus2) ? Shape.DOUBLE : Shape.NORMAL;
    }

    @Test
    void ratioIsThreeToTwoToTwoToOne() {
        int units = 7;
        List<Card> cards = new CardFactory(new Random(3)).createCards(units);
        assertEquals(units * 8, cards.size());

        Map<Shape, Integer> perShape = new EnumMap<>(Shape.class);
        for (Card card : cards) {
            perShape.merge(shapeOf(card), 1, Integer::sum);
        }
        assertEquals(units * 3, perShape.getOrDefault(Shape.NORMAL, 0));
        assertEquals(units * 2, perShape.getOrDefault(Shape.DOUBLE, 0));
        assertEquals(units * 2, perShape.getOrDefault(Shape.PAIR, 0));
        assertEquals(units * 1, perShape.getOrDefault(Shape.EMPTY, 0));
    }

    @Test
    void doubledCategoryIsEvenlyDistributed() {
        // 8 units => 16 double cards => 4 of each doubled category. Counted per DOUBLE card, since
        // PAIR cards also carry a +2 corner and would otherwise inflate the totals.
        List<Card> cards = new CardFactory(new Random(4)).createCards(8);
        Map<StatCategory, Integer> doubledPerCategory = new EnumMap<>(StatCategory.class);
        for (Card card : cards) {
            if (shapeOf(card) != Shape.DOUBLE) {
                continue;
            }
            for (CornerAttribute attr : corners(card)) {
                if (isPlus2(attr)) {
                    doubledPerCategory.merge(attr.category(), 1, Integer::sum);
                }
            }
        }
        assertEquals(4, doubledPerCategory.size(), "All four stats should appear as the doubled one");
        for (int perCategory : doubledPerCategory.values()) {
            assertEquals(4, perCategory);
        }
    }

    @Test
    void pairedCategoryIsEvenlyDistributed() {
        // 8 units => 16 pair cards => 4 of each paired category.
        List<Card> cards = new CardFactory(new Random(6)).createCards(8);
        Map<StatCategory, Integer> pairedPerCategory = new EnumMap<>(StatCategory.class);
        for (Card card : cards) {
            if (shapeOf(card) != Shape.PAIR) {
                continue;
            }
            List<CornerPosition> repeatedAt = repeatedCategoryPositions(card);
            pairedPerCategory.merge(card.at(repeatedAt.get(0)).category(), 1, Integer::sum);
        }
        assertEquals(4, pairedPerCategory.size(), "All four stats should appear as the paired one");
        for (int perCategory : pairedPerCategory.values()) {
            assertEquals(4, perCategory);
        }
    }

    @Test
    void pairCardsCarryOnePlus1AndOnePlus2OfTheRepeatedCategory() {
        List<Card> cards = new CardFactory(new Random(7)).createCards(6);
        int pairs = 0;
        for (Card card : cards) {
            if (shapeOf(card) != Shape.PAIR) {
                continue;
            }
            pairs++;
            List<CornerPosition> repeatedAt = repeatedCategoryPositions(card);
            long plus2 = repeatedAt.stream().filter(p -> isPlus2(card.at(p))).count();
            assertEquals(1, plus2, "A pair is one +2 and one +1 of the same category");
            // Three distinct categories: the repeated one plus two others.
            assertEquals(3, corners(card).stream().map(CornerAttribute::category).distinct().count());
        }
        assertTrue(pairs > 0, "Expected the deck to contain pair cards");
    }

    @Test
    void standardDeckHas112Cards() {
        assertEquals(112, Deck.standard(new Random(8)).remaining());
    }

    @Test
    void emptyCardsHaveExactlyOneNoneCornerAndThreeStats() {
        List<Card> cards = new CardFactory(new Random(5)).createCards(6);
        for (Card card : cards) {
            List<CornerAttribute> corners = corners(card);
            long noneCorners = count(corners, a -> a.category() == StatCategory.NONE);
            if (noneCorners >= 1) {
                assertEquals(1, noneCorners, "Empty card has exactly one NONE corner");
                long statCorners = count(corners, a -> a.category() != StatCategory.NONE);
                assertEquals(3, statCorners);
            }
        }
    }

    @Test
    void sameSeedProducesIdenticalDecks() {
        List<Card> a = new CardFactory(new Random(42)).createCards(4);
        List<Card> b = new CardFactory(new Random(42)).createCards(4);
        assertEquals(a.size(), b.size());
        for (int i = 0; i < a.size(); i++) {
            assertEquals(corners(a.get(i)), corners(b.get(i)),
                    "Card " + i + " should match for identical seeds");
            assertEquals(a.get(i).rotation(), b.get(i).rotation());
        }
    }
}
