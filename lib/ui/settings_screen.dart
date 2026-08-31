import 'dart:async';

import 'package:flutter/material.dart';

import '../game/tutorial_level_screen.dart';
import '../models/piece.dart';
import '../models/theme_palette.dart';
import '../services/audio_service.dart';
import '../services/live_services.dart';
import '../services/settings_service.dart';
import '../services/theme_service.dart';
import 'account_screen.dart';
import 'widgets/menu_backdrop.dart';
import 'widgets/neon_text.dart';
import 'legal_screen.dart';

/// Volume/mute, appearance, and accessibility toggles (docs/GDD.md SS6.5,
/// SS7-SS8). Reachable from the start screen so players never have to be
/// mid-run to find them.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.audio,
    required this.settings,
    required this.theme,
    required this.live,
  });

  final AudioService audio;
  final SettingsService settings;
  final ThemeService theme;
  final LiveServices live;

  /// Random strips out the only signal Duo gives for free (which triangle
  /// half a cell still needs), so switching to it is a real difficulty
  /// jump, not just a cosmetic pick — worth a confirm rather than a
  /// one-tap accident (matches the same picker on the start screen).
  Future<void> _confirmRandomColorMode(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Switch to Random colors?'),
        content: const Text(
          "This makes the game visually much harder to play — color won't "
          'tell you anything about a piece\'s shape or which triangle half '
          'it needs anymore.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Switch'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await settings.setPieceColorMode(PieceColorMode.random);
    }
  }

  Future<void> _showTutorial(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TutorialLevelScreen(settings: settings),
      ),
    );
    unawaited(settings.setHasSeenTutorial(true));
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return ListenableBuilder(
      listenable: Listenable.merge([audio, settings, theme, live.auth]),
      builder: (context, _) => Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Settings',
            style: TextStyle(shadows: neonShadows(accent, intensity: 0.6)),
          ),
        ),
        body: Stack(
          children: [
            MenuBackdrop(
              theme: theme.current,
              reduceMotion: settings.reduceMotion,
            ),
            // SingleChildScrollView outside Center (not the other way
            // around) so its hit-testable width is the full screen --
            // otherwise it only sizes itself to its centered, width-capped
            // content, leaving dead margins on wider screens where a drag
            // silently does nothing instead of scrolling.
            SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SettingsCard(
                            label: 'Help',
                            accent: accent,
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.school_outlined,
                                  color: Colors.white54,
                                ),
                                title: const Text('How to Play'),
                                subtitle: const Text(
                                  'Replay the onboarding walkthrough any time',
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right,
                                  color: Colors.white38,
                                ),
                                onTap: () => _showTutorial(context),
                              ),
                            ],
                          ),
                          _SettingsCard(
                            label: 'Appearance',
                            accent: accent,
                            children: [
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  for (final palette in ThemePalette.all)
                                    _ThemeSwatch(
                                      palette: palette,
                                      selected: theme.current.id == palette.id,
                                      onTap: () =>
                                          unawaited(theme.setTheme(palette.id)),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          _SettingsCard(
                            label: 'Audio',
                            accent: accent,
                            children: [
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                secondary: const Icon(
                                  Icons.volume_off,
                                  color: Colors.white54,
                                ),
                                title: const Text('Mute all audio'),
                                value: audio.muted,
                                onChanged: (v) => unawaited(audio.setMuted(v)),
                              ),
                              _SliderRow(
                                icon: Icons.music_note,
                                title: 'Music volume',
                                value: audio.musicVolume,
                                accent: accent,
                                onChanged: audio.muted
                                    ? null
                                    : (v) => unawaited(audio.setMusicVolume(v)),
                              ),
                              _SliderRow(
                                icon: Icons.graphic_eq,
                                title: 'Sound effects volume',
                                value: audio.sfxVolume,
                                accent: accent,
                                onChanged: audio.muted
                                    ? null
                                    : (v) => unawaited(audio.setSfxVolume(v)),
                              ),
                            ],
                          ),
                          _SettingsCard(
                            label: 'Accessibility',
                            accent: accent,
                            children: [
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                secondary: const Icon(
                                  Icons.motion_photos_off,
                                  color: Colors.white54,
                                ),
                                title: const Text('Reduce motion'),
                                subtitle: const Text(
                                  'Softens screen shake and thins out particle bursts',
                                ),
                                value: settings.reduceMotion,
                                onChanged: (v) =>
                                    unawaited(settings.setReduceMotion(v)),
                              ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                secondary: const Icon(
                                  Icons.vibration,
                                  color: Colors.white54,
                                ),
                                title: const Text('Haptics'),
                                subtitle: const Text(
                                  'Vibration feedback on key actions',
                                ),
                                value: settings.hapticsEnabled,
                                onChanged: (v) =>
                                    unawaited(settings.setHapticsEnabled(v)),
                              ),
                              _SliderRow(
                                icon: Icons.text_fields,
                                title: 'Text & UI size',
                                value: settings.uiScale,
                                min: 0.85,
                                max: 1.3,
                                divisions: 3,
                                accent: accent,
                                onChanged: (v) =>
                                    unawaited(settings.setUiScale(v)),
                              ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.touch_app,
                                  color: Colors.white54,
                                ),
                                title: const Text('Touch controls'),
                                subtitle: const Text(
                                  'Cluster mobile controls toward one thumb',
                                ),
                                trailing: DropdownButton<TouchHandedness>(
                                  value: settings.touchHandedness,
                                  onChanged: (v) {
                                    if (v != null) {
                                      unawaited(settings.setTouchHandedness(v));
                                    }
                                  },
                                  items: const [
                                    DropdownMenuItem(
                                      value: TouchHandedness.balanced,
                                      child: Text('Balanced'),
                                    ),
                                    DropdownMenuItem(
                                      value: TouchHandedness.left,
                                      child: Text('Left-handed'),
                                    ),
                                    DropdownMenuItem(
                                      value: TouchHandedness.right,
                                      child: Text('Right-handed'),
                                    ),
                                  ],
                                ),
                              ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.gesture,
                                  color: Colors.white54,
                                ),
                                title: const Text('Control scheme'),
                                subtitle: const Text(
                                  'Gestures replaces the on-screen buttons: '
                                  'swipe to move, tap to mirror (or fill a '
                                  'tapped cavity), double-tap to hard drop, '
                                  'swipe up to rotate, long-press to hold',
                                ),
                                trailing: DropdownButton<TouchControlScheme>(
                                  value: settings.touchControlScheme,
                                  onChanged: (v) {
                                    if (v != null) {
                                      unawaited(
                                        settings.setTouchControlScheme(v),
                                      );
                                    }
                                  },
                                  items: const [
                                    DropdownMenuItem(
                                      value: TouchControlScheme.buttons,
                                      child: Text('Buttons'),
                                    ),
                                    DropdownMenuItem(
                                      value: TouchControlScheme.gestures,
                                      child: Text('Gestures'),
                                    ),
                                  ],
                                ),
                              ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.palette,
                                  color: Colors.white54,
                                ),
                                title: const Text('Piece colors'),
                                subtitle: const Text(
                                  'Duo signals each triangle half; Random is '
                                  'much harder to read',
                                ),
                                trailing: DropdownButton<PieceColorMode>(
                                  value: settings.pieceColorMode,
                                  onChanged: (v) {
                                    if (v == null) return;
                                    if (v == PieceColorMode.random) {
                                      unawaited(
                                        _confirmRandomColorMode(context),
                                      );
                                    } else {
                                      unawaited(settings.setPieceColorMode(v));
                                    }
                                  },
                                  items: const [
                                    DropdownMenuItem(
                                      value: PieceColorMode.duo,
                                      child: Text('Duo (Recommended)'),
                                    ),
                                    DropdownMenuItem(
                                      value: PieceColorMode.random,
                                      child: Text('Random (hardest)'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          _SettingsCard(
                            label: 'Cloud Backup',
                            accent: accent,
                            children: [_CloudBackupSection(live: live)],
                          ),
                          _SettingsCard(
                            label: 'Legal',
                            accent: accent,
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.privacy_tip_outlined,
                                  color: Colors.white54,
                                ),
                                title: const Text('Privacy Policy'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        LegalScreen(analytics: live.analytics),
                                  ),
                                ),
                              ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.description_outlined,
                                  color: Colors.white54,
                                ),
                                title: const Text('Terms of Use'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => LegalScreen(
                                      analytics: live.analytics,
                                      initialTab: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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

class _CloudBackupSection extends StatelessWidget {
  const _CloudBackupSection({required this.live});

  final LiveServices live;

  @override
  Widget build(BuildContext context) {
    if (!live.backup.available) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          "Cloud backup isn't available yet. Your progress stays safe on "
          'this device in the meantime.',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
      );
    }
    if (!live.auth.isAnonymous) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.cloud_done, color: Colors.greenAccent, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Logged in with ${live.auth.email ?? 'email'}.',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: () => _confirmDelete(context),
              child: const Text('Delete my data'),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Link an account to back up your progress across devices — '
            'never required to play.',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => AccountScreen(live: live)),
                ),
                child: const Text('Log in with email'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete my data?'),
        content: const Text(
          'This permanently deletes your cloud backup and account. Local '
          'progress on this device is not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final dataOk = await live.backup.deleteAllData();
              final accountOk = dataOk && await live.auth.deleteAccount();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      accountOk
                          ? 'Your cloud backup and account were deleted.'
                          : "That didn't go through — try again anytime.",
                    ),
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final ThemePalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final swatchColors = palette.pieceColors.values.take(5).toList();
    return Semantics(
      button: true,
      selected: selected,
      label: '${palette.label} theme',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 148,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: palette.backgroundBottom,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? palette.accent : Colors.white24,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      palette.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.check_circle, color: palette.accent, size: 16),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final c in swatchColors)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A bordered, tinted section container — gives each settings group the
/// same card language as [PauseMenu]/the mode-select cards, instead of
/// Settings being the one screen left as a bare, unstyled list.
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.label,
    required this.accent,
    required this.children,
  });

  final String label;
  final Color accent;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.18)),
        ),
        // A ListTile paints its background/splashes on the nearest Material
        // ancestor — without this, the tinted Container above would sit
        // between the tiles and that ancestor and Flutter flags it as an
        // invisible-background bug.
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionLabel(label, accent: accent),
              const SizedBox(height: 4),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// A slider with an icon and a live percentage readout so the value is
/// always visible at rest, not just while dragging — the Music/SFX volume
/// sliders previously showed no value at all, inconsistent with the Text &
/// UI size slider next to them.
class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.accent,
    required this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
  });

  final IconData icon;
  final String title;
  final double value;
  final Color accent;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    // The raw value as a percentage (not position-within-range), matching
    // what the Text & UI size slider showed before this widget existed —
    // 100% at value 1.0 regardless of its 0.85-1.3 range.
    final pct = (value * 100).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Icon(icon, size: 20, color: Colors.white54),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title, style: const TextStyle(fontSize: 14)),
                    ),
                    Text(
                      '$pct%',
                      style: TextStyle(
                        color: onChanged == null ? Colors.white38 : accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: divisions,
                  label: '$pct%',
                  onChanged: onChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {required this.accent});
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: accent, letterSpacing: 1.2),
      ),
    );
  }
}
