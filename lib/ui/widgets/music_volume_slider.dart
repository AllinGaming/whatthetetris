import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/audio_service.dart';

/// A visible, persistent music control for the mode-select screen.
/// One-tap mute remains available while the slider changes only music,
/// leaving gameplay sound effects at their independently configured level.
class MusicVolumeSlider extends StatelessWidget {
  const MusicVolumeSlider({super.key, required this.audio});

  final AudioService audio;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: audio,
    builder: (context, _) {
      final percent = (audio.musicVolume * 100).round();
      return Semantics(
        container: true,
        label: 'Music volume $percent percent',
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: Row(
            children: [
              IconButton(
                onPressed: () => unawaited(audio.setMuted(!audio.muted)),
                tooltip: audio.muted ? 'Unmute all audio' : 'Mute all audio',
                icon: Icon(
                  audio.muted ? Icons.volume_off : Icons.music_note,
                  color: audio.muted ? Colors.orangeAccent : Colors.white70,
                ),
              ),
              const SizedBox(width: 2),
              const Text(
                'Music',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Expanded(
                child: Slider(
                  value: audio.musicVolume,
                  onChanged: (value) =>
                      unawaited(audio.setMusicVolume(value)),
                  semanticFormatterCallback: (value) =>
                      '${(value * 100).round()} percent',
                ),
              ),
              SizedBox(
                width: 38,
                child: Text(
                  '$percent%',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
