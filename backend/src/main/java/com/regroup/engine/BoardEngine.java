package com.regroup.engine;

import java.awt.Point;

public class BoardEngine {

    /** A card may be placed if the board is empty (a player's first move) or if the target point already exists on the board. */
    public boolean isValidPlacement(Board board, Card card, CornerPosition overlapCorner, Point atPoint) {
        return board.isEmpty() || board.hasPoint(atPoint);
    }

    /** Anchors the card so its {@code overlapCorner} lands on {@code atPoint}, then stamps all four corners onto the board, overwriting whatever was there before. */
    public void placeCard(Board board, Card card, CornerPosition overlapCorner, Point atPoint) {
        if (!isValidPlacement(board, card, overlapCorner, atPoint)) {
            throw new IllegalArgumentException("Card must share a corner with an existing card on the board");
        }

        Point overlapOffset = overlapCorner.point();
        for (CornerPosition position : CornerPosition.values()) {
            Point offset = position.point();
            Point globalPoint = new Point(
                    atPoint.x + (offset.x - overlapOffset.x),
                    atPoint.y + (offset.y - overlapOffset.y)
            );
            board.set(globalPoint, new BoardCell(card.at(position), card.rotation()));
        }
    }

    public void rotateCard(Card card) {
        card.rotate();
    }
}
