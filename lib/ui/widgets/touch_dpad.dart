import 'package:flutter/material.dart';

import 'hold_repeat_button.dart';
import 'juicy_button.dart';

/// Compact two-row mobile controls with full feature parity.
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

  static const _buttonSize = 48.0;
  static const _gap = SizedBox(width: 8);

  Widget _face(
    BuildContext context,
    IconData icon, {
    Color? color,
    String? badge,
    bool enabled = true,
  }) {
    final tint = enabled ? (color ?? Colors.white) : Colors.white30;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: _buttonSize,
          height: _buttonSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tint.withValues(alpha: 0.10),
            border: Border.all(color: tint.withValues(alpha: 0.45), width: 1.5),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: tint.withValues(alpha: 0.25),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Icon(icon, color: tint, size: 21),
        ),
        if (badge != null)
          Positioned(
            right: -4,
            top: -4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: tint.withValues(alpha: 0.7)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                child: Text(badge, style: TextStyle(fontSize: 9, color: tint)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _repeat(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback callback,
  ) {
    final face = Tooltip(
      message: label,
      child: _face(context, icon, enabled: enabled),
    );
    return enabled
        ? HoldRepeatButton(onHold: callback, semanticLabel: label, child: face)
        : face;
  }

  Widget _action(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback? callback, {
    Color? color,
    String? badge,
  }) {
    final activeCallback = enabled ? callback : null;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        enabled: activeCallback != null,
        label: label,
        child: JuicyButton(
          onPressed: activeCallback,
          style: _circleStyle,
          child: _face(
            context,
            icon,
            color: color,
            badge: badge,
            enabled: activeCallback != null,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _action(context, Icons.rotate_left, 'Rotate left', onRotateLeft),
              _gap,
              _action(
                context,
                Icons.rotate_right,
                'Rotate right',
                onRotateRight,
              ),
              _gap,
              _action(context, Icons.flip, 'Mirror triangles', onMirror),
              _gap,
              _action(
                context,
                Icons.inventory_2_outlined,
                'Hold piece',
                canHold ? onHold : null,
              ),
              _gap,
              _action(
                context,
                Icons.vertical_align_bottom,
                'Hard drop',
                onHardDrop,
                color: accent,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _repeat(context, Icons.arrow_back, 'Move left', onMoveLeft),
              _gap,
              _repeat(context, Icons.arrow_downward, 'Soft drop', onSoftDrop),
              _gap,
              _repeat(context, Icons.arrow_forward, 'Move right', onMoveRight),
              if (onFillCavities != null) ...[
                _gap,
                _action(
                  context,
                  Icons.auto_fix_high,
                  'Fill lowest cavity',
                  cavityCharges > 0 ? onFillCavities : null,
                  badge: '$cavityCharges',
                ),
              ],
              if (onSpeedUp != null) ...[
                _gap,
                _action(
                  context,
                  Icons.speed,
                  'Increase speed and score multiplier',
                  onSpeedUp,
                  badge: '+$speedBoost',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static final ButtonStyle _circleStyle = ElevatedButton.styleFrom(
    shape: const CircleBorder(),
    minimumSize: const Size(_buttonSize, _buttonSize),
    fixedSize: const Size(_buttonSize, _buttonSize),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    padding: EdgeInsets.zero,
    backgroundColor: Colors.transparent,
    disabledBackgroundColor: Colors.transparent,
    foregroundColor: Colors.white,
    elevation: 0,
    shadowColor: Colors.transparent,
  );
}
