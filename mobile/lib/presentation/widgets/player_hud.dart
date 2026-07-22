import 'package:flutter/material.dart';

import '../../domain/models/stats.dart';
import '../assets/board_art.dart';
import '../theme/app_colors.dart';
import 'animated_number.dart';

/// This player's portrait + hp/potion/coin badges, plus the PA/MA/PD/MD stat
/// grid. Mirrors the web client's PlayerHud.tsx.
class PlayerHud extends StatelessWidget {
  final int seat;
  final String name;
  final Stats stats;

  const PlayerHud({
    super.key,
    required this.seat,
    required this.name,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage: AssetImage(avatarFor(seat)),
            ),
            Positioned(
              bottom: -10,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Badge(icon: BoardArt.hp, value: stats.hp, tooltip: 'Health'),
                  const SizedBox(width: 4),
                  _Badge(
                    icon: BoardArt.pot,
                    value: stats.hpp,
                    tooltip: 'Healing potions',
                  ),
                  const SizedBox(width: 4),
                  _Badge(
                    icon: BoardArt.coin,
                    value: stats.cn,
                    tooltip: 'Coins',
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          name,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.text,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: 2.2,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _StatTile(
              icon: BoardArt.pa,
              value: stats.pa,
              tooltip: 'Physical attack',
            ),
            _StatTile(
              icon: BoardArt.ma,
              value: stats.ma,
              tooltip: 'Magic attack',
            ),
            _StatTile(
              icon: BoardArt.pd,
              value: stats.pd,
              tooltip: 'Physical defense',
            ),
            _StatTile(
              icon: BoardArt.md,
              value: stats.md,
              tooltip: 'Magic defense',
            ),
          ],
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String icon;
  final int value;
  final String tooltip;

  const _Badge({
    required this.icon,
    required this.value,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(icon, width: 14, height: 14),
            const SizedBox(width: 3),
            AnimatedNumber(
              value: value,
              style: const TextStyle(fontSize: 11, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String icon;
  final int value;
  final String tooltip;

  const _StatTile({
    required this.icon,
    required this.value,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(icon, width: 16, height: 16),
            const SizedBox(width: 4),
            AnimatedNumber(
              value: value,
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
