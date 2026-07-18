package com.regroup.engine;

/** Purely cosmetic: how many quarter-turns a card/attribute has been rotated, for the UI to draw it correctly. Never read by game-logic calculations. */
public enum Rotation {
    DEG_0,
    DEG_90,
    DEG_180,
    DEG_270;

    public Rotation clockwise() {
        return values()[(ordinal() + 1) % values().length];
    }
}
