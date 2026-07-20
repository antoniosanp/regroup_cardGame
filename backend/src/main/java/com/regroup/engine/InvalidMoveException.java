package com.regroup.engine;

/** Thrown by the engine on any illegal move; the code maps directly to a wire error code. */
public class InvalidMoveException extends RuntimeException {

    public enum Code {
        NOT_YOUR_TURN,
        CARD_ALREADY_HELD,
        NO_CARD_HELD,
        INSUFFICIENT_COINS,
        INVALID_PLACEMENT,
        BAD_STATE
    }

    private final Code code;

    public InvalidMoveException(Code code, String message) {
        super(message);
        this.code = code;
    }

    public Code getCode() {
        return code;
    }
}
