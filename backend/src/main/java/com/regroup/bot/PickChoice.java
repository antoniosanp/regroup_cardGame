package com.regroup.bot;

import com.regroup.engine.Slot;

import java.util.Objects;

/** A bot's pick decision: a face-up market slot, or the face-down deck when {@code slot} is null. */
public record PickChoice(Slot slot) {

    public static final PickChoice DECK = new PickChoice(null);

    public static PickChoice market(Slot slot) {
        return new PickChoice(Objects.requireNonNull(slot));
    }

    public boolean isDeck() {
        return slot == null;
    }

    /** The slot string the WS contract uses in CardPicked ("DECK" or the slot name). */
    public String wireName() {
        return isDeck() ? "DECK" : slot.name();
    }
}
