package com.regroup.engine;

import java.awt.Point;
import java.util.HashMap;
import java.util.Map;

/** A player's board: a cartesian plane of points, each holding whatever attribute the last card placed there left behind. */
public class Board {

    private final Map<Point, BoardCell> cells = new HashMap<>();

    public boolean isEmpty() {
        return cells.isEmpty();
    }

    public boolean hasPoint(Point point) {
        return cells.containsKey(point);
    }

    public BoardCell at(Point point) {
        return cells.get(point);
    }

    public void set(Point point, BoardCell cell) {
        cells.put(point, cell);
    }

    public Map<Point, BoardCell> cells() {
        return cells;
    }
}
