import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/achievement.dart';
import '../models/active_piece.dart';
import '../models/board.dart';
import '../models/game_mode.dart';
import '../models/piece.dart';
import '../models/pieces.dart';
import '../services/audio_service.dart';
import '../services/daily_challenge_service.dart';
import '../services/high_score_service.dart';
import '../services/live_services.dart';
import '../services/settings_service.dart';
import '../services/stats_service.dart';
import '../services/theme_service.dart';
import '../ui/game_side_panel.dart';
import '../ui/mobile_stats_bar.dart';
import '../ui/settings_screen.dart';
import '../ui/widgets/floating_toast.dart';
import '../ui/widgets/pause_menu.dart';
import '../ui/widgets/results_screen.dart';
import '../ui/widgets/touch_dpad.dart';
import '../ui/widgets/tutorial_overlay.dart';
import 'board_painter.dart';
import 'game_animations.dart';
import 'game_board.dart';
import 'piece_bag.dart';
import 'replay.dart';
import 'tutorial_level_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.mode,
    required this.highScores,
    required this.audio,
    required this.settings,
    required this.theme,
    required this.stats,
    required this.dailyChallenge,
    required this.live,
  });

  final GameMode mode;
  final HighScoreService highScores;
  final AudioService audio;
  final SettingsService settings;
  final ThemeService theme;
  final StatsService stats;
  final DailyChallengeService dailyChallenge;
  final LiveServices live;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const _previewCount = 3;
  static const _maxSpeedBoost = 8;
  static const _softFloorClearRows = 4;

  late final GameAnimations _anim = GameAnimations(vsync: this)
    ..reduceMotion = widget.settings.reduceMotion;

  Config get _config => Config(cols: cfg.cols);

  late GameBoard _board;
  ActivePiece? _active;
  PieceDefinition? _held;
  late List<PieceDefinition> _upcoming;

  /// Per-instance colors for [PieceColorMode.random] — assigned once, when a
  /// piece enters [_upcoming]/becomes [_active]/moves into [_held], and
  /// carried along from then on so the same piece instance never changes
  /// color mid-flight or between its preview swatch and its falling color.
  /// Unused (left stale) in the other two color modes.
  Color? _activeColor;
  Color? _heldColor;
  List<Color> _upcomingColors = [];
  GameState _state = GameState.paused;
  int _score = 0;
  int _lines = 0;
  Timer? _timer;
  Timer? _lockTimer;
  Timer? _clockTimer;
  final _stopwatch = Stopwatch();
  final _focusNode = FocusNode();
  final _rand = Random();
  int _seed = 0;
  late PieceBag _pieceBag;
  ReplayRecorder? _recorder;
  Replay? _lastReplay;
  int _cavityCharges = 1;
  int _speedBoost = 0;
  List<PieceCell> _lockedCells = const [];
  List<int> _clearingRows = const [];
  int _toastSeq = 0;
  final Map<int, ToastData> _toasts = {};
  int _combo = -1;
  int _backToBack = 0;
  int _runFusions = 0;
  int _runTetrises = 0;
  int _runBestCombo = 0;
  int _runBestBackToBack = 0;
  int _runMirrorUses = 0;
  int _runCavityFills = 0;
  bool _wasInDanger = false;
  bool _showingCountdown = false;
  int _countdownValue = 3;
  Timer? _countdownTimer;
  int _lockResets = 0;
  bool _holdUsed = false;
  bool _resolvingLock = false;

  /// The mirrored state the last piece actually settled into (kept in sync
  /// on every successful Mirror toggle, see [_mirrorActive]) -- each newly
  /// spawned piece starts in this same orientation instead of always
  /// resetting to unmirrored, so a run of same-colored triangles doesn't
  /// require re-mirroring every single piece.
  bool _lastMirrored = false;

  /// True once [EndCondition.boardCleared] has fired — distinguishes a
  /// Daily Challenge win from the ordinary top-out loss that [_endGame]
  /// otherwise represents, for the results screen and [DailyChallengeService].
  bool _challengeCleared = false;

  /// True from the moment a run ends until [_finishGame]'s persistence/
  /// analytics work (and any pre-dialog beat) completes — guards against
  /// the game's own instant-restart shortcuts (Space, the mobile Play
  /// button) firing [_startGame] while that async tail is still in flight,
  /// which would reset `_score`/`_lines`/`_lastReplay` out from under the
  /// still-running submission and mislabel/drop it. Cleared before the
  /// Results dialog opens, since Play Again from inside that dialog is a
  /// legitimate restart, not a race.
  bool _finishingGame = false;

  /// Exposed for a future "share replay" surface (docs/ROADMAP.md Phase 3+);
  /// not consumed anywhere yet.
  Replay? get lastReplay => _lastReplay;

  GameModeConfig get cfg => widget.mode.config;
  int get _level => 1 + (_lines ~/ 10);
  Duration get _tickSpeed => cfg.speedCurve(_level, _speedBoost);
  double get _scoreMultiplier => 1 + _speedBoost * 0.15;
  bool get _canAcceptInput =>
      _state == GameState.playing &&
      !_resolvingLock &&
      // Input unblocks the instant the countdown hits "GO!" (countdownValue
      // 0) rather than waiting out that whole displayed second too --
      // gravity/the clock still don't start until _beginRun fires a beat
      // later, but there's no reason to make the player wait through a
      // second full second of a dead control scheme after being told "GO!".
      !(_showingCountdown && _countdownValue > 0) &&
      _active != null;
  bool get _canSpeedUp =>
      cfg.hasManualSpeedBoost &&
      _speedBoost < _maxSpeedBoost &&
      cfg.speedCurve(_level, _speedBoost + 1) < _tickSpeed;

  /// A countdown/elapsed readout for Sprint's line target and Ultra's time
  /// limit — null for every other mode, so the HUD only shows it when it's
  /// meaningful (docs/GDD.md SS5).
  String? get _clockDisplay {
    if (cfg.timeLimit != null) {
      final remaining = cfg.timeLimit! - _stopwatch.elapsed;
      return _formatDuration(remaining.isNegative ? Duration.zero : remaining);
    }
    if (cfg.lineTarget != null) {
      final left = (cfg.lineTarget! - _lines).clamp(0, cfg.lineTarget!);
      return '$left lines left · ${_formatDuration(_stopwatch.elapsed)}';
    }
    return null;
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.highScores.addListener(_onHighScoresChanged);
    widget.settings.addListener(_onSettingsChanged);
    widget.theme.addListener(_onThemeChanged);
    _resetBoard();
    _startGame();
    if (!widget.settings.hasSeenTutorial) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showTutorial());
    }
  }

  Future<void> _showTutorial() async {
    if (!mounted) return;
    _setPaused(true);
    var finishedAll = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => TutorialOverlay(
        reduceMotion: widget.settings.reduceMotion,
        onDone: () {
          finishedAll = true;
          Navigator.of(dialogContext).pop();
        },
        onSkip: () => Navigator.of(dialogContext).pop(),
      ),
    );
    unawaited(widget.settings.setHasSeenTutorial(true));
    // Only players who actually finish the walkthrough (not Skip) go on to
    // the hands-on level -- practice on real controls/mechanics before a
    // real run starts.
    if (finishedAll && mounted) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const TutorialLevelScreen()));
    }
    if (mounted) _setPaused(false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.highScores.removeListener(_onHighScoresChanged);
    widget.settings.removeListener(_onSettingsChanged);
    widget.theme.removeListener(_onThemeChanged);
    _timer?.cancel();
    _lockTimer?.cancel();
    _clockTimer?.cancel();
    _countdownTimer?.cancel();
    _focusNode.dispose();
    _anim.dispose();
    // Music is shared across the whole app now (one track for menu and
    // every mode), so leaving this screen shouldn't stop it -- it just
    // keeps playing back on the menu underneath.
    super.dispose();
  }

  void _onHighScoresChanged() {
    if (mounted) setState(() {});
  }

  void _onSettingsChanged() {
    _anim.reduceMotion = widget.settings.reduceMotion;
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  /// Re-checks the stack's danger-zone state after any board mutation
  /// (lock, cavity fill, soft-floor clear) and fires the warning SFX only
  /// on the rising edge, not on every frame it stays true.
  void _updateDanger() {
    final inDanger = _board.isNearTop();
    if (inDanger && !_wasInDanger) {
      unawaited(widget.audio.play(Sfx.danger));
    }
    _wasInDanger = inDanger;
    _anim.setDanger(inDanger);
  }

  Future<void> _haptic(Future<void> Function() feedback) async {
    if (!widget.settings.hapticsEnabled) return;
    await feedback();
  }

  void _recordInput(ReplayInputType type) {
    _recorder?.record(type, _stopwatch.elapsedMilliseconds);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _state == GameState.playing) {
      _setPaused(true);
    } else if (state == AppLifecycleState.resumed &&
        _state == GameState.paused &&
        _showingCountdown) {
      // Backgrounding mid-countdown is the only way to reach "paused" while
      // _showingCountdown is true -- manual pause is blocked during it (see
      // _togglePause) -- so there's no Pause Menu button to resume from
      // (build() only shows one once the countdown is done). Pick the
      // countdown back up automatically instead of stranding the player on
      // a frozen "3" forever.
      _setPaused(false);
    }
  }

  void _resetBoard() {
    _board = GameBoard(_config);
    _cavityCharges = cfg.startingCavityCharges;
  }

  void _startGame() {
    if (_finishingGame) return;
    _timer?.cancel();
    _lockTimer?.cancel();
    _clockTimer?.cancel();
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _showingCountdown = false;
    _resetBoard();
    _score = 0;
    _lines = 0;
    _cavityCharges = cfg.startingCavityCharges;
    _speedBoost = 0;
    _state = GameState.playing;
    _resolvingLock = false;
    _challengeCleared = false;
    _toasts.clear();
    _combo = -1;
    _backToBack = 0;
    _runFusions = 0;
    _runTetrises = 0;
    _runBestCombo = 0;
    _runBestBackToBack = 0;
    _runMirrorUses = 0;
    _runCavityFills = 0;
    _wasInDanger = false;
    _anim.resetForNewRun();
    _held = null;
    _heldColor = null;
    _holdUsed = false;
    _lockResets = 0;
    _lastMirrored = false;
    _seed = cfg.useDailySeed
        ? DailyChallengeService.seedForToday()
        : _rand.nextInt(1 << 31);
    _pieceBag = PieceBag(
      random: Random(_seed),
      pieces: cfg.pieceNames != null ? Pieces.byNames(cfg.pieceNames!) : null,
    );
    _recorder = ReplayRecorder(seed: _seed, mode: widget.mode);
    _lastReplay = null;
    _upcoming = _pieceBag.takeMany(_previewCount);
    _upcomingColors = List.generate(
      _upcoming.length,
      (_) => _randomPieceColor(),
    );
    if (cfg.startsPrefilled) {
      // Same seed as the piece bag, but its own Random instance — the two
      // draw from independent streams so puzzle-layout generation can't
      // perturb piece order (or vice versa) despite sharing a day-seed.
      final puzzleRandom = Random(_seed);
      final palette = widget.theme.current.pieceColors.values.toList();
      _board.seedPuzzle(
        puzzleRandom,
        (kind, tri) => resolveCellColor(
          mode: widget.settings.pieceColorMode,
          themedColor: palette[puzzleRandom.nextInt(palette.length)],
          kind: kind,
          tri: tri,
        ),
      );
    }
    unawaited(widget.audio.playMusic(MusicTrack.forMode(widget.mode)));
    unawaited(widget.live.analytics.gameStart(widget.mode));
    _spawnPiece();
    // Timed modes (and the puzzle board, so the player gets a moment to
    // survey it) get a "Ready? 3-2-1-GO" beat before the clock/gravity
    // starts — otherwise they'd already be running while the player is
    // still getting oriented. Skipped on the very first-ever launch, where
    // the tutorial overlay already provides that pause.
    final needsCountdown =
        widget.settings.hasSeenTutorial &&
        (cfg.timeLimit != null ||
            cfg.lineTarget != null ||
            cfg.startsPrefilled);
    if (needsCountdown) {
      _beginReadyCountdown();
    } else {
      _beginRun();
    }
    setState(() {});
  }

  /// Starts the gravity timer, the run stopwatch, and (for timed modes) the
  /// HUD clock ticker — split out of [_startGame] so a ready countdown can
  /// delay all three without duplicating their setup.
  void _beginRun() {
    _stopwatch
      ..reset()
      ..start();
    if (cfg.timeLimit != null || cfg.lineTarget != null) {
      _clockTimer = Timer.periodic(
        const Duration(milliseconds: 200),
        (_) => _onClockTick(),
      );
    }
    _restartTimer();
  }

  void _beginReadyCountdown() {
    _showingCountdown = true;
    _countdownValue = 3; // renders as 3, 2, 1, then GO! at 0.
    _armCountdownTimer();
  }

  /// Starts (or resumes, after a pause suspended it) the ready-countdown
  /// ticker from the current [_countdownValue] -- split out of
  /// [_beginReadyCountdown] so [_setPaused] can re-arm it without resetting
  /// the count back to 3.
  void _armCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_countdownValue == 0) {
        _countdownTimer?.cancel();
        _countdownTimer = null;
        _showingCountdown = false;
        _beginRun();
      } else {
        _countdownValue--;
      }
      setState(() {});
    });
  }

  void _onClockTick() {
    if (_state != GameState.playing) return;
    if (cfg.timeLimit != null && _stopwatch.elapsed >= cfg.timeLimit!) {
      _endGame();
      return;
    }
    setState(() {});
  }

  void _restartTimer() {
    _timer?.cancel();
    if (_state != GameState.playing) return;
    _timer = Timer.periodic(_tickSpeed, (_) {
      if (_state == GameState.playing) {
        _tick();
      }
    });
  }

  int _scaledScore(int base) => (base * _scoreMultiplier).round();

  void _fillCavities() {
    if (!_canAcceptInput || !cfg.hasCavityFiller || _cavityCharges <= 0) {
      return;
    }
    if (_board.fillLowestCavity(
      colorForFill: (fillTri, existing) => resolveCellColor(
        mode: widget.settings.pieceColorMode,
        themedColor: existing,
        kind: CellKind.tri,
        tri: fillTri,
      ),
    )) {
      _recordInput(ReplayInputType.cavityFill);
      _cavityCharges--;
      _runCavityFills++;
      unawaited(widget.audio.play(Sfx.cavityFill));
      unawaited(widget.live.analytics.cavityFillUsed());
      final cleared = _detectFullRows();
      if (cleared.isNotEmpty) {
        _collapseRows(cleared);
        final points = _scaledScore(_pointsForLines(cleared.length));
        _score += points;
        _lines += cleared.length;
        _cavityCharges += cleared.length;
        _combo++;
        _reconcileActiveAfterBoardMutation();
        _showToast('POWER CLEAR +$points', Colors.amberAccent);
        unawaited(_haptic(HapticFeedback.mediumImpact));
      }
      _updateDanger();
      if (cfg.lineTarget != null && _lines >= cfg.lineTarget!) {
        _endGame();
        setState(() {});
        return;
      }
      if (cfg.endCondition == EndCondition.boardCleared && _board.isEmpty) {
        _challengeCleared = true;
        _endGame();
        setState(() {});
        return;
      }
      _restartTimer();
      setState(() {});
    }
  }

  void _speedUp() {
    if (!_canAcceptInput || !_canSpeedUp) return;
    _recordInput(ReplayInputType.speedUp);
    _speedBoost++;
    _restartTimer();
    _showToast(
      'RISK x${_scoreMultiplier.toStringAsFixed(2)}',
      Colors.orangeAccent,
    );
    unawaited(_haptic(HapticFeedback.selectionClick));
    setState(() {});
  }

  int _pointsForLines(int cleared) {
    switch (cleared) {
      case 1:
        return 100 * _level;
      case 2:
        return 300 * _level;
      case 3:
        return 500 * _level;
      case 4:
        return 800 * _level;
      default:
        return 0;
    }
  }

  void _tick() {
    if (!_canAcceptInput) return;
    final next = _active!.copyWith(row: _active!.row + 1);
    final moved = _attemptMove(
      next,
      duration: _tickSpeed,
      curve: Curves.linear,
    );
    if (!moved) {
      _scheduleLock();
    }
  }

  void _scheduleLock() {
    if (!_canAcceptInput || _lockTimer != null) return;
    _lockTimer = Timer(const Duration(milliseconds: 450), () {
      _lockTimer = null;
      if (!_canAcceptInput) return;
      final below = _active!.copyWith(row: _active!.row + 1);
      if (_canPlace(below)) return;
      unawaited(_lockPiece());
    });
  }

  void _cancelLock() {
    _lockTimer?.cancel();
    _lockTimer = null;
  }

  int _pieceWidth(PieceDefinition def) {
    final rotation = def.rotations.first;
    final maxCol = rotation.map((c) => c.col).reduce(max);
    final minCol = rotation.map((c) => c.col).reduce(min);
    return maxCol - minCol + 1;
  }

  /// Picks a color unrelated to any piece's identity, for
  /// [PieceColorMode.random] — drawn from the current theme's own palette so
  /// it still looks intentional, just shuffled away from shape.
  Color _randomPieceColor() {
    final palette = widget.theme.current.pieceColors.values.toList();
    return palette[_rand.nextInt(palette.length)];
  }

  /// Resolves the color a piece of [type] should render as right now, given
  /// [instanceColor] (its previously-assigned random color, if any) —
  /// centralizing the mode branch so every render/lock site agrees.
  Color _resolveThemedColor(PieceDefinition type, Color? instanceColor) {
    if (widget.settings.pieceColorMode == PieceColorMode.random) {
      return instanceColor ?? _randomPieceColor();
    }
    return widget.theme.current.colorFor(type.name);
  }

  /// Resolved colors for the next/hold previews, matching whatever each
  /// piece will actually fall as — see [_resolveThemedColor].
  List<Color> get _resolvedUpcomingColors => [
    for (int i = 0; i < _upcoming.length; i++)
      _resolveThemedColor(
        _upcoming[i],
        i < _upcomingColors.length ? _upcomingColors[i] : null,
      ),
  ];

  Color? get _resolvedHeldColor =>
      _held == null ? null : _resolveThemedColor(_held!, _heldColor);

  void _spawnPiece({
    PieceDefinition? forcedType,
    Color? forcedColor,
    bool resetHold = true,
  }) {
    final type = forcedType ?? _upcoming.removeAt(0);
    final color = forcedType != null
        ? (forcedColor ?? _randomPieceColor())
        : _upcomingColors.removeAt(0);
    if (forcedType == null) {
      _upcoming.add(_pieceBag.take());
      _upcomingColors.add(_randomPieceColor());
    }
    _activeColor = color;
    _cancelLock();
    _lockResets = 0;
    if (resetHold) _holdUsed = false;
    final width = _pieceWidth(type);
    final spawnCol = ((_config.cols - width) ~/ 2).clamp(0, _config.cols - 1);
    _active = ActivePiece(
      type: type,
      row: 0,
      col: spawnCol,
      mirrored: _lastMirrored,
    );
    _anim.snapPiece(Offset(_active!.col.toDouble(), _active!.row.toDouble()));
    if (!_canPlace(_active!)) {
      if (cfg.softFloor) {
        _board.clearTopRows(_softFloorClearRows);
        _showToast('CLEARED FOR SPACE', Colors.cyanAccent);
        _updateDanger();
        if (!_canPlace(_active!)) {
          _endGame();
        }
      } else {
        _endGame();
      }
    }
  }

  void _reconcileActiveAfterBoardMutation() {
    if (_active == null || _canPlace(_active!)) return;
    for (int offset = 1; offset < _config.rows; offset++) {
      final candidate = _active!.copyWith(row: _active!.row - offset);
      if (_canPlace(candidate)) {
        _active = candidate;
        _anim.snapPiece(
          Offset(candidate.col.toDouble(), candidate.row.toDouble()),
        );
        return;
      }
    }
    _endGame();
  }

  void _endGame() {
    if (_state == GameState.over) return;
    _state = GameState.over;
    _active = null;
    _timer?.cancel();
    _clockTimer?.cancel();
    _stopwatch.stop();
    _cancelLock();
    _resolvingLock = false;
    _lastReplay = _recorder?.build();
    unawaited(_finishGame());
  }

  Set<String> _unlockedAchievementIds() {
    final ctx = AchievementContext(
      stats: widget.stats,
      highScores: widget.highScores,
      dailyChallenge: widget.dailyChallenge,
    );
    return Achievement.all
        .where((a) => a.isUnlocked(ctx))
        .map((a) => a.id)
        .toSet();
  }

  /// Runs one local-persistence write, isolating its failure so a thrown
  /// exception (corrupt prefs, a platform-channel hiccup) can't silently
  /// prevent the *other* independent writes in [_finishGame] from running.
  Future<void> _tryPersist(String label, Future<void> Function() action) async {
    try {
      await action();
    } catch (e, st) {
      debugPrint('_finishGame: $label failed: $e\n$st');
    }
  }

  /// Persists the run, works out what (if anything) just unlocked, and
  /// shows the results screen. Split from [_endGame] so the achievement
  /// before/after diff can actually await the local persistence calls
  /// (previously fire-and-forget) before comparing — the live-service
  /// calls stay fire-and-forget since nothing in the UI depends on them.
  Future<void> _finishGame() async {
    _finishingGame = true;
    var isNewBest = false;
    var newlyUnlocked = const <Achievement>[];
    try {
      final priorBest = widget.highScores.bestScore(widget.mode);
      isNewBest = _score > priorBest;
      final formRatio = priorBest == 0
          ? (_score > 0 ? 1.0 : 0.0)
          : (_score / priorBest).clamp(0.0, 1.0);
      final beforeAchievements = _unlockedAchievementIds();

      // Each write is independent local persistence (SharedPreferences) —
      // wrapped separately so a failure in one (corrupt prefs, a platform-
      // channel hiccup) can't silently skip the rest, which previously
      // included `stats.recordRun` since it ran last.
      await _tryPersist(
        'submitRun',
        () => widget.highScores.submitRun(
          widget.mode,
          score: _score,
          level: _level,
        ),
      );
      if (cfg.lineTarget != null && _lines >= cfg.lineTarget!) {
        await _tryPersist(
          'submitTime',
          () => widget.highScores.submitTime(
            widget.mode,
            _stopwatch.elapsedMilliseconds,
          ),
        );
      }
      if (cfg.useDailySeed) {
        await _tryPersist(
          'recordResult',
          () => widget.dailyChallenge.recordResult(
            _score,
            cleared: _challengeCleared,
          ),
        );
      }
      await _tryPersist(
        'recordRun',
        () => widget.stats.recordRun(
          mode: widget.mode,
          linesCleared: _lines,
          tetrises: _runTetrises,
          fusionBonuses: _runFusions,
          bestCombo: _runBestCombo,
          bestBackToBack: _runBestBackToBack,
          playtimeMs: _stopwatch.elapsedMilliseconds,
          mirrorUses: _runMirrorUses,
          cavityFills: _runCavityFills,
          maxSpeedBoost: _speedBoost,
          formRatio: formRatio,
        ),
      );

      final afterAchievements = _unlockedAchievementIds();
      newlyUnlocked = Achievement.all
          .where(
            (a) =>
                afterAchievements.contains(a.id) &&
                !beforeAchievements.contains(a.id),
          )
          .toList();

      // Everything above only touches persistence services, never `setState`
      // or `_anim` — safe to run after dispose. Everything below does, so it
      // needs this widget to still be alive.
      if (!mounted) return;

      if (isNewBest) {
        _showToast('NEW BEST!', Colors.amberAccent);
        unawaited(widget.audio.play(Sfx.newBest));
        unawaited(_haptic(HapticFeedback.heavyImpact));
        _anim.triggerCelebration();
        for (int c = 0; c < _config.cols; c += 2) {
          _anim.burst(Offset(c + 0.5, 0), Colors.amberAccent, count: 8);
        }
      } else {
        unawaited(widget.audio.play(Sfx.gameOver));
        unawaited(
          _haptic(
            newlyUnlocked.isNotEmpty
                ? HapticFeedback.mediumImpact
                : HapticFeedback.lightImpact,
          ),
        );
      }

      unawaited(
        widget.live.analytics.gameOver(
          mode: widget.mode,
          score: _score,
          level: _level,
          lines: _lines,
          durationMs: _stopwatch.elapsedMilliseconds,
          isNewBest: isNewBest,
        ),
      );
      unawaited(
        widget.live.backup.pushSaves(
          highScores: widget.highScores,
          stats: widget.stats,
        ),
      );
      final replay = _lastReplay;
      if (replay != null && _score > 0) {
        unawaited(
          widget.live.leaderboard.submitScore(
            mode: widget.mode,
            score: _score,
            level: _level,
            replay: replay,
            isDaily: cfg.useDailySeed,
          ),
        );
      }

      setState(() {});
      if (isNewBest) {
        // A beat to let the particle shower/flash actually play before the
        // modal dims everything behind it.
        await Future.delayed(const Duration(milliseconds: 550));
        if (!mounted) return;
      }
      if (newlyUnlocked.isNotEmpty) {
        // Timed to land right as the Results dialog reveals the unlocked
        // achievement list, not stacked on top of the game-over/new-best cue.
        unawaited(widget.audio.play(Sfx.achievementUnlock));
      }
    } finally {
      // Cleared before the dialog opens (not in a wrapper around the whole
      // method) so "Play Again" tapped from inside that dialog is never
      // mistaken for the race this flag exists to prevent.
      _finishingGame = false;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ResultsScreen(
        mode: widget.mode,
        score: _score,
        level: _level,
        lines: _lines,
        isNewBest: isNewBest,
        challengeCleared: _challengeCleared,
        durationMs: _stopwatch.elapsedMilliseconds,
        fusions: _runFusions,
        tetrises: _runTetrises,
        mirrorUses: _runMirrorUses,
        cavityFills: _runCavityFills,
        newlyUnlocked: newlyUnlocked,
        onPlayAgain: () {
          Navigator.of(dialogContext).pop();
          _startGame();
        },
        onShare: () {
          Navigator.of(dialogContext).pop();
          unawaited(_shareResult());
        },
        onMenu: () {
          Navigator.of(dialogContext).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Future<void> _shareResult() async {
    unawaited(widget.audio.play(Sfx.menuTap));
    final text = cfg.lineTarget != null
        ? "I cleared ${cfg.lineTarget} lines in ${cfg.label} in "
              '${_formatDuration(_stopwatch.elapsed)} on What The Tetris! \u{1F53A}'
        : 'I scored $_score points (Level $_level) in ${cfg.label} on '
              'What The Tetris! \u{1F53A}';
    await Share.share('$text\nhttps://allingaming.github.io/whatthetetris/');
  }

  ActivePiece? get _ghostPiece {
    if (_active == null) return null;
    var ghost = _active!;
    while (true) {
      final next = ghost.copyWith(row: ghost.row + 1);
      if (!_canPlace(next)) return ghost;
      ghost = next;
    }
  }

  bool _canPlace(ActivePiece piece) => _board.canPlace(piece);

  bool _attemptMove(
    ActivePiece next, {
    required Duration duration,
    required Curve curve,
    bool manual = false,
  }) {
    if (!_canPlace(next)) return false;
    _active = next;
    _anim.retargetPiece(
      Offset(next.col.toDouble(), next.row.toDouble()),
      duration: duration,
      curve: curve,
    );
    if (manual && _lockTimer != null) {
      final below = next.copyWith(row: next.row + 1);
      if (_canPlace(below)) {
        _cancelLock();
      } else if (_lockResets < 15) {
        _lockResets++;
        _cancelLock();
        _scheduleLock();
      }
    }
    setState(() {});
    return true;
  }

  void _mirrorActive() {
    if (!_canAcceptInput) return;
    final toggled = _active!.copyWith(mirrored: !_active!.mirrored);
    final moved = _attemptMove(
      toggled,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOutCubic,
      manual: true,
    );
    if (moved) {
      _lastMirrored = toggled.mirrored;
      _recordInput(ReplayInputType.mirror);
      _runMirrorUses++;
      unawaited(_haptic(HapticFeedback.selectionClick));
      unawaited(widget.audio.play(Sfx.mirror));
      unawaited(widget.live.analytics.mirrorUsed());
    }
  }

  bool _tryMove({int dx = 0, int dy = 0}) {
    if (!_canAcceptInput) return false;
    final next = _active!.copyWith(
      row: _active!.row + dy,
      col: _active!.col + dx,
    );
    return _attemptMove(
      next,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOutCubic,
      manual: true,
    );
  }

  bool _tryRotate(int rotDelta) {
    if (!_canAcceptInput) return false;
    final rotCount = _active!.type.rotations.length;
    final rawRot = (_active!.rotation + rotDelta) % rotCount;
    final nextRot = rawRot < 0 ? rawRot + rotCount : rawRot;
    const kicks = [0, -1, 1, -2, 2];
    for (final dx in kicks) {
      final next = _active!.copyWith(col: _active!.col + dx, rotation: nextRot);
      if (_attemptMove(
        next,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOutCubic,
        manual: true,
      )) {
        unawaited(_haptic(HapticFeedback.selectionClick));
        unawaited(widget.audio.play(Sfx.rotate));
        return true;
      }
    }
    final floorKick = _active!.copyWith(
      row: _active!.row - 1,
      rotation: nextRot,
    );
    final moved = _attemptMove(
      floorKick,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOutCubic,
      manual: true,
    );
    if (moved) unawaited(widget.audio.play(Sfx.rotate));
    return moved;
  }

  // Named so both the keyboard/desktop side panel and the mobile touch
  // D-pad can reference the exact same callbacks.
  void _moveLeft() {
    if (_tryMove(dx: -1)) {
      _recordInput(ReplayInputType.moveLeft);
      unawaited(widget.audio.play(Sfx.move));
    }
  }

  void _moveRight() {
    if (_tryMove(dx: 1)) {
      _recordInput(ReplayInputType.moveRight);
      unawaited(widget.audio.play(Sfx.move));
    }
  }

  void _softDrop() {
    if (_tryMove(dy: 1)) {
      _recordInput(ReplayInputType.softDrop);
      _score += _scaledScore(1);
      unawaited(widget.audio.play(Sfx.softDrop));
      setState(() {});
    }
  }

  void _rotateLeft() => _tryRotate(-1);
  void _rotateRight() => _tryRotate(1);

  void _holdActive() {
    if (!_canAcceptInput || _holdUsed) return;
    _recordInput(ReplayInputType.hold);
    final outgoing = _active!.type;
    final outgoingColor = _activeColor;
    final incoming = _held;
    final incomingColor = _heldColor;
    _held = outgoing;
    _heldColor = outgoingColor;
    _active = null;
    _holdUsed = true;
    _spawnPiece(
      forcedType: incoming,
      forcedColor: incomingColor,
      resetHold: false,
    );
    unawaited(_haptic(HapticFeedback.selectionClick));
    unawaited(widget.audio.play(Sfx.move));
    setState(() {});
  }

  void _hardDrop() {
    if (!_canAcceptInput) return;
    _recordInput(ReplayInputType.hardDrop);
    _cancelLock();
    int steps = 0;
    var candidate = _active!;
    while (true) {
      final next = candidate.copyWith(row: candidate.row + 1);
      if (!_canPlace(next)) break;
      candidate = next;
      steps++;
    }
    _active = candidate;
    _anim.retargetPiece(
      Offset(candidate.col.toDouble(), candidate.row.toDouble()),
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeIn,
    );
    _anim.triggerShake(intensity: 0.4 + (steps / 15).clamp(0.0, 1.2));
    if (steps >= 3) {
      final center = candidate.cellsOnBoard().first;
      final origin = Offset(center.col + 0.5, center.row + 0.5);
      _anim.burst(
        origin,
        _resolveThemedColor(candidate.type, _activeColor),
        count: 10,
      );
      _anim.triggerImpactRing(origin);
    }
    _score += _scaledScore(steps * 2);
    unawaited(_haptic(HapticFeedback.mediumImpact));
    unawaited(widget.audio.play(Sfx.hardDrop));
    setState(() {});
    unawaited(_lockPiece());
  }

  // Touch board gestures, layered on top of the D-pad/side-panel buttons
  // rather than replacing them: drag horizontally to slide the piece
  // (locked to whichever axis the drag started in, so a horizontal slide
  // can't also register as a soft drop), drag down to soft-drop, and a
  // fast downward fling hard-drops instead. Tap rotates, long-press holds.
  // All the actual actions below are self-guarded by [_canAcceptInput], so
  // these handlers can call them unconditionally, same as [_handleKey].
  static const double _dragLockThreshold = 8.0;
  static const double _hardDropFlingVelocity = 1200.0;

  double _cellSize = 1;
  double _dragDx = 0;
  double _dragDy = 0;
  bool? _dragHorizontal;

  void _onBoardPanStart(DragStartDetails details) {
    _dragDx = 0;
    _dragDy = 0;
    _dragHorizontal = null;
  }

  void _onBoardPanUpdate(DragUpdateDetails details) {
    _dragDx += details.delta.dx;
    _dragDy += details.delta.dy;
    _dragHorizontal ??=
        (_dragDx.abs() >= _dragLockThreshold ||
            _dragDy.abs() >= _dragLockThreshold)
        ? _dragDx.abs() >= _dragDy.abs()
        : null;

    if (_cellSize <= 0) return;
    if (_dragHorizontal == true) {
      while (_dragDx >= _cellSize) {
        _moveRight();
        _dragDx -= _cellSize;
      }
      while (_dragDx <= -_cellSize) {
        _moveLeft();
        _dragDx += _cellSize;
      }
    } else if (_dragHorizontal == false) {
      while (_dragDy >= _cellSize) {
        _softDrop();
        _dragDy -= _cellSize;
      }
      if (_dragDy < 0) _dragDy = 0; // dragging back up never moves it up
    }
  }

  void _onBoardPanEnd(DragEndDetails details) {
    if (_dragHorizontal == false &&
        details.velocity.pixelsPerSecond.dy > _hardDropFlingVelocity) {
      _hardDrop();
    }
    _dragDx = 0;
    _dragDy = 0;
    _dragHorizontal = null;
  }

  static const _fusionBonusPerCell = 25;
  static const _goldFusionColor = Color(0xFFFFD24C);

  Future<void> _lockPiece() async {
    if (_active == null || _resolvingLock) return;
    _resolvingLock = true;
    _cancelLock();
    final lockedCells = _active!.cellsOnBoard();
    final fusions = _board.countFusions(_active!);
    final themedColor = _resolveThemedColor(_active!.type, _activeColor);
    _board.lock(
      _active!,
      colorForCell: (cell) => resolveCellColor(
        mode: widget.settings.pieceColorMode,
        themedColor: themedColor,
        kind: cell.kind,
        tri: cell.tri,
      ),
    );
    _active = null;
    _lockedCells = lockedCells;
    _anim.lockFlash.forward(from: 0);
    unawaited(widget.audio.play(Sfx.lock));
    setState(() {});

    var fusionPoints = 0;
    if (fusions > 0) {
      fusionPoints = _scaledScore(fusions * _fusionBonusPerCell);
      _score += fusionPoints;
      final center = lockedCells.first;
      _anim.burst(
        Offset(center.col + 0.5, center.row + 0.5),
        _goldFusionColor,
        count: 8,
      );
      _showToast('FUSION x$fusions +$fusionPoints', _goldFusionColor);
      unawaited(widget.audio.play(Sfx.fusionBonus));
      unawaited(widget.live.analytics.fusionBonus(fusions));
      _runFusions++;
    }

    final clearedRows = _detectFullRows();
    if (clearedRows.isNotEmpty) {
      _clearingRows = clearedRows;
      setState(() {});
      await _anim.lineClear.forward(from: 0);
      if (!mounted) return;

      for (final r in clearedRows) {
        for (int c = 0; c < _config.cols; c++) {
          final cell = _board.cells[r][c];
          final color = cell.full ?? cell.bl ?? cell.tr!;
          _anim.burst(Offset(c + 0.5, r + 0.5), color, count: 6);
        }
      }
      if (clearedRows.length >= 3) {
        _anim.triggerShake(intensity: clearedRows.length == 4 ? 1.6 : 1.0);
      }
      unawaited(_haptic(HapticFeedback.heavyImpact));
      unawaited(_playClearSfx(clearedRows.length));
      unawaited(widget.live.analytics.lineClear(clearedRows.length));

      _collapseRows(clearedRows);
      final levelBefore = _level;
      final points = _scaledScore(_pointsForLines(clearedRows.length));
      _score += points;
      _lines += clearedRows.length;
      if (cfg.hasCavityFiller) _cavityCharges += clearedRows.length;
      _clearingRows = const [];
      _combo++;
      _runBestCombo = _runBestCombo > _combo + 1 ? _runBestCombo : _combo + 1;
      if (clearedRows.length == 4) {
        _runTetrises++;
        unawaited(widget.live.analytics.tetrisClear());
      }

      final isHardClear = clearedRows.length == 4 || fusions >= 2;
      var b2bBonus = 0;
      if (isHardClear) {
        if (_backToBack > 0) {
          b2bBonus = (points * 0.5).round();
          _score += b2bBonus;
        }
        _backToBack++;
        _runBestBackToBack = _runBestBackToBack > _backToBack
            ? _runBestBackToBack
            : _backToBack;
      } else {
        _backToBack = 0;
      }

      final accent = Theme.of(context).colorScheme.primary;
      if (clearedRows.length == 4) {
        _showToast('TETRIS!', Colors.amberAccent, big: true);
      } else {
        _showToast('+$points', Colors.white);
      }
      if (b2bBonus > 0) {
        _showToast('BACK-TO-BACK +$b2bBonus', Colors.deepPurpleAccent);
      }
      if (_level > levelBefore) {
        _showToast('LEVEL $_level!', accent);
        unawaited(widget.audio.play(Sfx.levelUp));
        _anim.triggerLevelUp();
      }
      if (_combo > 0) {
        final heat = (_combo / 6).clamp(0.0, 1.0);
        _showToast(
          '${_combo + 1}x COMBO!',
          Color.lerp(accent, Colors.redAccent, heat)!,
          big: _combo >= 2,
        );
        unawaited(widget.audio.play(Sfx.comboTick));
        unawaited(widget.live.analytics.combo(_combo + 1));
        _anim.setComboHeat(heat);
      } else {
        _anim.setComboHeat(0);
      }
    } else {
      _combo = -1;
      _anim.setComboHeat(0);
    }
    _lockedCells = const [];
    _resolvingLock = false;
    _updateDanger();
    // Sprint-style modes end the instant the line target is hit, rather than
    // running on unbounded — Ultra/Chill have their own end conditions
    // (clock tick, top-out) but nothing was checking this one.
    if (cfg.lineTarget != null && _lines >= cfg.lineTarget!) {
      _endGame();
      setState(() {});
      return;
    }
    // Daily Challenge's puzzle board is won the instant it's fully empty —
    // locking a piece always adds fill, so this can only trip via the
    // collapse above wiping out the board's last remaining rows.
    if (cfg.endCondition == EndCondition.boardCleared && _board.isEmpty) {
      _challengeCleared = true;
      _endGame();
      setState(() {});
      return;
    }
    _spawnPiece();
    _restartTimer();
    setState(() {});
  }

  Future<void> _playClearSfx(int lineCount) {
    return widget.audio.play(switch (lineCount) {
      1 => Sfx.clear1,
      2 => Sfx.clear2,
      3 => Sfx.clear3,
      _ => Sfx.clearTetris,
    });
  }

  List<int> _detectFullRows() => _board.detectFullRows();

  void _collapseRows(List<int> rows) => _board.collapseRows(rows);

  void _showToast(String text, Color color, {bool big = false}) {
    final id = _toastSeq++;
    setState(() => _toasts[id] = ToastData(text, color, big: big));
  }

  void _removeToast(int id) {
    setState(() => _toasts.remove(id));
  }

  void _setPaused(bool paused) {
    if (paused && _state == GameState.playing) {
      _timer?.cancel();
      _cancelLock();
      _stopwatch.stop();
      if (_showingCountdown) {
        // Suspend the ready countdown too -- otherwise it keeps firing in
        // the background regardless of pause state and can call _beginRun
        // (starting the stopwatch/clock for real) while still "paused".
        _countdownTimer?.cancel();
        _countdownTimer = null;
      }
      setState(() => _state = GameState.paused);
    } else if (!paused && _state == GameState.paused) {
      setState(() => _state = GameState.playing);
      if (_showingCountdown) {
        _armCountdownTimer(); // resume the ready countdown where it left off
        return;
      }
      _stopwatch.start();
      _restartTimer();
      if (_active != null &&
          !_canPlace(_active!.copyWith(row: _active!.row + 1))) {
        _scheduleLock();
      }
    }
  }

  void _togglePause() {
    if (_state == GameState.over || _showingCountdown) return;
    unawaited(widget.audio.play(Sfx.pause));
    _setPaused(_state == GameState.playing);
  }

  void _pauseOrPlay() {
    if (_state == GameState.over) {
      _startGame();
    } else {
      _togglePause();
    }
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;
    final isRepeat = event is KeyRepeatEvent;
    final key = event.logicalKey;
    if (_state == GameState.over && key == LogicalKeyboardKey.space) {
      _startGame();
      return;
    }
    if (isRepeat &&
        key != LogicalKeyboardKey.arrowLeft &&
        key != LogicalKeyboardKey.arrowRight &&
        key != LogicalKeyboardKey.arrowDown) {
      return;
    }
    switch (key) {
      case LogicalKeyboardKey.arrowLeft:
        _moveLeft();
        break;
      case LogicalKeyboardKey.arrowRight:
        _moveRight();
        break;
      case LogicalKeyboardKey.arrowDown:
        _softDrop();
        break;
      case LogicalKeyboardKey.arrowUp:
      case LogicalKeyboardKey.keyW:
        _rotateRight();
        break;
      case LogicalKeyboardKey.keyQ:
      case LogicalKeyboardKey.keyZ:
        _rotateLeft();
        break;
      case LogicalKeyboardKey.keyM:
        _mirrorActive();
        break;
      case LogicalKeyboardKey.keyC:
      case LogicalKeyboardKey.shiftLeft:
      case LogicalKeyboardKey.shiftRight:
        _holdActive();
        break;
      case LogicalKeyboardKey.space:
        _hardDrop();
        break;
      case LogicalKeyboardKey.keyG:
        _fillCavities();
        break;
      case LogicalKeyboardKey.keyP:
      case LogicalKeyboardKey.escape:
        _togglePause();
        break;
    }
  }

  static const double _mobileBreakpoint = 600;

  Widget _buildBoard(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Center(
      child: AspectRatio(
        aspectRatio: _config.cols / _config.rows,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              _cellSize = constraints.maxWidth / _config.cols;
              return Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: _rotateRight,
                      onLongPress: _holdActive,
                      onPanStart: _onBoardPanStart,
                      onPanUpdate: _onBoardPanUpdate,
                      onPanEnd: _onBoardPanEnd,
                      child: AnimatedBuilder(
                        animation: _anim.shake,
                        builder: (context, child) => Transform.translate(
                          offset: _anim.shakeOffset,
                          child: child,
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.8),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.55),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                              BoxShadow(
                                color: accent.withValues(alpha: 0.30),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                              BoxShadow(
                                color: accent.withValues(alpha: 0.15),
                                blurRadius: 40,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: CustomPaint(
                            painter: BoardPainter(
                              board: _board.cells,
                              active: _active,
                              ghost: _state == GameState.playing
                                  ? _ghostPiece
                                  : null,
                              config: _config,
                              boardRevision: _board.revision,
                              state: _state,
                              lockedCells: _lockedCells,
                              clearingRows: _clearingRows,
                              anim: _anim,
                              theme: widget.theme.current,
                              colorMode: widget.settings.pieceColorMode,
                              activeThemeColor: _active == null
                                  ? Colors.white
                                  : _resolveThemedColor(
                                      _active!.type,
                                      _activeColor,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  for (final entry in _toasts.entries)
                    if (entry.value.big)
                      FloatingToast(
                        key: ValueKey(entry.key),
                        data: entry.value,
                        onDone: () => _removeToast(entry.key),
                      ),
                  if (_showingCountdown) _buildCountdownOverlay(accent),
                  if (_state == GameState.paused && !_showingCountdown)
                    _buildPauseMenu(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCountdownOverlay(Color accent) {
    final isGo = _countdownValue == 0;
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          // Input already unblocks the instant "GO!" shows (see
          // _canAcceptInput) -- drop the opaque dimming here too, so the
          // player can actually see the board react instead of moving
          // blind behind the backdrop for that last second.
          color: isGo ? Colors.transparent : Colors.black54,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            isGo ? 'GO!' : '$_countdownValue',
            key: ValueKey(_countdownValue),
            style: TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.bold,
              color: isGo ? accent : Colors.white,
              shadows: [
                Shadow(
                  color: (isGo ? accent : Colors.white).withValues(alpha: 0.8),
                  blurRadius: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPauseMenu() {
    return PauseMenu(
      modeLabel: cfg.label,
      score: _score,
      level: _level,
      lines: _lines,
      onResume: _togglePause,
      onRestart: _startGame,
      onSettings: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SettingsScreen(
              audio: widget.audio,
              settings: widget.settings,
              theme: widget.theme,
              live: widget.live,
            ),
          ),
        );
      },
      // Ends the run the same way a top-out/time-up/line-target finish
      // does -- persists the score/stats/achievements and shows the normal
      // Results screen (whose own "Menu" button returns here) -- rather
      // than abandoning the run with nothing saved.
      onQuit: _endGame,
    );
  }

  Widget _buildDesktopLayout(BuildContext context, BoxConstraints constraints) {
    final panelWidth = min(260.0, constraints.maxWidth * 0.28);
    return Row(
      children: [
        Expanded(child: _buildBoard(context)),
        GameSidePanel(
          width: panelWidth,
          mode: widget.mode,
          state: _state,
          score: _score,
          lines: _lines,
          level: _level,
          bestScore: widget.highScores.bestScore(widget.mode),
          bestLevel: widget.highScores.bestLevel(widget.mode),
          modeClock: _clockDisplay,
          cavityCharges: _cavityCharges,
          speedBoost: _speedBoost,
          upcoming: _upcoming,
          upcomingColors: _resolvedUpcomingColors,
          nextMirrored: _lastMirrored,
          held: _held,
          heldColor: _resolvedHeldColor,
          theme: widget.theme.current,
          colorMode: widget.settings.pieceColorMode,
          canHold: !_holdUsed,
          canSpeedUp: _canSpeedUp,
          toasts: _toasts,
          onRemoveToast: _removeToast,
          onPauseOrPlay: _pauseOrPlay,
          onRestart: _startGame,
          onMoveLeft: _moveLeft,
          onMoveRight: _moveRight,
          onSoftDrop: _softDrop,
          onHardDrop: _hardDrop,
          onRotateLeft: _rotateLeft,
          onRotateRight: _rotateRight,
          onMirror: _mirrorActive,
          onHold: _holdActive,
          onSpeedUp: _speedUp,
          onFillCavities: _fillCavities,
          onMenu: () {
            unawaited(widget.audio.play(Sfx.menuTap));
            _togglePause();
          },
          onShare: _shareResult,
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(child: _buildBoard(context)),
          MobileStatsBar(
            state: _state,
            score: _score,
            lines: _lines,
            level: _level,
            upcoming: _upcoming,
            upcomingColor: _resolvedUpcomingColors.isEmpty
                ? null
                : _resolvedUpcomingColors.first,
            nextMirrored: _lastMirrored,
            theme: widget.theme.current,
            colorMode: widget.settings.pieceColorMode,
            anim: _anim,
            modeClock: _clockDisplay,
            onPauseOrPlay: _pauseOrPlay,
            onMenu: () {
              unawaited(widget.audio.play(Sfx.menuTap));
              _togglePause();
            },
            onShare: _shareResult,
          ),
          TouchDpad(
            enabled: _state == GameState.playing && !_resolvingLock,
            onMoveLeft: _moveLeft,
            onMoveRight: _moveRight,
            onSoftDrop: _softDrop,
            onRotateLeft: _rotateLeft,
            onRotateRight: _rotateRight,
            onMirror: _mirrorActive,
            onHold: _holdActive,
            canHold: !_holdUsed,
            onHardDrop: _hardDrop,
            onFillCavities: cfg.hasCavityFiller ? _fillCavities : null,
            cavityCharges: _cavityCharges,
            onSpeedUp: cfg.hasManualSpeedBoost ? _speedUp : null,
            speedBoost: _speedBoost,
            reduceMotion: widget.settings.reduceMotion,
            handedness: widget.settings.touchHandedness,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return constraints.maxWidth < _mobileBreakpoint
                ? _buildMobileLayout(context)
                : _buildDesktopLayout(context, constraints);
          },
        ),
      ),
    );
  }
}
