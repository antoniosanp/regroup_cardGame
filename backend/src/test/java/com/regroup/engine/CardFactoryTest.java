package com.regroup.engine;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

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

    @Test
    void everyCardHasFourCornersAndNoRepeatedStatCategory() {
        List<Card> cards = new CardFactory(new Random(1)).createCards(5);
        for (Card card : cards) {
            List<CornerAttribute> corners = corners(card);
            assertEquals(4, corners.size());
            Map<StatCategory, Integer> perCategory = new EnumMap<>(StatCategory.class);
            for (CornerAttribute attr : corners) {
                if (attr.category() != StatCategory.NONE) {
                    perCategory.merge(attr.category(), 1, Integer::sum);
                }
            }
            for (var entry : perCategory.entrySet()) {
                assertTrue(entry.getValue() <= 1,
                        "Card must not repeat a stat category: " + entry.getKey());
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

    @Test
    void ratioIsFourToTwoToOne() {
        int units = 7;
        List<Card> cards = new CardFactory(new Random(3)).createCards(units);
        assertEquals(units * 7, cards.size());

        int normal = 0;
        int doubles = 0;
        int empties = 0;
        for (Card card : cards) {
            List<CornerAttribute> corners = corners(card);
            long noneCorners = count(corners, a -> a.category() == StatCategory.NONE);
            long plus2 = count(corners, CardFactoryTest::isPlus2);
            if (noneCorners == 1) {
                empties++;
            } else if (plus2 == 1) {
                doubles++;
            } else {
                normal++;
            }
        }
        assertEquals(units * 4, normal);
        assertEquals(units * 2, doubles);
        assertEquals(units * 1, empties);
    }

    @Test
    void doubledCategoryIsEvenlyDistributed() {
        // 8 units => 16 double cards => 4 of each doubled category.
        List<Card> cards = new CardFactory(new Random(4)).createCards(8);
        Map<StatCategory, Integer> doubledPerCategory = new EnumMap<>(StatCategory.class);
        for (Card card : cards) {
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
