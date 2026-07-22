import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/models/phase.dart';

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
      setState(() {
        if (_secondsLeft > 0) _secondsLeft--;
      });
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

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = low ? _pulseController.value : 0.0;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: yours ? Colors.amber.withValues(alpha: 0.2) : Colors.black26,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: low
                  ? Color.lerp(Colors.redAccent, Colors.red.shade900, pulse)!
                  : Colors.white24,
              width: low ? 1 + pulse : 1,
            ),
          ),
          child: child,
        );
      },
      child: Semantics(
        label: inTurn ? 'Turn timer: $mm minutes $ss seconds, $label' : label,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              inTurn ? '$mm:${ss.toString().padLeft(2, '0')}' : '--:--',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: low ? Colors.redAccent : Colors.white,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
