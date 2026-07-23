import 'package:flutter/material.dart';

import '../../domain/models/stats.dart';
import '../assets/board_art.dart';
import '../theme/app_colors.dart';
import 'animated_number.dart';

/// This player's portrait (avatar photo with a gold border and four corner
/// badges: HP top-left, name top-right, potion bottom-left, coin
/// bottom-right) plus a 2x2 stat grid (PA/MA over PD/MD). Mirrors the web
/// client's PlayerHud.tsx + `.player-hud*`/`.stat-*` CSS. Stacked in a
/// column — this now lives in a narrow panel beside the board (symmetric to
/// the hand panel on the opposite side), not a wide bottom bar, so the
/// portrait is width-driven (AspectRatio picks its own height) with the
/// stat grid below it rather than beside it.
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
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Portrait(seat: seat, name: name, stats: stats),
        const SizedBox(height: 8),
        _StatGrid(stats: stats),
      ],
    );
  }
}

class _Portrait extends StatelessWidget {
  final int seat;
  final String name;
  final Stats stats;

  const _Portrait({
    required this.seat,
    required this.name,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      // Same 335/290 portrait proportion the web uses.
      aspectRatio: 335 / 290,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.woodDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gold, width: 4),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(avatarFor(seat), fit: BoxFit.cover),
            Positioned(
              top: 4,
              left: 4,
              child: _Badge(
                icon: BoardArt.hp,
                value: stats.hp,
                tooltip: 'Health',
              ),
            ),
            Positioned(
              bottom: 4,
              left: 4,
              child: _Badge(
                icon: BoardArt.pot,
                value: stats.hpp,
                tooltip: 'Healing potions',
              ),
            ),
            Positioned(
              bottom: 4,
              right: 4,
              child: _Badge(
                icon: BoardArt.coin,
                value: stats.cn,
                tooltip: 'Coins',
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 84),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0x99140A05),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  final Stats stats;

  const _StatGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    // Sizes to whatever width its parent (the side panel) gives it — no
    // fixed width of its own now that it sits in a narrow column instead of
    // a wide bottom bar.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: BoardArt.pa,
                value: stats.pa,
                tooltip: 'Physical attack',
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _StatTile(
                icon: BoardArt.ma,
                value: stats.ma,
                tooltip: 'Magic attack',
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: BoardArt.pd,
                value: stats.pd,
                tooltip: 'Physical defense',
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _StatTile(
                icon: BoardArt.md,
                value: stats.md,
                tooltip: 'Magic defense',
              ),
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
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: const Color(0xBF140A05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.gold),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(icon, width: 16, height: 16),
            const SizedBox(width: 3),
            AnimatedNumber(
              value: value,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textLight,
                fontWeight: FontWeight.w800,
              ),
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
    // Sized down from the original bottom-bar version (24px icon / 18px
    // digits) — each tile now only gets about half of the narrow side
    // panel's width, not a share of a wide bottom bar.
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.woodLight, AppColors.woodDark],
          ),
          border: Border.all(color: AppColors.iron, width: 2),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(icon, width: 18, height: 18),
            const SizedBox(width: 4),
            AnimatedNumber(
              value: value,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textLight,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
