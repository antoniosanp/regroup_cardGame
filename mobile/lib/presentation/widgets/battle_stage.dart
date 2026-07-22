import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/models/battle.dart';
import '../../domain/models/player.dart';
import '../../state/game_state.dart' show BattleVm;
import '../assets/board_art.dart';
import '../theme/app_colors.dart';
import 'animated_number.dart';

/// Full-screen battle-phase overlay: plays `BATTLE_RESULT.attacks[]` grouped
/// into per-attacker phases (consecutive same-attackerId rows, per
/// WS_CONTRACT.md's resolution-order description). Simplified port of the
/// web client's BattleStage.tsx — that version measures DOM rects to fly a
/// lunge animation and floating damage numbers to exact pixel positions;
/// here each hit instead highlights the attacker and defender in place and
/// pops a "-N"/"+N" floater directly over the defender's own row, which
/// needs no cross-widget position measuring and is easier to get right
/// without being able to run this interactively. Purely presentational:
/// every number comes from the server's BATTLE_RESULT; this never computes
/// game rules.
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

class _BattleStageState extends State<BattleStage> {
  final Map<String, int> _shownHp = {};
  final Set<String> _deadIds = {};
  final List<_Floater> _floaters = [];
  String? _activeAttackerId;
  String? _highlightDefenderId;
  bool _finished = false;
  bool _skipped = false;
  int _floaterId = 0;
  Timer? _pendingStep;

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

  Future<void> _runSequence() async {
    final phases = _groupByAttacker(widget.battle.attacks);

    for (final phase in phases) {
      if (!_active) break;
      setState(() => _activeAttackerId = phase.attackerId);
      await _sleep(350);
      if (!_active) break;

      for (final attack in phase.attacks) {
        if (!_active) break;
        setState(() => _highlightDefenderId = attack.defenderId);

        final blocked = attack.totalDamage <= 0;
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
        await _sleep(500);
        if (!mounted) return;
        setState(() => _highlightDefenderId = null);
        await _sleep(220);
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
        .map((o) => o.playerId);
    setState(() => _deadIds.addAll(eliminatedNow));
    if (eliminatedNow.isNotEmpty && _active) await _sleep(600);
    if (!mounted) return;

    setState(() => _finished = true);
    widget.onFinished?.call();
  }

  void _finishInstantly() {
    setState(() {
      for (final o in widget.battle.outcomes) {
        _shownHp[o.playerId] = o.hpAfter;
      }
      _deadIds.addAll(
        widget.battle.outcomes
            .where((o) => o.eliminated)
            .map((o) => o.playerId),
      );
      _activeAttackerId = null;
      _highlightDefenderId = null;
      _finished = true;
    });
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
        color: Colors.black87,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Battle — round ${widget.battle.round}',
              style: const TextStyle(
                color: AppColors.textLight,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            // Attacker square on the left; the defenders are a row of squares
            // on the right (not full-width rows — that was the feedback), each
            // the same compact card shape as the attacker.
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 150,
                    child: Center(child: _AttackerPane(attacker: attacker)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: ordered.map((p) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: _DefenderSquare(
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
                            );
                          }).toList(),
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
                  _skipped = true;
                  _finishInstantly();
                },
                child: const Text(
                  'Skip animation',
                  style: TextStyle(color: AppColors.textLight),
                ),
              ),
            if (_finished)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Next round starts automatically…',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AttackerPane extends StatelessWidget {
  final PlayerState? attacker;

  const _AttackerPane({required this.attacker});

  @override
  Widget build(BuildContext context) {
    final a = attacker;
    return AnimatedScale(
      duration: const Duration(milliseconds: 200),
      scale: a != null ? 1.08 : 1,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.iron,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.accent, width: a != null ? 2 : 0),
        ),
        child: a == null
            ? const Center(
                child: Text(
                  '···',
                  style: TextStyle(color: AppColors.muted, fontSize: 24),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundImage: AssetImage(avatarFor(a.seat)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    a.name,
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(BoardArt.pa, width: 14, height: 14),
                      Text(
                        ' ${a.stats.pa}  ',
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 11,
                        ),
                      ),
                      Image.asset(BoardArt.ma, width: 14, height: 14),
                      Text(
                        ' ${a.stats.ma}',
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

/// A single defender rendered as a compact square card (avatar + name + HP +
/// PD/MD), matching the attacker pane's shape — the feedback was that
/// defenders shouldn't be full-width rows.
class _DefenderSquare extends StatelessWidget {
  final PlayerState player;
  final bool isAttacking;
  final bool isHit;
  final bool isDead;
  final bool isSelf;
  final int hp;
  final List<_Floater> floaters;

  const _DefenderSquare({
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
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 108,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isHit
                ? AppColors.accent.withValues(alpha: 0.6)
                : isAttacking
                ? AppColors.wood.withValues(alpha: 0.4)
                : AppColors.iron,
            borderRadius: BorderRadius.circular(10),
            border: isSelf
                ? Border.all(color: AppColors.gold, width: 2)
                : Border.all(color: AppColors.woodDark, width: 1),
          ),
          child: Opacity(
            opacity: isDead ? 0.4 : 1,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundImage: AssetImage(avatarFor(player.seat)),
                ),
                const SizedBox(height: 6),
                Text(
                  '${player.name}${isSelf ? ' (you)' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(BoardArt.hp, width: 15, height: 15),
                    const SizedBox(width: 2),
                    AnimatedNumber(
                      value: hp,
                      style: TextStyle(
                        color: hp <= 0 ? AppColors.bad : AppColors.textLight,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(BoardArt.pd, width: 12, height: 12),
                    Text(
                      ' ${player.stats.pd}  ',
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontSize: 10,
                      ),
                    ),
                    Image.asset(BoardArt.md, width: 12, height: 12),
                    Text(
                      ' ${player.stats.md}',
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                if (isDead)
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text('💀'),
                  ),
                if (isAttacking)
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text(
                      'attacking',
                      style: TextStyle(color: AppColors.warn, fontSize: 10),
                    ),
                  ),
              ],
            ),
          ),
        ),
        ...floaters.map(
          (f) => Positioned(
            top: -10,
            child: TweenAnimationBuilder<double>(
              key: ValueKey(f.id),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              builder: (context, t, child) {
                return Opacity(
                  opacity: 1 - t,
                  child: Transform.translate(
                    offset: Offset(0, -24 * t),
                    child: child,
                  ),
                );
              },
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

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
