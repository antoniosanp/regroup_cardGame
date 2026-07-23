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
        color: Colors.black87,
        padding: const EdgeInsets.all(12),
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
                  // Defenders: square cards, wrapped so they flow if needed.
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          runAlignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: ordered.map((p) {
                            return _DefenderCard(
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
          color: AppColors.iron,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.accent, width: a != null ? 2 : 1),
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
                  CircleAvatar(
                    radius: 26,
                    backgroundImage: AssetImage(avatarFor(a.seat)),
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

/// A defender, shown as a square-ish card: avatar + name on top, HP and the
/// defensive stats (PD/MD) below. Flashes when hit, dims + skull when dead,
/// gold border for you, wood border for the current attacker.
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
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 96,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
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
          ),
          child: Opacity(
            opacity: isDead ? 0.4 : 1,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top: avatar + name.
                CircleAvatar(
                  radius: 22,
                  backgroundImage: AssetImage(avatarFor(player.seat)),
                ),
                const SizedBox(height: 3),
                Text(
                  '${player.name}${isSelf ? ' (you)' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Divider(height: 8, thickness: 1, color: Colors.white24),
                // HP (prominent, animated).
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(BoardArt.hp, width: 15, height: 15),
                    const SizedBox(width: 3),
                    AnimatedNumber(
                      value: hp,
                      style: TextStyle(
                        color: hp <= 0 ? AppColors.bad : AppColors.textLight,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                // Bottom: defensive stats (PD/MD).
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _StatChip(icon: BoardArt.pd, value: player.stats.pd),
                    const SizedBox(width: 8),
                    _StatChip(icon: BoardArt.md, value: player.stats.md),
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
