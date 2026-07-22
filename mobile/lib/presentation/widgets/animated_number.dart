import 'package:flutter/material.dart';

/// Small reusable tween: animates its displayed integer from whatever it was
/// previously showing to a new [value] over [duration]. Mirrors the web
/// client's AnimatedNumber.tsx, minus the color flash (kept out to limit
/// scope/risk here — see FE-06 notes; the counting animation itself is the
/// functional part players actually rely on to notice a stat changed).
class AnimatedNumber extends StatefulWidget {
  final int value;
  final TextStyle? style;
  final Duration duration;

  const AnimatedNumber({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 500),
  });

  @override
  State<AnimatedNumber> createState() => _AnimatedNumberState();
}

class _AnimatedNumberState extends State<AnimatedNumber> {
  int _previous = 0;

  @override
  void initState() {
    super.initState();
    _previous = widget.value;
  }

  @override
  void didUpdateWidget(covariant AnimatedNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    _previous = oldWidget.value;
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: _previous.toDouble(), end: widget.value.toDouble()),
      duration: widget.duration,
      builder: (context, value, child) {
        return Text(value.round().toString(), style: widget.style);
      },
    );
  }
}
