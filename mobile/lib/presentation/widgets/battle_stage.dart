import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/models/battle.dart';
import '../../domain/models/player.dart';
import '../../sfx/sfx.dart';
import '../../state/game_state.dart' show BattleVm;
import '../assets/board_art.dart';
import '../theme/app_colors.dart';
import 'animated_number.dart';

/// Full-screen battle-phase overlay: plays `BATTLE_RESULT.attacks[]` grouped
/// into per-attacker phases (consecutive same-attackerId rows, per
/// WS_CONTRACT.md's resolution order). The current attacker is shown as a card
/// on the left that lunges toward the target defender's card on each hit
/// (positions measured via GlobalKeys, like the web's BattleStage.tsx).
/// Defenders are compact square cards — avatar + name on top, HP and the
/// defensive stats (PD/MD) below. Purely presentational: every number comes
/// from the server's BATTLE_RESULT.
class BattleStage extends StatefulWidget {
  final BattleVm battle;
  final List<PlayerState> players;
  final String selfId;
  final VoidCallback? onFinished;

  const BattleStage({
    super.key,
    required this.battle,
    required this.players,
    required this.selfId,
    this.onFinished,
  });

  @override
  State<BattleStage> createState() => _BattleStageState();
}

class _Floater {
  final int id;
  final String playerId;
  final String text;
  final Color color;

  const _Floater({
    required this.id,
    required this.playerId,
    required this.text,
    required this.color,
  });
}

class _AttackerPhase {
  final String attackerId;
  final List<BattleAttack> attacks;

  const _AttackerPhase({required this.attackerId, required this.attacks});
}

List<_AttackerPhase> _groupByAttacker(List<BattleAttack> attacks) {
  final phases = <_AttackerPhase>[];
  for (final a in attacks) {
    if (phases.isNotEmpty && phases.last.attackerId == a.attackerId) {
      phases.last.attacks.add(a);
    } else {
      phases.add(_AttackerPhase(attackerId: a.attackerId, attacks: [a]));
    }
  }
  return phases;
}

class _BattleStageState extends State<BattleStage>
    with SingleTickerProviderStateMixin {
  final Map<String, int> _shownHp = {};
  final Set<String> _deadIds = {};
  final List<_Floater> _floaters = [];
  final _random = Random();
  String? _activeAttackerId;
  String? _highlightDefenderId;
  bool _finished = false;
  bool _skipped = false;
  bool _playedFinishSound = false;
  int _floaterId = 0;
  Timer? _pendingStep;

  // Lunge: the attacker card translates by `_lungeOffset * controller.value`
  // toward the target defender, measured via these GlobalKeys.
  late final AnimationController _lungeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  Offset _lungeOffset = Offset.zero;
  final GlobalKey _attackerKey = GlobalKey();
  final Map<String, GlobalKey> _defenderKeys = {};

  GlobalKey _keyFor(String playerId) =>
      _defenderKeys.putIfAbsent(playerId, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    _shownHp.addEntries(
      widget.battle.outcomes.map((o) => MapEntry(o.playerId, o.hpBefore)),
    );
    _runSequence();
  }

  @override
  void dispose() {
    _pendingStep?.cancel();
    _lungeController.dispose();
    super.dispose();
  }

  Future<void> _sleep(int ms) {
    final completer = Completer<void>();
    _pendingStep?.cancel();
    _pendingStep = Timer(Duration(milliseconds: ms), () {
      if (mounted) completer.complete();
    });
    return completer.future;
  }

  bool get _active => mounted && !_skipped;

  /// Sets `_lungeOffset` to half the vector from the attacker's centre to the
  /// target defender's centre (both global), so the attacker visibly lunges
  /// partway toward whoever it's hitting.
  void _computeLunge(String defenderId) {
    final aObj = _attackerKey.currentContext?.findRenderObject();
    final dObj = _defenderKeys[defenderId]?.currentContext?.findRenderObject();
    if (aObj is! RenderBox ||
        dObj is! RenderBox ||
        !aObj.attached ||
        !dObj.attached) {
      _lungeOffset = Offset.zero;
      return;
    }
    final aCenter = aObj.localToGlobal(aObj.size.center(Offset.zero));
    final dCenter = dObj.localToGlobal(dObj.size.center(Offset.zero));
    _lungeOffset = (dCenter - aCenter) * 0.5;
  }

  Future<void> _runSequence() async {
    playSfx(SfxName.battleStart);
    final phases = _groupByAttacker(widget.battle.attacks);

    for (final phase in phases) {
      if (!_active) break;
      setState(() => _activeAttackerId = phase.attackerId);
      playSfx(SfxName.attackerStep);
      // Let the attacker card mount/lay out before measuring lunge targets.
      await _sleep(350);
      if (!_active) break;

      for (final attack in phase.attacks) {
        if (!_active) break;
        setState(() => _highlightDefenderId = attack.defenderId);
        playSfx(SfxName.attackLunge);

        // Lunge toward the target, then land the hit at the peak.
        _computeLunge(attack.defenderId);
        if (_lungeOffset != Offset.zero) {
          await _lungeController.forward(from: 0);
        } else {
          await _sleep(200);
        }
        if (!_active) break;

        final blocked = attack.totalDamage <= 0;
        if (blocked) {
          playSfx(SfxName.hitBlocked);
        } else {
          // ~1 in 8 hits gets the comedy chicken variant (SOUNDS.md); pitch
          // varied so repeated hits don't sound cloned.
          final chicken = _random.nextInt(8) == 0;
          playSfx(
            chicken ? SfxName.hitImpactChicken : SfxName.hitImpact,
            pitchVariance: 0.1,
          );
          playSfx(SfxName.hpTick);
        }
        _addFloater(
          attack.defenderId,
          blocked ? '0' : '-${attack.totalDamage}',
          blocked ? AppColors.muted : AppColors.bad,
        );
        if (!blocked) {
          setState(() {
            _shownHp[attack.defenderId] =
                (_shownHp[attack.defenderId] ?? 0) - attack.totalDamage;
          });
        }

        // Retreat.
        if (_lungeController.value > 0) {
          await _lungeController.reverse();
        }
        await _sleep(160);
        if (!mounted) return;
        setState(() => _highlightDefenderId = null);
        await _sleep(120);
      }
    }

    if (!mounted) return;
    setState(() => _activeAttackerId = null);

    if (_skipped) {
      _finishInstantly();
      return;
    }

    final healed = widget.battle.outcomes.where(
      (o) => o.healedHp > 0 && !o.eliminated,
    );
    for (final o in healed) {
      _addFloater(o.playerId, '+${o.healedHp}', AppColors.good);
      playSfx(SfxName.heal);
    }
    setState(() {
      for (final o in widget.battle.outcomes) {
        _shownHp[o.playerId] = o.hpAfter;
      }
    });
    if (healed.isNotEmpty && _active) await _sleep(700);
    if (!mounted) return;

    final eliminatedNow = widget.battle.outcomes
        .where((o) => o.eliminated)
        .map((o) => o.playerId)
        .toList();
    setState(() => _deadIds.addAll(eliminatedNow));
    for (final _ in eliminatedNow) {
      playSfx(SfxName.eliminated);
    }
    if (eliminatedNow.isNotEmpty && _active) await _sleep(600);
    if (!mounted) return;

    setState(() => _finished = true);
    playSfx(SfxName.battleEnd);
    widget.onFinished?.call();
  }

  void _finishInstantly() {
    final eliminatedNow = widget.battle.outcomes
        .where((o) => o.eliminated)
        .map((o) => o.playerId)
        .toList();
    setState(() {
      for (final o in widget.battle.outcomes) {
        _shownHp[o.playerId] = o.hpAfter;
      }
      _deadIds.addAll(eliminatedNow);
      _activeAttackerId = null;
      _highlightDefenderId = null;
      _finished = true;
    });
    _lungeController.value = 0;
    // The finish sounds must play exactly once even though _finishInstantly can
    // be reached both from the Skip button and the skipped async path.
    if (!_playedFinishSound) {
      _playedFinishSound = true;
      for (final _ in eliminatedNow) {
        playSfx(SfxName.eliminated);
      }
      playSfx(SfxName.battleEnd);
    }
    widget.onFinished?.call();
  }

  void _addFloater(String playerId, String text, Color color) {
    final id = ++_floaterId;
    setState(
      () => _floaters.add(
        _Floater(id: id, playerId: playerId, text: text, color: color),
      ),
    );
    Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _floaters.removeWhere((f) => f.id == id));
    });
  }

  @override
  Widget build(BuildContext context) {
    final ordered = [...widget.players]
      ..sort((a, b) => a.seat.compareTo(b.seat));
    final attacker = ordered
        .where((p) => p.playerId == _activeAttackerId)
        .firstOrNull;

    return Positioned.fill(
      child: Container(
        // Matches the web's dark wood-brown scrim (rgba(15,9,5,.94)) rather
        // than a plain black overlay.
        color: const Color(0xF00F0905),
        padding: const EdgeInsets.all(12),
        // Forces every Text in this overlay to render without a decoration
        // (feedback: names/numbers were showing a stray underline during the
        // battle phase). No TextStyle in this file — or anywhere else in the
        // app — sets an underline explicitly, so this is a defensive reset
        // in case it's being inherited from somewhere upstream.
        child: DefaultTextStyle.merge(
          style: const TextStyle(decoration: TextDecoration.none),
          child: Column(
            children: [
              Text(
                'Battle — round ${widget.battle.round}',
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Attacker card (left), lunging toward the target on each hit.
                    SizedBox(
                      width: 132,
                      child: Center(
                        child: AnimatedBuilder(
                          animation: _lungeController,
                          builder: (context, child) => Transform.translate(
                            offset: _lungeOffset * _lungeController.value,
                            child: child,
                          ),
                          child: _AttackerCard(
                            key: _attackerKey,
                            attacker: attacker,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Defenders: a fixed vertical column, one row per player —
                    // mirrors the web's `.battle-defenders` (a stable per-player
                    // slot that never reflows), not a row/Wrap. Scrollable so
                    // 4 tall cards on a short landscape screen never overflow.
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final p in ordered) ...[
                                _DefenderCard(
                                  key: _keyFor(p.playerId),
                                  player: p,
                                  isAttacking: p.playerId == _activeAttackerId,
                                  isHit: p.playerId == _highlightDefenderId,
                                  isDead: _deadIds.contains(p.playerId),
                                  isSelf: p.playerId == widget.selfId,
                                  hp: _shownHp[p.playerId] ?? p.stats.hp,
                                  floaters: _floaters
                                      .where((f) => f.playerId == p.playerId)
                                      .toList(),
                                ),
                                if (p != ordered.last)
                                  const SizedBox(height: 8),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!_finished && widget.battle.attacks.isNotEmpty)
                TextButton(
                  onPressed: () {
                    playSfx(SfxName.battleSkip);
                    _skipped = true;
                    _finishInstantly();
                  },
                  child: const Text(
                    'Skip animation',
                    style: TextStyle(color: AppColors.textLight, fontSize: 12),
                  ),
                ),
              if (_finished)
                const Text(
                  'Next round…',
                  style: TextStyle(color: AppColors.muted, fontSize: 11),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The current attacker, shown as a card: avatar + name on top, its offensive
/// stats (PA/MA) below — these are what determine the damage it deals.
class _AttackerCard extends StatelessWidget {
  final PlayerState? attacker;

  const _AttackerCard({super.key, required this.attacker});

  @override
  Widget build(BuildContext context) {
    final a = attacker;
    return AnimatedScale(
      duration: const Duration(milliseconds: 200),
      scale: a != null ? 1.06 : 1,
      child: Container(
        width: 118,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          // Wood gradient + gold border, matching the web's
          // .battle-attacker tile instead of a flat iron box.
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.woodLight, AppColors.woodDark],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gold, width: a != null ? 3 : 1),
        ),
        child: a == null
            ? const SizedBox(
                height: 96,
                child: Center(
                  child: Text(
                    '···',
                    style: TextStyle(color: AppColors.muted, fontSize: 24),
                  ),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Squared, rounded-corner portrait (web uses
                  // border-radius:10px, not a circle) — same pattern as
                  // PlayerHud's portrait.
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.iron, width: 2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(avatarFor(a.seat), fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    a.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _StatChip(icon: BoardArt.pa, value: a.stats.pa),
                      const SizedBox(width: 8),
                      _StatChip(icon: BoardArt.ma, value: a.stats.ma),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

/// A defender, shown as a wide-short card: avatar on the left, name/HP/PD/MD
/// stacked to its *right* (not below it) — keeping stats beside the avatar
/// instead of underneath is what keeps each row short, so a column of 4 of
/// these never runs off a short landscape screen (feedback: the old
/// everything-stacked-vertically layout could push the roster off-screen).
/// Flashes when hit, dims + skull when dead, gold border for you, wood
/// border for the current attacker.
class _DefenderCard extends StatelessWidget {
  final PlayerState player;
  final bool isAttacking;
  final bool isHit;
  final bool isDead;
  final bool isSelf;
  final int hp;
  final List<_Floater> floaters;

  const _DefenderCard({
    super.key,
    required this.player,
    required this.isAttacking,
    required this.isHit,
    required this.isDead,
    required this.isSelf,
    required this.hp,
    required this.floaters,
  });

  @override
  Widget build(BuildContext context) {
    // A square, rounded-corner portrait (web's .battle-defender-avatar is
    // border-radius:9px, not a circle) — desaturated when eliminated, same
    // spirit as the web's grayscale(0.85) filter on dead rows. The skull for
    // "dead" is a small badge pinned to its corner (same pattern as the
    // first-mover badge in PlayerOrderRow) instead of its own text line
    // below, since stats no longer have a "below the avatar" area to put it in.
    Widget avatarImage = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.iron, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(avatarFor(player.seat), fit: BoxFit.cover),
    );
    if (isDead) {
      avatarImage = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        child: avatarImage,
      );
    }
    final avatar = Stack(
      clipBehavior: Clip.none,
      children: [
        avatarImage,
        if (isDead)
          const Positioned(
            top: -4,
            right: -4,
            child: Text('💀', style: TextStyle(fontSize: 12)),
          ),
      ],
    );

    Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 172,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: isHit
            ? AppColors.accent.withValues(alpha: 0.65)
            : isAttacking
            ? AppColors.wood.withValues(alpha: 0.4)
            : AppColors.iron,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelf ? AppColors.gold : AppColors.woodDark,
          width: isSelf ? 2 : 1,
        ),
        // Red glow ring on the hit row, mirroring the web's
        // `box-shadow: 0 0 0 2px var(--bad)` on .battle-row-hit.
        boxShadow: isHit
            ? [
                BoxShadow(
                  color: AppColors.bad.withValues(alpha: 0.8),
                  blurRadius: 6,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Opacity(
        opacity: isDead ? 0.4 : 1,
        // Avatar on the left, everything else stacked *beside* it — keeping
        // stats to the right instead of below is what keeps this row short.
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            avatar,
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${player.name}${isSelf ? ' (you)' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textLight,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isAttacking)
                        const Text(
                          'ATK',
                          style: TextStyle(
                            color: AppColors.warn,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(BoardArt.hp, width: 14, height: 14),
                      const SizedBox(width: 3),
                      AnimatedNumber(
                        value: hp,
                        style: TextStyle(
                          color: hp <= 0 ? AppColors.bad : AppColors.textLight,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatChip(icon: BoardArt.pd, value: player.stats.pd),
                      const SizedBox(width: 6),
                      _StatChip(icon: BoardArt.md, value: player.stats.md),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (isAttacking) {
      // Dashed outline, mirroring the web's `.battle-row-attacking`
      // (border-style: dashed) marker on the current attacker's own roster
      // entry — additive to whatever solid border/tint the card already has.
      card = CustomPaint(
        foregroundPainter: _DashedRRectPainter(
          color: AppColors.gold,
          borderRadius: BorderRadius.circular(10),
        ),
        child: card,
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        card,
        // Damage / heal floaters, rising and fading above the card.
        ...floaters.map(
          (f) => Positioned(
            top: -10,
            child: TweenAnimationBuilder<double>(
              key: ValueKey(f.id),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              builder: (context, t, child) => Opacity(
                opacity: 1 - t,
                child: Transform.translate(
                  offset: Offset(0, -24 * t),
                  child: child,
                ),
              ),
              child: Text(
                f.text,
                style: TextStyle(
                  color: f.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Lightweight dashed rounded-rect outline — no external package needed for
/// this one polish detail (P2 in the mobile/web visual-parity plan).
class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final BorderRadius borderRadius;

  const _DashedRRectPainter({required this.color, required this.borderRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = borderRadius.toRRect(Offset.zero & size);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const dashWidth = 4.0;
    const dashGap = 3.0;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.borderRadius != borderRadius;
}

class _StatChip extends StatelessWidget {
  final String icon;
  final int value;

  const _StatChip({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(icon, width: 14, height: 14),
        const SizedBox(width: 2),
        Text(
          '$value',
          style: const TextStyle(
            color: AppColors.textLight,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
