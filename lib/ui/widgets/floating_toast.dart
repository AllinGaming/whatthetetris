import 'package:flutter/material.dart';

import 'neon_text.dart';

class ToastData {
  const ToastData(
    this.text,
    this.color, {
    this.big = false,
    this.subtitle,
    this.duration,
    this.backdrop = false,
  });

  final String text;
  final Color color;

  /// A dramatic full-size banner (four-line/combo callouts) instead of a
  /// small side-panel popup.
  final bool big;
  final String? subtitle;
  final Duration? duration;
  final bool backdrop;
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
    duration:
        widget.data.duration ??
        (widget.data.big
            ? const Duration(milliseconds: 1400)
            : const Duration(milliseconds: 900)),
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
        final fade = t < 0.10
            ? Curves.easeOut.transform(t / 0.10)
            : t < 0.76
            ? 1.0
            : (1 - (t - 0.76) / 0.24).clamp(0.0, 1.0);
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
      child: _content(big),
    );
  }

  Widget _content(bool big) {
    final data = widget.data;
    final title = Text(
      data.text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: data.color,
        fontWeight: FontWeight.w900,
        fontSize: big ? (data.backdrop ? 27 : 40) : (data.backdrop ? 17 : 15),
        letterSpacing: big ? 1.2 : 0,
        shadows: neonShadows(data.color, intensity: big ? 1.4 : 1),
      ),
    );
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        title,
        if (data.subtitle != null && data.subtitle!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            data.subtitle!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              height: 1.25,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
    );
    if (!data.backdrop) return content;
    return Container(
      key: const ValueKey('floating-toast-backdrop'),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xE6191C29),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: data.color.withValues(alpha: 0.68)),
        boxShadow: [
          BoxShadow(
            color: data.color.withValues(alpha: 0.30),
            blurRadius: 16,
            spreadRadius: 1,
          ),
          const BoxShadow(color: Colors.black54, blurRadius: 10),
        ],
      ),
      child: content,
    );
  }
}
