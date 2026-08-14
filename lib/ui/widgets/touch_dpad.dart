import 'package:flutter/material.dart';

import '../../services/settings_service.dart';
import 'hold_repeat_button.dart';
import 'juicy_button.dart';

/// A two-cluster "gamepad" control surface: a joined move/soft-drop track on
/// one side, and a hard-drop hero button + rotate/hold/mode actions on the
/// other — rather than a flat grid of identical circles, so weight on
/// screen matches how often (and how satisfyingly) each action gets pressed.
class TouchDpad extends StatelessWidget {
  const TouchDpad({
    super.key,
    required this.enabled,
    required this.onMoveLeft,
    required this.onMoveRight,
    required this.onSoftDrop,
    required this.onRotateLeft,
    required this.onRotateRight,
    required this.onMirror,
    required this.onHold,
    required this.canHold,
    required this.onHardDrop,
    required this.onFillCavities,
    required this.cavityCharges,
    required this.onSpeedUp,
    required this.speedBoost,
    this.reduceMotion = false,
    this.handedness = TouchHandedness.balanced,
  });

  final bool enabled;
  final VoidCallback onMoveLeft;
  final VoidCallback onMoveRight;
  final VoidCallback onSoftDrop;
  final VoidCallback onRotateLeft;
  final VoidCallback onRotateRight;
  final VoidCallback onMirror;
  final VoidCallback onHold;
  final bool canHold;
  final VoidCallback onHardDrop;
  final VoidCallback? onFillCavities;
  final int cavityCharges;
  final VoidCallback? onSpeedUp;
  final int speedBoost;

  /// Skips the hero button's idle glow pulse (docs/GDD.md SS8 motion toggle).
  final bool reduceMotion;

  /// Which hand the *move* track sits under — the mirror-image hand gets the
  /// action cluster (docs/GDD.md SS8). [balanced] defaults to the
  /// conventional move-left/act-right split.
  final TouchHandedness handedness;

  static const _heroSize = 64.0;
  static const _primarySize = 58.0;
  static const _satelliteSize = 36.0;

  /// Mirror/Rotate's tint — a shared "these are the core, frequent actions"
  /// identity distinct from the hero button's theme-accent glow.
  static const _primaryTint = Color(0xFFFFD54F);

  static ButtonStyle _circleStyle(double size) => ElevatedButton.styleFrom(
    shape: const CircleBorder(),
    minimumSize: Size(size, size),
    fixedSize: Size(size, size),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    padding: EdgeInsets.zero,
    backgroundColor: Colors.transparent,
    disabledBackgroundColor: Colors.transparent,
    foregroundColor: Colors.white,
    elevation: 0,
    shadowColor: Colors.transparent,
  );

  Widget _satellite(
    IconData icon,
    String label,
    VoidCallback? callback, {
    String? badge,
  }) {
    final active = enabled && callback != null;
    final tint = active ? Colors.white : Colors.white30;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        enabled: active,
        label: label,
        child: JuicyButton(
          onPressed: active ? callback : null,
          style: _circleStyle(_satelliteSize),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: _satelliteSize,
                height: _satelliteSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tint.withValues(alpha: 0.08),
                  border: Border.all(color: tint.withValues(alpha: 0.4)),
                ),
                child: Icon(icon, color: tint, size: 19),
              ),
              if (badge != null)
                Positioned(
                  right: -6,
                  top: -6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: tint.withValues(alpha: 0.7)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(fontSize: 8, color: tint),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _primaryButton(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback callback,
    double size, {
    Color? accent,
    bool pulse = false,
  }) {
    final active = enabled;
    final skipMotion = reduceMotion || MediaQuery.of(context).disableAnimations;
    final tint = active ? Colors.white : Colors.white30;
    final glow = active ? (accent ?? Colors.white) : Colors.white24;
    final face = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [glow.withValues(alpha: 0.32), glow.withValues(alpha: 0.10)],
        ),
        border: Border.all(color: glow.withValues(alpha: 0.85), width: 2),
      ),
      child: Icon(icon, color: tint, size: size * 0.44),
    );
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        enabled: active,
        label: label,
        child: JuicyButton(
          onPressed: active ? callback : null,
          style: _circleStyle(size),
          child: pulse
              ? _PulsingGlow(
                  color: glow,
                  enabled: active && !skipMotion,
                  child: face,
                )
              : face,
        ),
      ),
    );
  }

  Widget _buildMoveTrack() {
    return _DpadTrack(
      enabled: enabled,
      onLeft: onMoveLeft,
      onDown: onSoftDrop,
      onRight: onMoveRight,
    );
  }

  Widget _buildActionCluster(BuildContext context, Color accent) {
    final satellites = [
      _satellite(
        Icons.rotate_left,
        'Rotate left',
        enabled ? onRotateLeft : null,
      ),
      _satellite(
        Icons.inventory_2_outlined,
        'Hold piece',
        enabled && canHold ? onHold : null,
      ),
      if (onFillCavities != null)
        _satellite(
          Icons.auto_fix_high,
          'Fill lowest cavity',
          enabled && cavityCharges > 0 ? onFillCavities : null,
          badge: '$cavityCharges',
        ),
      if (onSpeedUp != null)
        _satellite(
          Icons.speed,
          'Increase speed and score multiplier',
          enabled ? onSpeedUp : null,
          badge: '+$speedBoost',
        ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 6,
          runSpacing: 6,
          children: satellites,
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Hard drop leads (leftmost) rather than trails the row, so it
            // sits closer to the middle of the screen instead of jammed
            // against the edge — the opposite of where you'd want the
            // single most-pressed button.
            _primaryButton(
              context,
              Icons.keyboard_double_arrow_down,
              'Hard drop',
              onHardDrop,
              _heroSize,
              accent: accent,
              pulse: true,
            ),
            const SizedBox(width: 10),
            // Mirror and Rotate sit at the same priority tier — both core,
            // frequent triangle-matching actions, not occasional extras, so
            // they don't belong crammed into the small satellite row with
            // Hold/Fill-Cavities/Speed-Boost. Shared yellow tint marks them
            // as a pair, distinct from the hero button's theme-accent glow.
            _primaryButton(
              context,
              Icons.rotate_right,
              'Rotate right',
              onRotateRight,
              _primarySize,
              accent: _primaryTint,
            ),
            const SizedBox(width: 8),
            _primaryButton(
              context,
              Icons.flip,
              'Mirror triangles',
              onMirror,
              _primarySize,
              accent: _primaryTint,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final moveTrack = _buildMoveTrack();
    final actionCluster = _buildActionCluster(context, accent);
    final clusters = handedness == TouchHandedness.right
        ? [actionCluster, moveTrack]
        : [moveTrack, actionCluster];

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: clusters,
      ),
    );
  }
}

/// The joined move-left / soft-drop / move-right control — three segments in
/// one continuous rounded track rather than three floating circles, so it
/// reads as a single cohesive D-pad rather than a loose row of buttons.
class _DpadTrack extends StatelessWidget {
  const _DpadTrack({
    required this.enabled,
    required this.onLeft,
    required this.onDown,
    required this.onRight,
  });

  final bool enabled;
  final VoidCallback onLeft;
  final VoidCallback onDown;
  final VoidCallback onRight;

  static const _segWidth = 50.0;
  static const _height = 64.0;

  Widget _segment(
    IconData icon,
    String label,
    VoidCallback callback, {
    BorderRadius? radius,
  }) {
    final tint = enabled ? Colors.white : Colors.white30;
    final face = Container(
      width: _segWidth,
      height: _height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [tint.withValues(alpha: 0.16), tint.withValues(alpha: 0.04)],
        ),
      ),
      child: Icon(icon, color: tint, size: 26),
    );
    final wrapped = Tooltip(
      message: label,
      child: Semantics(button: true, label: label, child: face),
    );
    return enabled
        ? HoldRepeatButton(
            onHold: callback,
            semanticLabel: label,
            child: wrapped,
          )
        : wrapped;
  }

  @override
  Widget build(BuildContext context) {
    final tint = enabled ? Colors.white : Colors.white30;
    final divider = Container(
      width: 1,
      height: _height * 0.6,
      color: tint.withValues(alpha: 0.18),
    );
    return Container(
      height: _height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tint.withValues(alpha: 0.4), width: 1.5),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(
            Icons.chevron_left,
            'Move left',
            onLeft,
            radius: const BorderRadius.horizontal(left: Radius.circular(18)),
          ),
          divider,
          _segment(Icons.expand_more, 'Soft drop', onDown),
          divider,
          _segment(
            Icons.chevron_right,
            'Move right',
            onRight,
            radius: const BorderRadius.horizontal(right: Radius.circular(18)),
          ),
        ],
      ),
    );
  }
}

/// A slow breathing glow behind the hard-drop hero button, so the single
/// most-pressed, most-satisfying action visually invites the tap rather than
/// sitting flat next to everything else.
class _PulsingGlow extends StatefulWidget {
  const _PulsingGlow({
    required this.color,
    required this.enabled,
    required this.child,
  });

  final Color color;
  final bool enabled;
  final Widget child;

  @override
  State<_PulsingGlow> createState() => _PulsingGlowState();
}

class _PulsingGlowState extends State<_PulsingGlow>
    with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _PulsingGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.enabled && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = _ctrl.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.22 + 0.22 * t),
                blurRadius: 10 + 10 * t,
                spreadRadius: 1 + 2 * t,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
