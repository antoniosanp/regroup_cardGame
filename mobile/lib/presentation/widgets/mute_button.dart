import 'package:flutter/material.dart';

import '../../sfx/sfx.dart';

/// Small speaker toggle that mutes/unmutes all sound, persisted across
/// launches. Mirrors the web client's `.mute-toggle`. Rebuilds itself from
/// [Sfx]'s `muted` ValueNotifier.
class MuteButton extends StatelessWidget {
  final double size;

  const MuteButton({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: Sfx.instance.muted,
      builder: (context, muted, _) {
        return IconButton(
          onPressed: () => Sfx.instance.toggleMute(),
          tooltip: muted ? 'Unmute sound' : 'Mute sound',
          iconSize: size,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(
            muted ? Icons.volume_off : Icons.volume_up,
            color: const Color(0xFFF5EAD0),
            shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
          ),
        );
      },
    );
  }
}
