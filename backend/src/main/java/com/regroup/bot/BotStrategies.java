package com.regroup.bot;

import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.Set;
import java.util.function.Function;

/** Creates the per-match strategy instances for bot seats. */
public final class BotStrategies {

    private BotStrategies() {
    }

    /**
     * One fresh strategy per bot seat: the three personalities shuffled across the seats so every
     * offline game has variety (cycling if there are ever more than three bots).
     */
    public static Map<Integer, BotStrategy> assignPersonalities(Set<Integer> botSeats, Random rng) {
        List<Function<Random, BotStrategy>> pool = new ArrayList<>(List.<Function<Random, BotStrategy>>of(
                DefensiveBotStrategy::new, OffensiveBotStrategy::new, AdaptiveBotStrategy::new));
        Collections.shuffle(pool, rng);
        Map<Integer, BotStrategy> bySeat = new LinkedHashMap<>();
        int next = 0;
        for (int seat : botSeats) {
            bySeat.put(seat, pool.get(next++ % pool.size()).apply(rng));
        }
        return bySeat;
    }
}
