package com.regroup.bot;

/** Every tunable magic number of the bot personalities in one place (botAIplan.md section 4). */
public final class BotTuning {

    /** Per-stat multipliers applied to a candidate move's stat delta. */
    public record Weights(double pa, double pd, double ma, double md, double cn, double hpp) {
        public double dot(MoveEvaluator.StatVector v) {
            return pa * v.pa() + pd * v.pd() + ma * v.ma() + md * v.md() + cn * v.cn() + hpp * v.hpp();
        }
    }

    /** Chance per turn that Defensive/Offensive play their archetype profile instead of the neutral one. */
    public static final double PRIMARY_PROFILE_PROBABILITY = 0.7;

    /** The defensive bot's tolerated |pd - md| imbalance; rule allows tuning within 1..3. */
    public static final int MAX_DEFENSE_GAP = 2;

    /** Score penalty for a move that leaves |pd - md| beyond the gap. */
    public static final double DEFENSE_GAP_PENALTY = 5.0;

    /** Extra weight on whichever defense stat currently lags, so the defensive bot closes the gap. */
    public static final double LAGGING_DEFENSE_BOOST = 1.5;

    /** Extra weight on whichever attack stat is already stronger — adjacency rewards concentration. */
    public static final double STRONGER_ATTACK_BOOST = 1.0;

    /** An opponent attack stat at or above this makes the adaptive bot prioritize the matching defense. */
    public static final int THREAT_THRESHOLD = 3;

    /** Random weight wobble so several adaptive bots in one match don't play identically. */
    public static final double ADAPTIVE_JITTER = 0.10;

    /** Score penalty per coin of a slot's price; coins cap at 2 and partly reappear at recalc, so keep this <= 1.0. */
    public static final double COIN_COST_PENALTY = 0.75;

    /** Expected score of an unknown deck card; the deck wins when the visible cards fit the personality badly. */
    public static final double DECK_EXPECTED_VALUE = 2.0;

    public static final Weights NEUTRAL = new Weights(1, 1, 1, 1, 1, 1);
    public static final Weights DEFENSIVE = new Weights(0.5, 3, 0.5, 3, 0.5, 1);
    public static final Weights OFFENSIVE = new Weights(3, 0.5, 3, 0.5, 0.5, 0.5);

    private BotTuning() {
    }
}
