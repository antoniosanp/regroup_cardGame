package com.regroup.engine;

/** Groups corner attributes so adjacency matching can compare "same kind of stat" regardless of value (1pa vs 2pa). */
public enum StatCategory {
    NONE,
    PA,
    PD,
    MA,
    MD
}
