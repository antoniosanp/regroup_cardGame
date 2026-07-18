package com.regroup.engine;

/** One row per symbol in gameRules.md's corner property table. */
public enum CornerAttribute {
    EMPTY(StatCategory.NONE, 0, 0, 0, 0, 0, 0),
    HP_POTION_COIN(StatCategory.NONE, 1, 1, 0, 0, 0, 0),
    COINS_2(StatCategory.NONE, 0, 2, 0, 0, 0, 0),
    PA_1(StatCategory.PA, 0, 0, 1, 0, 0, 0),
    PA_2(StatCategory.PA, 0, 0, 2, 0, 0, 0),
    PD_1(StatCategory.PD, 0, 0, 0, 1, 0, 0),
    PD_2(StatCategory.PD, 0, 0, 0, 2, 0, 0),
    MA_1(StatCategory.MA, 0, 0, 0, 0, 1, 0),
    MA_2(StatCategory.MA, 0, 0, 0, 0, 2, 0),
    MD_1(StatCategory.MD, 0, 0, 0, 0, 0, 1),
    MD_2(StatCategory.MD, 0, 0, 0, 0, 0, 2);

    private final StatCategory category;
    private final int hpp;
    private final int coins;
    private final int pa;
    private final int pd;
    private final int ma;
    private final int md;

    CornerAttribute(StatCategory category, int hpp, int coins, int pa, int pd, int ma, int md) {
        this.category = category;
        this.hpp = hpp;
        this.coins = coins;
        this.pa = pa;
        this.pd = pd;
        this.ma = ma;
        this.md = md;
    }

    public StatCategory category() {
        return category;
    }

    public int hpp() {
        return hpp;
    }

    public int coins() {
        return coins;
    }

    public int pa() {
        return pa;
    }

    public int pd() {
        return pd;
    }

    public int ma() {
        return ma;
    }

    public int md() {
        return md;
    }
}
