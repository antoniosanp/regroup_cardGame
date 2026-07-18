package com.regroup.engine;

import java.awt.Point;
import java.util.Map;

public class CombatEngine {

    public void calculateStats(Board board, Player player) {
        int coins = 0;
        int healthPotions = 0;
        int physicalAttack = 0;
        int physicalDefense = 0;
        int magicAttack = 0;
        int magicDefense = 0;

        for (Map.Entry<Point, BoardCell> entry : board.cells().entrySet()) {
            CornerAttribute attribute = entry.getValue().attribute();
            coins += attribute.coins();
            healthPotions += attribute.hpp();

            if (attribute.category() == StatCategory.NONE) {
                continue;
            }
            if (hasMatchingNeighbor(board, entry.getKey(), attribute.category())) {
                physicalAttack += attribute.pa();
                physicalDefense += attribute.pd();
                magicAttack += attribute.ma();
                magicDefense += attribute.md();
            }
        }

        player.setCn(coins);
        player.setHpp(healthPotions);
        player.setPa(physicalAttack);
        player.setPd(physicalDefense);
        player.setMa(magicAttack);
        player.setMd(magicDefense);
    }

    private boolean hasMatchingNeighbor(Board board, Point point, StatCategory category) {
        Point[] neighbors = {
                new Point(point.x + 1, point.y),
                new Point(point.x - 1, point.y),
                new Point(point.x, point.y + 1),
                new Point(point.x, point.y - 1),
        };
        for (Point neighbor : neighbors) {
            BoardCell neighborCell = board.at(neighbor);
            if (neighborCell != null && neighborCell.attribute().category() == category) {
                return true;
            }
        }
        return false;
    }

    public int calculateDamage(Player attacker, Player defender) {
        int physicalDamage = Math.max(attacker.pa() - defender.pd(), 0);
        int magicDamage = Math.max(attacker.ma() - defender.md(), 0);
        return physicalDamage + magicDamage;
    }
}
