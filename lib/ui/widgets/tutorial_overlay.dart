import 'package:flutter/material.dart';

import 'cavity_fill_diagram.dart';
import 'fusion_hero.dart';
import 'mirror_flip_demo.dart';
import 'move_rotate_demo.dart';

class _TutorialPage {
  const _TutorialPage({
    this.icon,
    this.visual,
    required this.title,
    required this.body,
  }) : assert(
         icon != null || visual != null,
         'every page needs either an icon or a custom visual',
       );

  /// Used when the page has no bespoke [visual] — plain controls/overview
  /// pages don't need one.
  final IconData? icon;

  /// A small demonstration widget (e.g. [FusionHero], [MirrorFlipDemo],
  /// [MoveRotateDemo]) used in place of a static icon for mechanics that are
  /// easier to show — and now, mostly, to actually try — than to describe.
  final Widget? visual;
  final String title;
  final String body;
}

/// A labeled icon used on the Back-to-Back & Combo page — two related
/// concepts side by side rather than a single generic icon. Tapping pulses
/// it, a small nod to interactivity for a page that (unlike the mechanic
/// pages around it) has no single discrete action to actually practice.
class _MechanicBadge extends StatefulWidget {
  const _MechanicBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  State<_MechanicBadge> createState() => _MechanicBadgeState();
}

class _MechanicBadgeState extends State<_MechanicBadge> {
  bool _pulsed = false;

  void _pulse() {
    setState(() => _pulsed = true);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _pulsed = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _pulse,
      child: AnimatedScale(
        scale: _pulsed ? 1.22 : 1.0,
        duration: const Duration(milliseconds: 220),
        curve: _pulsed ? Curves.easeOut : Curves.easeIn,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 34, color: widget.color),
            const SizedBox(height: 6),
            Text(
              widget.label,
              style: TextStyle(
                color: widget.color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Built per-instance (rather than a top-level const list) because the
/// Mirror Flip/Fusion pages' demo widgets need this dialog's snapshot of
/// [SettingsService.reduceMotion], which isn't known until construction.
List<_TutorialPage> _buildPages(bool reduceMotion) => [
  const _TutorialPage(
    visual: MoveRotateDemo(color: Colors.lightBlueAccent),
    title: 'Move & Rotate',
    body:
        'Try it above: ⟵ / ⟶ move, ⟳ rotates. In-game that\'s the arrows '
        'plus ⟲ / ⟳, with soft-drop on the down arrow. Hard drop instantly '
        "locks a piece where the ghost outline shows it landing.",
  ),
  _TutorialPage(
    visual: MirrorFlipDemo(
      color: Colors.orangeAccent,
      reduceMotion: reduceMotion,
    ),
    title: 'Mirror Flip',
    body:
        'Every piece is built from triangle halves, not full squares. '
        "Mirror (M) flips every cell's diagonal in place — same piece, same "
        "position, opposite halves. Use it to line up a fusion the piece's "
        "current orientation can't reach.",
  ),
  _TutorialPage(
    visual: FusionHero(
      colorA: Colors.cyanAccent,
      colorB: Colors.pinkAccent,
      size: 108,
      reduceMotion: reduceMotion,
      interactive: true,
    ),
    title: 'Fusion Bonus',
    body:
        'Land a triangle half onto a cell that already holds the opposite '
        'half — any color — and they fuse into a full cell. This is this '
        "game's answer to a T-spin bonus: extra points per fused cell, on "
        'top of anything it clears.',
  ),
  _TutorialPage(
    visual: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MechanicBadge(
          icon: Icons.local_fire_department,
          label: 'COMBO',
          color: Colors.orangeAccent,
        ),
        SizedBox(width: 28),
        _MechanicBadge(
          icon: Icons.stacked_line_chart,
          label: 'BACK-TO-BACK',
          color: Colors.deepPurpleAccent,
        ),
      ],
    ),
    title: 'Back-to-Back & Combo',
    body:
        'Tap either badge above for a look. Clearing lines back to back '
        "builds a combo, shown from your second clear in a row and "
        'escalating in color as it grows. A Tetris — or a lock with 2+ '
        'fusions — counts as a hard clear: two hard clears in a row earns '
        'a +50% Back-to-Back bonus. Combo rewards frequency; Back-to-Back '
        'rewards the consistency of your best clears.',
  ),
  _TutorialPage(
    visual: const CavityFillDiagram(color: Colors.lightGreenAccent),
    title: 'Hold & Cavity Fill',
    body:
        'Tap the cavity above to close it yourself. Hold (C) sets a piece '
        'aside for later — once per piece. Cavity Fill (G) closes a stray, '
        'unfused half using its own color — no match needed. Charges '
        'regenerate with every line you clear, and completing one via '
        'Cavity Fill refunds it.',
  ),
  const _TutorialPage(
    icon: Icons.explore_outlined,
    title: 'Picking a Mode',
    body:
        'New to this? Chill plays on a narrower board with the 5 easiest '
        "shapes and never truly ends — the stack clears itself before it "
        'can top out. Zen keeps the full shape set with that same safety '
        'net — a great place to practice fusions and mirror flips risk-free. '
        'Sprint, Ultra, and Daily Challenge are goal- and clock-driven once '
        "you're ready for the pressure.",
  ),
];

/// A short, dismiss-once "How to Play" overlay shown the first time a
/// player ever reaches a game screen (docs/GDD.md SS3-4 core mechanics).
/// Also reachable any time afterward from the start screen and Settings, so
/// a player who skipped it — or wants a refresher — isn't locked out for
/// good. Nothing here is mode-specific beyond the last page; it explains
/// the universal controls and the fusion/mirror/cavity mechanics that make
/// this game its own thing, not a Tetris reskin.
class TutorialOverlay extends StatefulWidget {
  const TutorialOverlay({
    super.key,
    required this.onDone,
    this.reduceMotion = false,
  });

  final VoidCallback onDone;

  /// Forwarded to the Mirror Flip/Fusion pages' looping demo widgets — see
  /// `SettingsService.reduceMotion`.
  final bool reduceMotion;

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> {
  final _controller = PageController();
  late final _pages = _buildPages(widget.reduceMotion);
  int _page = 0;

  /// Guards [_finish] so a fast double-tap on Skip/"Let's go" (or one of
  /// each in quick succession) can only ever pop this dialog once. Without
  /// it, the second `onDone()` call pops whatever route is now on top —
  /// which, since Navigator's pop transition is synchronous, is the screen
  /// this dialog was opened over (Start screen, Settings, or a brand-new
  /// GameScreen on first launch).
  bool _closing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    if (_closing) return;
    _closing = true;
    widget.onDone();
  }

  void _next() {
    if (_page == _pages.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final isLast = _page == _pages.length - 1;
    return Dialog(
      backgroundColor: const Color(0xFF14161F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          // A short/landscape viewport (or a high UI-scale text setting)
          // could otherwise push this dialog's fixed-height content past
          // the screen with no way to reach Skip/Next — scroll instead of
          // overflow, matching ResultsScreen's pattern.
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 290,
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, i) {
                    final page = _pages[i];
                    return Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            page.visual ??
                                Icon(page.icon, size: 48, color: accent),
                            const SizedBox(height: 14),
                            Text(
                              page.title,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              page.body,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < _pages.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _page ? accent : Colors.white24,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(onPressed: _finish, child: const Text('Skip')),
                  FilledButton(
                    onPressed: _next,
                    child: Text(isLast ? "Let's go" : 'Next'),
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
