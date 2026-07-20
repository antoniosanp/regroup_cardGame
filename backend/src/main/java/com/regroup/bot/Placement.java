package com.regroup.bot;

import com.regroup.engine.CornerPosition;

/**
 * A bot's placement decision: rotate the held card {@code rotations} quarter-turns clockwise
 * (via the engine, so the UI-facing rotation stays consistent), then anchor {@code overlapCorner}
 * at board point (x, y).
 */
public record Placement(int rotations, CornerPosition overlapCorner, int x, int y) {
}
