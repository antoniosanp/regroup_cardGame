import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/models/phase.dart';
import '../../sfx/sfx.dart';
import '../assets/board_art.dart';
import '../theme/app_colors.dart';

const int _turnSeconds = 60;

/// Client-side cosmetic countdown for the 60s turn cap documented in
/// WS_CONTRACT.md. The server never sends a deadline/timestamp on the wire,
/// so this can only approximate: it resets to 60s whenever a new turn begins
/// (round/currentSeat/phase changes) and ticks down locally. The real
/// enforcement (auto-play on expiry) stays entirely server-side; this is
/// display only, never authoritative. Mirrors the web client's TurnTimer.tsx.
class TurnTimer extends StatefulWidget {
  final Phase phase;
  final int round;
  final int currentSeat;
  final String? currentName;
  final bool isYourTurn;

  const TurnTimer({
    super.key,
    required this.phase,
    required this.round,
    required this.currentSeat,
    required this.isYourTurn,
    this.currentName,
  });

  @override
  State<TurnTimer> createState() => _TurnTimerState();
}

class _TurnTimerState extends State<TurnTimer>
    with SingleTickerProviderStateMixin {
  int _secondsLeft = _turnSeconds;
  Timer? _ticker;
  // FE-14: pulses the border while the timer is low, so the last seconds of
  // a turn are impossible to miss out of the corner of an eye.
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(covariant TurnTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Bright chime the moment it becomes your turn (mirrors TurnTimer.tsx).
    if (widget.isYourTurn &&
        !oldWidget.isYourTurn &&
        widget.phase == Phase.turn) {
      playSfx(SfxName.turnYours);
    }
    if (oldWidget.round != widget.round ||
        oldWidget.currentSeat != widget.currentSeat ||
        oldWidget.phase != widget.phase) {
      _restart();
    }
  }

  void _restart() {
    _ticker?.cancel();
    setState(() => _secondsLeft = _turnSeconds);
    if (widget.phase != Phase.turn) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final before = _secondsLeft;
      setState(() {
        if (_secondsLeft > 0) _secondsLeft--;
      });
      // Ticks only for your own turn's countdown; the expired toll fires the
      // single second it crosses 0 (not repeatedly while parked at 0), same
      // as the web's TurnTimer.
      if (widget.isYourTurn) {
        if (_secondsLeft > 0 && _secondsLeft <= 10) {
          playSfx(SfxName.timerLowTick);
        } else if (_secondsLeft == 0 && before > 0) {
          playSfx(SfxName.timerExpired);
        }
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inTurn = widget.phase == Phase.turn;
    final low = inTurn && _secondsLeft <= 10;
    final yours = inTurn && widget.isYourTurn;
    final mm = _secondsLeft ~/ 60;
    final ss = _secondsLeft % 60;

    // Once this cosmetic clock hits zero, the server's real 60s timeout is
    // about to (or already did) auto-play this seat's turn — see
    // WS_CONTRACT.md's disconnection/timeout section. This is display only:
    // deliberately NOT used to disable pick/place buttons elsewhere, since
    // this client-side clock is only an approximation and could be briefly
    // wrong relative to the server's actual deadline — disabling real
    // actions on an imprecise local guess risks blocking a still-legal move
    // in the last second. The server remains the only real enforcement.
    final label = !inTurn
        ? (widget.phase == Phase.battle ? 'Battle' : '')
        : widget.isYourTurn
        ? (_secondsLeft == 0 ? 'Auto-placing…' : 'Your turn!')
        : (widget.currentName ?? 'Waiting…');

    // Square plaque backed by panelSquare.png, mirroring the web's
    // .turn-timer (a --topbox-size square). A low-timer pulse tints the value.
    return AspectRatio(
      aspectRatio: 1,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final pulse = low ? _pulseController.value : 0.0;
          return Container(
            decoration: BoxDecoration(
              image: const DecorationImage(
                image: AssetImage(BoardArt.panelSquare),
                fit: BoxFit.fill,
              ),
              borderRadius: BorderRadius.circular(8),
              border: low
                  ? Border.all(
                      color: Color.lerp(
                        AppColors.bad,
                        Colors.red.shade900,
                        pulse,
                      )!,
                      width: 1 + pulse * 2,
                    )
                  : null,
            ),
            child: child,
          );
        },
        child: Semantics(
          label: inTurn ? 'Turn timer: $mm minutes $ss seconds, $label' : label,
          // One FittedBox around the whole stack scales it to fit the square
          // at any size — no per-child overflow.
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    inTurn ? '$mm:${ss.toString().padLeft(2, '0')}' : '--:--',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: low ? AppColors.bad : AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: yours ? FontWeight.w800 : FontWeight.w600,
                      color: yours ? AppColors.wood : AppColors.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
