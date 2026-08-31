import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/audio_service.dart';

/// A one-tap master audio control for gameplay HUDs.
///
/// The underlying preference already controls both the shared music bed and
/// every sound effect, so this remains in sync with the switch in Settings.
class QuickMuteButton extends StatelessWidget {
  const QuickMuteButton({super.key, required this.audio, this.compact = false});

  final AudioService audio;
  final bool compact;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: audio,
    builder: (context, _) {
      final muted = audio.muted;
      return IconButton(
        onPressed: () => unawaited(audio.setMuted(!muted)),
        icon: Icon(
          muted ? Icons.volume_off : Icons.volume_up,
          color: muted ? Colors.orangeAccent : Colors.white70,
        ),
        iconSize: compact ? 20 : 24,
        padding: compact ? EdgeInsets.zero : const EdgeInsets.all(8),
        constraints: compact
            ? const BoxConstraints.tightFor(width: 40, height: 40)
            : null,
        tooltip: muted ? 'Unmute music and sound' : 'Mute music and sound',
      );
    },
  );
}
