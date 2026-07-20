package com.regroup.engine;

import java.util.List;

/** The outcome of one round's all-vs-all battle: every attacker to defender damage instance, plus each player's net hp change. */
public record BattleResult(int round, List<Attack> attacks, List<Outcome> outcomes) {

    /** One attacker to defender damage instance, computed from the shared pre-battle stat snapshot. */
    public record Attack(int attackerSeat, int defenderSeat, int physicalDamage, int magicDamage, int totalDamage) {
    }

    /** A player's net result for the round: damage taken from the snapshot, healing applied if they survived, final hp, elimination. */
    public record Outcome(int seat, int hpBefore, int damageTaken, int healedHp, int hpAfter, boolean eliminated) {
    }
}
