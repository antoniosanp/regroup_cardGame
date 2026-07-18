package com.regroup.engine;

import java.util.EnumMap;
import java.util.Map;

public class Card {

    private final Map<CornerPosition, CornerAttribute> corners = new EnumMap<>(CornerPosition.class);
    private Rotation rotation = Rotation.DEG_0;

    public Card(CornerAttribute topLeft, CornerAttribute topRight, CornerAttribute bottomLeft, CornerAttribute bottomRight) {
        corners.put(CornerPosition.TOP_LEFT, topLeft);
        corners.put(CornerPosition.TOP_RIGHT, topRight);
        corners.put(CornerPosition.BOTTOM_LEFT, bottomLeft);
        corners.put(CornerPosition.BOTTOM_RIGHT, bottomRight);
    }

    public CornerAttribute at(CornerPosition position) {
        return corners.get(position);
    }

    /** How many quarter-turns this card has been rotated; UI-only, ignored by placement/stat logic. */
    public Rotation rotation() {
        return rotation;
    }

    /** Rotates the card 90 degrees clockwise in place: each corner takes on the attribute that was counter-clockwise from it. */
    public void rotate() {
        CornerAttribute topLeft = corners.get(CornerPosition.TOP_LEFT);
        CornerAttribute topRight = corners.get(CornerPosition.TOP_RIGHT);
        CornerAttribute bottomRight = corners.get(CornerPosition.BOTTOM_RIGHT);
        CornerAttribute bottomLeft = corners.get(CornerPosition.BOTTOM_LEFT);

        corners.put(CornerPosition.TOP_RIGHT, topLeft);
        corners.put(CornerPosition.BOTTOM_RIGHT, topRight);
        corners.put(CornerPosition.BOTTOM_LEFT, bottomRight);
        corners.put(CornerPosition.TOP_LEFT, bottomLeft);

        rotation = rotation.clockwise();
    }
}
