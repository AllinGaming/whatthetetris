import 'package:flutter/material.dart';

import 'neon_text.dart';

class ToastData {
  const ToastData(this.text, this.color, {this.big = false});
  final String text;
  final Color color;

  /// A dramatic full-size banner (Tetris/combo callouts) instead of a
  /// small side-panel popup.
  final bool big;
}

/// A small rise-and-fade toast (score popup / level-up / new-best) that
/// removes itself via [onDone] once its animation completes.
class FloatingToast extends StatefulWidget {
  const FloatingToast({super.key, required this.data, required this.onDone});

  final ToastData data;
  final VoidCallback onDone;

  @override
  State<FloatingToast> createState() => _FloatingToastState();
}

class _FloatingToastState extends State<FloatingToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.data.big
        ? const Duration(milliseconds: 1400)
        : const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone();
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final big = widget.data.big;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final rise = big ? 0.0 : Curves.easeOut.transform(t) * 28;
        final fade = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3).clamp(0.0, 1.0);
        final scale = big
            ? (Curves.elasticOut.transform((t / 0.4).clamp(0.0, 1.0)))
            : 1.0;
        return Opacity(
          opacity: fade,
          child: Transform.translate(
            offset: Offset(0, -rise),
            child: Transform.scale(scale: big ? scale : 1.0, child: child),
          ),
        );
      },
      child: Text(
        widget.data.text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: widget.data.color,
          fontWeight: FontWeight.w900,
          fontSize: big ? 40 : 15,
          letterSpacing: big ? 2 : 0,
          shadows: neonShadows(widget.data.color, intensity: big ? 1.4 : 1),
        ),
      ),
    );
  }
}
