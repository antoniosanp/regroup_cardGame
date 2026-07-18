package com.regroup.engine;
import java.awt.Point;

public enum CornerPosition {
    TOP_LEFT(new Point(0, 1)),
    TOP_RIGHT(new Point(1, 1)),
    BOTTOM_LEFT(new Point(0, 0)),
    BOTTOM_RIGHT(new Point(1, 0));

    private final Point point;

    CornerPosition(Point point) {
        this.point = point;
    }

    public Point point() {
        return new Point(point); // defensive copy
    }
}