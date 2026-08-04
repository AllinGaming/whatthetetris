import 'package:flutter/material.dart';

class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.label, required this.value, this.best});

  final String label;
  final int value;
  final int? best;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ),
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: value),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                builder: (context, animatedValue, _) => Text(
                  '$animatedValue',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (best != null)
            Text(
              'best $best',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: Colors.white38),
            ),
        ],
      ),
    );
  }
}
