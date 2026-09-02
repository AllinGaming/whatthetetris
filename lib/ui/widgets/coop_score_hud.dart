import 'package:flutter/material.dart';

import '../../models/piece.dart';

/// Score-first multiplayer HUD shared by all co-op variants.
///
/// The team score deliberately gets the strongest visual weight. Connection,
/// level, best, objective progress, and each player's clear contribution stay
/// visible without competing with the board for vertical space.
class CoopScoreHud extends StatelessWidget {
  const CoopScoreHud({
    super.key,
    required this.connected,
    required this.score,
    required this.lines,
    required this.combo,
    required this.backToBack,
    required this.redLines,
    required this.blueLines,
    required this.bestScore,
    this.puzzleRowsRemaining,
    this.puzzleSpeedBonusPreview,
  });

  final bool connected;
  final int score;
  final int lines;
  final int combo;
  final int backToBack;
  final int redLines;
  final int blueLines;
  final int bestScore;
  final int? puzzleRowsRemaining;
  final int? puzzleSpeedBonusPreview;

  @override
  Widget build(BuildContext context) {
    final level = 1 + lines ~/ 10;
    final objectiveLabel = puzzleRowsRemaining == null
        ? 'TEAM LINES'
        : 'ROWS TO GO';
    final objectiveValue = puzzleRowsRemaining ?? lines;

    return Semantics(
      key: const ValueKey('coop-score-hud'),
      container: true,
      liveRegion: true,
      label:
          'Team score $score. $objectiveLabel $objectiveValue. '
          '${puzzleSpeedBonusPreview == null ? '' : 'Speed bonus $puzzleSpeedBonusPreview. '}'
          'Red clears $redLines. Blue clears $blueLines.',
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              duoBlColor.withValues(alpha: 0.10),
              Colors.white.withValues(alpha: 0.055),
              duoTrColor.withValues(alpha: 0.10),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          boxShadow: [
            BoxShadow(
              color: Color.lerp(
                duoBlColor,
                duoTrColor,
                0.5,
              )!.withValues(alpha: 0.08),
              blurRadius: 14,
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 350;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: connected
                            ? Colors.greenAccent
                            : Colors.orangeAccent,
                        boxShadow: [
                          BoxShadow(
                            color:
                                (connected
                                        ? Colors.greenAccent
                                        : Colors.orangeAccent)
                                    .withValues(alpha: 0.55),
                            blurRadius: 7,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      compact
                          ? (connected ? 'LIVE' : 'OFFLINE')
                          : (connected ? 'LIVE CO-OP' : 'RECONNECTING'),
                      style: TextStyle(
                        color: connected
                            ? Colors.greenAccent
                            : Colors.orangeAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: compact ? 0.4 : 0.8,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'BEST ${formatCoopScore(bestScore)}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _MetricPill(label: 'LV', value: '$level'),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TEAM SCORE',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          TweenAnimationBuilder<int>(
                            tween: IntTween(end: score),
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, _) => Text(
                              formatCoopScore(value),
                              key: const ValueKey('coop-score-value'),
                              maxLines: 1,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: compact ? 24 : 28,
                                height: 1,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4,
                                shadows: [
                                  Shadow(
                                    color: Color.lerp(
                                      duoBlColor,
                                      duoTrColor,
                                      0.5,
                                    )!.withValues(alpha: 0.75),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 9 : 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.13),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            objectiveLabel,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            '$objectiveValue',
                            key: const ValueKey('coop-objective-value'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              height: 1.05,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (puzzleSpeedBonusPreview != null)
                            Text(
                              'SPEED +${formatCoopScore(puzzleSpeedBonusPreview!)}',
                              key: const ValueKey('coop-speed-bonus-preview'),
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: _Contribution(
                        label: compact
                            ? 'RED $redLines'
                            : 'RED CLEARS $redLines',
                        color: duoBlColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Contribution(
                        label: compact
                            ? 'BLUE $blueLines'
                            : 'BLUE CLEARS $blueLines',
                        color: duoTrColor,
                        alignRight: true,
                      ),
                    ),
                  ],
                ),
                if (combo > 1 || backToBack > 1) ...[
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (combo > 1) '${combo}x COMBO',
                      if (backToBack > 1) 'B2B $backToBack',
                    ].join(' · '),
                    style: TextStyle(
                      color: Color.lerp(duoBlColor, duoTrColor, 0.5),
                      fontWeight: FontWeight.w900,
                      fontSize: compact ? 9 : 10,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      '$label $value',
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
    ),
  );
}

class _Contribution extends StatelessWidget {
  const _Contribution({
    required this.label,
    required this.color,
    this.alignRight = false,
  });

  final String label;
  final Color color;
  final bool alignRight;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: alignRight
        ? MainAxisAlignment.end
        : MainAxisAlignment.start,
    children: [
      if (alignRight) ...[
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 5),
      ],
      Container(
        width: 22,
        height: 3,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 5),
          ],
        ),
      ),
      if (!alignRight) ...[
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ],
  );
}

String formatCoopScore(int value) {
  final digits = value.toString();
  final output = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) output.write(',');
    output.write(digits[index]);
  }
  return output.toString();
}
