package com.regroup.engine;

/** The three face-up card positions. A is free, B costs 1 coin, C costs 2 — the coin cost equals the slot's position. */
public enum Slot {
    A, B, C;

    public int price() {
        return ordinal();
    }
}
