package com.regroup.engine;

/** What sits at a single point on a player's board: the attribute contributing to stats, plus the rotation the UI should draw it at. */
public record BoardCell(CornerAttribute attribute, Rotation rotation) {
}
