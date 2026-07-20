package com.regroup.websocket;

import java.util.List;
import java.util.Map;

/**
 * Server -> client message records. Field names are the exact wire contract (WS_CONTRACT.md).
 * Regroup has no hidden information, so broadcasts carry full detail; the only private messages
 * are MATCH_FOUND, RESUME_STATE and ERROR.
 */
public final class Messages {

    private Messages() {
    }

    public record PlayerInfo(String playerId, String name, int seat) {
    }

    public record Stats(int hp, int pa, int pd, int ma, int md, int cn, int hpp) {
    }

    public record CardDto(String topLeft, String topRight, String bottomLeft, String bottomRight, String rotation) {
    }

    public record BoardCellDto(int x, int y, String attribute, String rotation) {
    }

    public record PlayerState(String playerId, String name, int seat, boolean alive, Stats stats) {
    }

    // Private queue (/user/queue/game)

    public record MatchFound(String type, String matchId, List<PlayerInfo> players, int yourSeat) {
        public MatchFound(String matchId, List<PlayerInfo> players, int yourSeat) {
            this("MATCH_FOUND", matchId, players, yourSeat);
        }
    }

    public record ResumeState(String type, String matchId, String phase, int round, int currentSeat,
                              boolean finalRound, List<PlayerState> players, Map<String, List<BoardCellDto>> boards,
                              Map<String, CardDto> market, int deckRemaining, CardDto heldCard) {
        public ResumeState(String matchId, String phase, int round, int currentSeat, boolean finalRound,
                           List<PlayerState> players, Map<String, List<BoardCellDto>> boards,
                           Map<String, CardDto> market, int deckRemaining, CardDto heldCard) {
            this("RESUME_STATE", matchId, phase, round, currentSeat, finalRound, players, boards, market,
                    deckRemaining, heldCard);
        }
    }

    public record Error(String type, String code, String message) {
        public Error(String code, String message) {
            this("ERROR", code, message);
        }
    }

    // Match broadcast (/topic/match.{matchId})

    public record RoundStart(String type, int round, int startingSeat, boolean finalRound) {
        public RoundStart(int round, int startingSeat, boolean finalRound) {
            this("ROUND_START", round, startingSeat, finalRound);
        }
    }

    public record TurnStart(String type, String playerId, int seat) {
        public TurnStart(String playerId, int seat) {
            this("TURN_START", playerId, seat);
        }
    }

    public record CardPicked(String type, String playerId, String slot, CardDto card,
                             Map<String, CardDto> market, int deckRemaining) {
        public CardPicked(String playerId, String slot, CardDto card, Map<String, CardDto> market, int deckRemaining) {
            this("CARD_PICKED", playerId, slot, card, market, deckRemaining);
        }
    }

    public record CardRotated(String type, String playerId, String rotation) {
        public CardRotated(String playerId, String rotation) {
            this("CARD_ROTATED", playerId, rotation);
        }
    }

    public record CardPlaced(String type, String playerId, String corner, int x, int y, CardDto card) {
        public CardPlaced(String playerId, String corner, int x, int y, CardDto card) {
            this("CARD_PLACED", playerId, corner, x, y, card);
        }
    }

    public record StatsUpdated(String type, String playerId, Stats stats) {
        public StatsUpdated(String playerId, Stats stats) {
            this("STATS_UPDATED", playerId, stats);
        }
    }

    public record BattleAttack(String attackerId, String defenderId, int physicalDamage, int magicDamage, int totalDamage) {
    }

    public record BattleOutcome(String playerId, int hpBefore, int damageTaken, int healedHp, int hpAfter, boolean eliminated) {
    }

    public record BattleResult(String type, int round, List<BattleAttack> attacks, List<BattleOutcome> outcomes) {
        public BattleResult(int round, List<BattleAttack> attacks, List<BattleOutcome> outcomes) {
            this("BATTLE_RESULT", round, attacks, outcomes);
        }
    }

    public record PlayerEliminated(String type, String playerId, int finalHp) {
        public PlayerEliminated(String playerId, int finalHp) {
            this("PLAYER_ELIMINATED", playerId, finalHp);
        }
    }

    public record MatchResult(String type, List<String> winners, String reason) {
        public MatchResult(List<String> winners, String reason) {
            this("MATCH_RESULT", winners, reason);
        }
    }

    /** For PLAYER_DISCONNECTED and PLAYER_RECONNECTED. */
    public record PlayerNotice(String type, String playerId) {
    }
}
