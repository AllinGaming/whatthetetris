import 'dart:math';

import 'package:flutter/material.dart';

import '../models/active_piece.dart';
import '../models/board.dart';
import '../models/coop_variant.dart';
import '../models/piece.dart';
import '../models/pieces.dart';
import 'game_board.dart';
import 'piece_bag.dart';
import 'puzzle_speed_bonus.dart';

enum CoopPlayer {
  red,
  blue;

  TriHalf get triangle => this == CoopPlayer.red ? TriHalf.bl : TriHalf.tr;
  Color get color => this == CoopPlayer.red ? duoBlColor : duoTrColor;
  bool get mirrored => this == CoopPlayer.blue;
}

/// Player inputs shared by both cooperative variants. The fixed variant
/// rejects [mirror]; the mirror variant accepts it while preserving each
/// player's red or blue ownership. Cavity fills use separate inventories.
enum CoopAction {
  left,
  right,
  softDrop,
  rotateLeft,
  rotateRight,
  mirror,
  hardDrop,
  fillCavity,
}

class CoopActivePieceState {
  const CoopActivePieceState({
    required this.name,
    required this.rotation,
    required this.row,
    required this.col,
    required this.mirrored,
  });

  factory CoopActivePieceState.fromPiece(ActivePiece piece) =>
      CoopActivePieceState(
        name: piece.type.name,
        rotation: piece.rotation,
        row: piece.row,
        col: piece.col,
        mirrored: piece.mirrored,
      );

  factory CoopActivePieceState.fromJson(
    Map<String, dynamic> json, {
    required CoopPlayer player,
  }) => CoopActivePieceState(
    name: json['name'] as String,
    rotation: (json['rotation'] as num).toInt(),
    row: (json['row'] as num).toInt(),
    col: (json['col'] as num).toInt(),
    mirrored: json['mirrored'] as bool? ?? player.mirrored,
  );

  final String name;
  final int rotation;
  final int row;
  final int col;
  final bool mirrored;

  ActivePiece toPiece(CoopPlayer player) => ActivePiece(
    type: Pieces.all.firstWhere((piece) => piece.name == name),
    rotation: rotation,
    row: row,
    col: col,
    mirrored: mirrored,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'rotation': rotation,
    'row': row,
    'col': col,
    'mirrored': mirrored,
  };
}

/// One authoritative gameplay moment carried with a snapshot so both peers
/// render the same score callouts, particles, flashes, and impact feedback.
/// This never touches Firestore; it travels only over the WebRTC data channel.
class CoopEffectState {
  const CoopEffectState({
    required this.id,
    required this.player,
    required this.cellIndexes,
    required this.clearedRows,
    required this.fusionCount,
    required this.fusionPoints,
    required this.linePoints,
    required this.comboCount,
    required this.comboBonus,
    required this.backToBackCount,
    required this.backToBackBonus,
    required this.scoreGain,
    required this.hardDropDistance,
    required this.cavityFill,
  });

  factory CoopEffectState.fromJson(Map<String, dynamic> json) =>
      CoopEffectState(
        id: (json['id'] as num).toInt(),
        player: CoopPlayer.values.firstWhere(
          (value) => value.name == json['player'],
        ),
        cellIndexes: (json['cellIndexes'] as List<dynamic>? ?? const [])
            .map((value) => (value as num).toInt())
            .toList(growable: false),
        clearedRows: (json['clearedRows'] as List<dynamic>? ?? const [])
            .map((value) => (value as num).toInt())
            .toList(growable: false),
        fusionCount: (json['fusionCount'] as num?)?.toInt() ?? 0,
        fusionPoints: (json['fusionPoints'] as num?)?.toInt() ?? 0,
        linePoints: (json['linePoints'] as num?)?.toInt() ?? 0,
        comboCount: (json['comboCount'] as num?)?.toInt() ?? 0,
        comboBonus: (json['comboBonus'] as num?)?.toInt() ?? 0,
        backToBackCount: (json['backToBackCount'] as num?)?.toInt() ?? 0,
        backToBackBonus: (json['backToBackBonus'] as num?)?.toInt() ?? 0,
        scoreGain: (json['scoreGain'] as num?)?.toInt() ?? 0,
        hardDropDistance: (json['hardDropDistance'] as num?)?.toInt() ?? 0,
        cavityFill: json['cavityFill'] as bool? ?? false,
      );

  final int id;
  final CoopPlayer player;
  final List<int> cellIndexes;
  final List<int> clearedRows;
  final int fusionCount;
  final int fusionPoints;
  final int linePoints;
  final int comboCount;
  final int comboBonus;
  final int backToBackCount;
  final int backToBackBonus;
  final int scoreGain;
  final int hardDropDistance;
  final bool cavityFill;

  int get lineCount => clearedRows.length;

  Map<String, dynamic> toJson() => {
    'id': id,
    'player': player.name,
    'cellIndexes': cellIndexes,
    'clearedRows': clearedRows,
    'fusionCount': fusionCount,
    'fusionPoints': fusionPoints,
    'linePoints': linePoints,
    'comboCount': comboCount,
    'comboBonus': comboBonus,
    'backToBackCount': backToBackCount,
    'backToBackBonus': backToBackBonus,
    'scoreGain': scoreGain,
    'hardDropDistance': hardDropDistance,
    'cavityFill': cavityFill,
  };
}

/// Compact host-authoritative state sent over the WebRTC data channel.
/// Locked cells use a bit mask: 1 = red/bottom-left, 2 = blue/top-right,
/// 4 = a full cell, 8 = blue/bottom-left, 16 = red/top-right. The last two
/// bits preserve player color after a Mirror action while older fixed-mode
/// snapshots remain backward compatible.
class CoopGameSnapshot {
  const CoopGameSnapshot({
    this.roundId = 0,
    required this.revision,
    required this.rows,
    required this.cols,
    required this.cells,
    this.variant = CoopVariant.fixed,
    required this.redPiece,
    required this.bluePiece,
    required this.score,
    required this.lines,
    required this.locks,
    required this.fusions,
    required this.combo,
    required this.bestCombo,
    required this.backToBack,
    required this.redLines,
    required this.blueLines,
    required this.effect,
    this.effects = const [],
    required this.redCavityCharges,
    required this.blueCavityCharges,
    required this.gameOver,
    this.puzzleCleared = false,
    this.puzzleSpeedBonus = 0,
  });

  factory CoopGameSnapshot.fromJson(Map<String, dynamic> json) {
    final rows = (json['rows'] as num).toInt();
    final cols = (json['cols'] as num).toInt();
    final cells = (json['cells'] as List<dynamic>)
        .map((value) => (value as num).toInt())
        .toList(growable: false);
    if (cells.length != rows * cols) {
      throw const FormatException('Invalid cooperative board size');
    }
    CoopActivePieceState? parsePiece(Object? value, CoopPlayer player) =>
        value == null
        ? null
        : CoopActivePieceState.fromJson(
            Map<String, dynamic>.from(value as Map<dynamic, dynamic>),
            player: player,
          );

    CoopEffectState? parseEffect(Object? value) => value is Map
        ? CoopEffectState.fromJson(Map<String, dynamic>.from(value))
        : null;
    final legacyEffect = parseEffect(json['effect']);
    final effects = json['effects'] is List
        ? (json['effects'] as List<dynamic>)
              .map(parseEffect)
              .whereType<CoopEffectState>()
              .toList(growable: false)
        : <CoopEffectState>[];
    final effectHistory = effects.isNotEmpty
        ? effects
        : [if (legacyEffect != null) legacyEffect];
    final legacyCavityCharges = (json['cavityCharges'] as num?)?.toInt();
    return CoopGameSnapshot(
      roundId: (json['roundId'] as num?)?.toInt() ?? 0,
      revision: (json['revision'] as num).toInt(),
      rows: rows,
      cols: cols,
      cells: cells,
      variant: CoopVariant.fromName(json['variant']),
      redPiece: parsePiece(json['redPiece'], CoopPlayer.red),
      bluePiece: parsePiece(json['bluePiece'], CoopPlayer.blue),
      score: (json['score'] as num).toInt(),
      lines: (json['lines'] as num).toInt(),
      locks: (json['locks'] as num?)?.toInt() ?? 0,
      fusions: (json['fusions'] as num?)?.toInt() ?? 0,
      combo: (json['combo'] as num?)?.toInt() ?? 0,
      bestCombo: (json['bestCombo'] as num?)?.toInt() ?? 0,
      backToBack: (json['backToBack'] as num?)?.toInt() ?? 0,
      redLines: (json['redLines'] as num?)?.toInt() ?? 0,
      blueLines: (json['blueLines'] as num?)?.toInt() ?? 0,
      effect: effectHistory.isEmpty ? null : effectHistory.last,
      effects: List<CoopEffectState>.unmodifiable(effectHistory),
      redCavityCharges:
          (json['redCavityCharges'] as num?)?.toInt() ??
          legacyCavityCharges ??
          0,
      blueCavityCharges: (json['blueCavityCharges'] as num?)?.toInt() ?? 0,
      gameOver: json['gameOver'] as bool,
      puzzleCleared: json['puzzleCleared'] as bool? ?? false,
      puzzleSpeedBonus: (json['puzzleSpeedBonus'] as num?)?.toInt() ?? 0,
    );
  }

  final int roundId;
  final int revision;
  final int rows;
  final int cols;
  final List<int> cells;
  final CoopVariant variant;
  final CoopActivePieceState? redPiece;
  final CoopActivePieceState? bluePiece;
  final int score;
  final int lines;
  final int locks;
  final int fusions;
  final int combo;
  final int bestCombo;
  final int backToBack;
  final int redLines;
  final int blueLines;
  final CoopEffectState? effect;
  final List<CoopEffectState> effects;
  final int redCavityCharges;
  final int blueCavityCharges;
  final bool gameOver;
  final bool puzzleCleared;
  final int puzzleSpeedBonus;

  bool get roundOver => gameOver || puzzleCleared;

  int get occupiedRowCount {
    var count = 0;
    for (var row = 0; row < rows; row++) {
      final start = row * cols;
      if (cells.skip(start).take(cols).any((cell) => cell != 0)) count++;
    }
    return count;
  }

  int get puzzleRowsRemaining => max(0, occupiedRowCount - 1);

  /// A rematch starts a fresh engine whose revision counter resets. Compare
  /// round generation first so peers accept that new snapshot while still
  /// rejecting genuinely stale updates from an earlier round.
  bool isAtLeastAsNewAs(CoopGameSnapshot other) =>
      roundId > other.roundId ||
      (roundId == other.roundId && revision >= other.revision);

  Config get config => Config(rows: rows, cols: cols);

  ActivePiece? activeFor(CoopPlayer player) {
    final state = player == CoopPlayer.red ? redPiece : bluePiece;
    return state?.toPiece(player);
  }

  int cavityChargesFor(CoopPlayer player) =>
      player == CoopPlayer.red ? redCavityCharges : blueCavityCharges;

  /// Calculates the landing preview from this peer's latest authoritative
  /// snapshot. The screen renders only its local player's result.
  ActivePiece? ghostFor(CoopPlayer player) {
    final active = activeFor(player);
    if (active == null || roundOver) return null;
    var ghost = active;
    final gameBoard = GameBoard(config)..cells = buildBoard();
    final other = activeFor(
      player == CoopPlayer.red ? CoopPlayer.blue : CoopPlayer.red,
    );
    while (true) {
      final next = ghost.copyWith(row: ghost.row + 1);
      if (!gameBoard.canPlace(next) ||
          (other != null && _piecesConflict(next, other))) {
        return ghost;
      }
      ghost = next;
    }
  }

  List<List<CellOccupancy>> buildBoard() => List.generate(rows, (row) {
    return List.generate(cols, (col) {
      final mask = cells[row * cols + col];
      final cell = CellOccupancy();
      if (mask & 4 != 0) {
        cell.full = duoFullColor;
      } else {
        if (mask & 1 != 0) cell.bl = duoBlColor;
        if (mask & 2 != 0) cell.tr = duoTrColor;
        if (mask & 8 != 0) cell.bl = duoTrColor;
        if (mask & 16 != 0) cell.tr = duoBlColor;
      }
      return cell;
    });
  });

  Map<String, dynamic> toJson() => {
    'version': 10,
    'roundId': roundId,
    'revision': revision,
    'rows': rows,
    'cols': cols,
    'cells': cells,
    'variant': variant.name,
    'redPiece': redPiece?.toJson(),
    'bluePiece': bluePiece?.toJson(),
    'score': score,
    'lines': lines,
    'locks': locks,
    'fusions': fusions,
    'combo': combo,
    'bestCombo': bestCombo,
    'backToBack': backToBack,
    'redLines': redLines,
    'blueLines': blueLines,
    'effect': effect?.toJson(),
    'effects': effects.map((value) => value.toJson()).toList(growable: false),
    'redCavityCharges': redCavityCharges,
    'blueCavityCharges': blueCavityCharges,
    'gameOver': gameOver,
    'puzzleCleared': puzzleCleared,
    'puzzleSpeedBonus': puzzleSpeedBonus,
  };
}

/// Runs only on the room host. The blue peer sends inputs while the host
/// applies both players' actions and broadcasts snapshots, avoiding two
/// devices independently resolving simultaneous locks or line clears.
class CoopGameEngine {
  CoopGameEngine({
    required int seed,
    this.variant = CoopVariant.fixed,
    this.roundId = 0,
  }) : _redBag = PieceBag(random: Random(seed ^ 0x52ED), pieces: _coopPieces),
       _blueBag = PieceBag(random: Random(seed ^ 0xB1E0), pieces: _coopPieces),
       board = GameBoard(variant.isPuzzle ? puzzleConfig : config) {
    _redCavityCharges = variant.startingCavityCharges;
    _blueCavityCharges = variant.startingCavityCharges;
    if (variant.isPuzzle) {
      board.seedPuzzle(Random(seed ^ 0x50555A5A), (kind, tri) {
        if (kind == CellKind.full) return duoFullColor;
        return tri == TriHalf.bl ? duoBlColor : duoTrColor;
      });
    }
    _spawn(CoopPlayer.red);
    _spawn(CoopPlayer.blue);
  }

  static const config = Config(rows: 20, cols: 8);
  static const puzzleConfig = Config(rows: 16, cols: 8);
  static final _coopPieces = Pieces.byNames(const [
    'I4',
    'O4',
    'T4',
    'L4',
    'J4',
  ]);

  final PieceBag _redBag;
  final PieceBag _blueBag;
  final GameBoard board;
  final CoopVariant variant;
  final int roundId;
  ActivePiece? _redPiece;
  ActivePiece? _bluePiece;
  bool _redMirrored = false;
  bool _blueMirrored = true;
  int score = 0;
  int lines = 0;
  int locks = 0;
  int fusions = 0;
  int combo = 0;
  int bestCombo = 0;
  int backToBack = 0;
  int redLines = 0;
  int blueLines = 0;
  int _effectId = 0;
  CoopEffectState? _effect;
  final List<CoopEffectState> _recentEffects = [];
  int _redCavityCharges = 1;
  int _blueCavityCharges = 1;
  int revision = 0;
  bool gameOver = false;
  bool puzzleCleared = false;
  int puzzleSpeedBonus = 0;
  bool _puzzleSpeedBonusAwarded = false;

  bool get roundOver => gameOver || puzzleCleared;
  bool get puzzleSpeedBonusAwarded => _puzzleSpeedBonusAwarded;

  /// Applies the host's elapsed-time award exactly once after a Puzzle win.
  /// It becomes part of the authoritative snapshot, so both peers finish
  /// with the same score without any extra database writes.
  void awardPuzzleSpeedBonus(Duration elapsed) {
    if (!variant.isPuzzle || !puzzleCleared || _puzzleSpeedBonusAwarded) {
      return;
    }
    _puzzleSpeedBonusAwarded = true;
    puzzleSpeedBonus = PuzzleSpeedBonus.forElapsed(elapsed);
    score += puzzleSpeedBonus;
    revision++;
  }

  ActivePiece? activeFor(CoopPlayer player) =>
      player == CoopPlayer.red ? _redPiece : _bluePiece;

  int cavityChargesFor(CoopPlayer player) =>
      player == CoopPlayer.red ? _redCavityCharges : _blueCavityCharges;

  void _setCavityCharges(CoopPlayer player, int value) {
    if (player == CoopPlayer.red) {
      _redCavityCharges = value;
    } else {
      _blueCavityCharges = value;
    }
  }

  void _addCavityCharges(CoopPlayer player, int value) {
    _setCavityCharges(player, cavityChargesFor(player) + value);
  }

  void _setActive(CoopPlayer player, ActivePiece? piece) {
    if (player == CoopPlayer.red) {
      _redPiece = piece;
    } else {
      _bluePiece = piece;
    }
  }

  PieceBag _bagFor(CoopPlayer player) =>
      player == CoopPlayer.red ? _redBag : _blueBag;

  CoopPlayer _other(CoopPlayer player) =>
      player == CoopPlayer.red ? CoopPlayer.blue : CoopPlayer.red;

  bool applyAction(CoopPlayer player, CoopAction action) {
    if (roundOver) return false;
    if (action == CoopAction.fillCavity) return _fillCavity(player);
    if (activeFor(player) == null) return false;
    return switch (action) {
      CoopAction.left => _move(player, dx: -1),
      CoopAction.right => _move(player, dx: 1),
      CoopAction.softDrop => _softDrop(player),
      CoopAction.rotateLeft => _rotate(player, -1),
      CoopAction.rotateRight => _rotate(player, 1),
      CoopAction.mirror => variant.allowsMirror && _mirror(player),
      CoopAction.hardDrop => _hardDrop(player),
      CoopAction.fillCavity => false,
    };
  }

  bool _fillCavity(CoopPlayer player) {
    if (cavityChargesFor(player) <= 0) return false;
    final filled = board.fillLowestCavity(
      colorForFill: (fillTri, _) =>
          fillTri == TriHalf.bl ? duoBlColor : duoTrColor,
    );
    if (filled == null) return false;

    final scoreBefore = score;
    _addCavityCharges(player, -1);
    final fullRows = board.detectFullRows();
    var award = const _CoopClearAward();
    if (fullRows.isNotEmpty) {
      award = _awardClear(player, fullRows, fusionCount: 0);
      board.collapseRows(fullRows);
      // Exactly one recharge per line, awarded only to the player whose
      // action completed it rather than duplicated into both inventories.
      _shiftBothAfterClear(fullRows);
      _completePuzzleIfReady();
    }
    _recordEffect(
      CoopEffectState(
        id: ++_effectId,
        player: player,
        cellIndexes: [filled.row * config.cols + filled.col],
        clearedRows: List<int>.unmodifiable(fullRows),
        fusionCount: 0,
        fusionPoints: 0,
        linePoints: award.linePoints,
        comboCount: combo,
        comboBonus: award.comboBonus,
        backToBackCount: backToBack,
        backToBackBonus: award.backToBackBonus,
        scoreGain: score - scoreBefore,
        hardDropDistance: 0,
        cavityFill: true,
      ),
    );
    revision++;
    return true;
  }

  bool tick() {
    if (roundOver) return false;
    var changed = _step(CoopPlayer.red);
    if (!roundOver) changed = _step(CoopPlayer.blue) || changed;
    return changed;
  }

  bool _step(CoopPlayer player) {
    final piece = activeFor(player);
    if (piece == null) return false;
    final next = piece.copyWith(row: piece.row + 1);
    if (_canPlace(player, next)) {
      _setActive(player, next);
      revision++;
      return true;
    }
    _lock(player);
    return true;
  }

  bool _move(CoopPlayer player, {int dx = 0, int dy = 0}) {
    final piece = activeFor(player)!;
    final next = piece.copyWith(row: piece.row + dy, col: piece.col + dx);
    if (!_canPlace(player, next)) return false;
    _setActive(player, next);
    revision++;
    return true;
  }

  bool _softDrop(CoopPlayer player) {
    if (_move(player, dy: 1)) {
      score += 1;
      return true;
    }
    _lock(player);
    return true;
  }

  bool _rotate(CoopPlayer player, int delta) {
    final piece = activeFor(player)!;
    final count = piece.type.rotations.length;
    final raw = (piece.rotation + delta) % count;
    final rotation = raw < 0 ? raw + count : raw;
    for (final kick in const [0, -1, 1, -2, 2]) {
      final next = piece.copyWith(rotation: rotation, col: piece.col + kick);
      if (_canPlace(player, next)) {
        _setActive(player, next);
        revision++;
        return true;
      }
    }
    return false;
  }

  bool _mirror(CoopPlayer player) {
    final piece = activeFor(player)!;
    final next = piece.copyWith(mirrored: !piece.mirrored);
    if (!_canPlace(player, next)) return false;
    _setActive(player, next);
    if (player == CoopPlayer.red) {
      _redMirrored = next.mirrored;
    } else {
      _blueMirrored = next.mirrored;
    }
    revision++;
    return true;
  }

  bool _hardDrop(CoopPlayer player) {
    var piece = activeFor(player)!;
    var distance = 0;
    while (true) {
      final next = piece.copyWith(row: piece.row + 1);
      if (!_canPlace(player, next)) break;
      piece = next;
      distance++;
    }
    _setActive(player, piece);
    _lock(player, hardDropDistance: distance, dropPoints: distance * 2);
    return true;
  }

  void _lock(
    CoopPlayer player, {
    int hardDropDistance = 0,
    int dropPoints = 0,
  }) {
    final piece = activeFor(player);
    if (piece == null || roundOver) return;
    final scoreBefore = score;
    final lockedCells = piece.cellsOnBoard();
    final newFusions = board.countFusions(piece);
    board.lock(piece, colorForCell: (_) => player.color);
    _setActive(player, null);
    locks++;
    fusions += newFusions;
    final fusionPoints = newFusions * 25 * (1 + lines ~/ 10);
    score += dropPoints + 10 + fusionPoints;

    final fullRows = board.detectFullRows();
    var award = const _CoopClearAward();
    if (fullRows.isNotEmpty) {
      award = _awardClear(player, fullRows, fusionCount: newFusions);
      board.collapseRows(fullRows);
      _shiftOtherAfterClear(_other(player), fullRows);
      _completePuzzleIfReady();
    } else {
      combo = 0;
    }
    _recordEffect(
      CoopEffectState(
        id: ++_effectId,
        player: player,
        cellIndexes: [
          for (final cell in lockedCells) cell.row * config.cols + cell.col,
        ],
        clearedRows: List<int>.unmodifiable(fullRows),
        fusionCount: newFusions,
        fusionPoints: fusionPoints,
        linePoints: award.linePoints,
        comboCount: combo,
        comboBonus: award.comboBonus,
        backToBackCount: backToBack,
        backToBackBonus: award.backToBackBonus,
        scoreGain: score - scoreBefore,
        hardDropDistance: hardDropDistance,
        cavityFill: false,
      ),
    );
    revision++;
    if (!roundOver) _spawn(player);
  }

  bool _completePuzzleIfReady() {
    if (!variant.isPuzzle || !board.hasAtMostOneOccupiedRow) return false;
    puzzleCleared = true;
    gameOver = false;
    _redPiece = null;
    _bluePiece = null;
    return true;
  }

  _CoopClearAward _awardClear(
    CoopPlayer player,
    List<int> fullRows, {
    required int fusionCount,
  }) {
    final level = 1 + lines ~/ 10;
    final linePoints = _lineClearScore(fullRows.length) * level;
    lines += fullRows.length;
    if (player == CoopPlayer.red) {
      redLines += fullRows.length;
    } else {
      blueLines += fullRows.length;
    }
    _addCavityCharges(player, fullRows.length);

    combo++;
    bestCombo = max(bestCombo, combo);
    final comboBonus = combo > 1 ? (combo - 1) * 50 * level : 0;

    final hardClear = fullRows.length >= 4 || fusionCount >= 2;
    var backToBackBonus = 0;
    if (hardClear) {
      if (backToBack > 0) backToBackBonus = (linePoints * 0.5).round();
      backToBack++;
    } else {
      backToBack = 0;
    }

    score += linePoints + comboBonus + backToBackBonus;
    return _CoopClearAward(
      linePoints: linePoints,
      comboBonus: comboBonus,
      backToBackBonus: backToBackBonus,
    );
  }

  int _lineClearScore(int count) => switch (count) {
    1 => 100,
    2 => 300,
    3 => 500,
    _ => 800,
  };

  void _recordEffect(CoopEffectState effect) {
    _effect = effect;
    _recentEffects.add(effect);
    if (_recentEffects.length > 4) _recentEffects.removeAt(0);
  }

  void _shiftBothAfterClear(List<int> clearedRows) {
    final red = _redPiece;
    final blue = _bluePiece;
    _redPiece = null;
    _bluePiece = null;
    if (red != null) {
      _redPiece = red;
      _shiftOtherAfterClear(CoopPlayer.red, clearedRows);
    }
    if (blue != null && !gameOver) {
      _bluePiece = blue;
      _shiftOtherAfterClear(CoopPlayer.blue, clearedRows);
    }
  }

  void _shiftOtherAfterClear(CoopPlayer player, List<int> clearedRows) {
    var piece = activeFor(player);
    if (piece == null) return;
    final maxRow = piece.cellsOnBoard().map((cell) => cell.row).reduce(max);
    final shift = clearedRows.where((row) => row > maxRow).length;
    if (shift > 0) piece = piece.copyWith(row: piece.row + shift);
    if (_canPlace(player, piece)) {
      _setActive(player, piece);
      return;
    }
    for (int lift = 1; lift <= clearedRows.length + 2; lift++) {
      final lifted = piece.copyWith(row: piece.row - lift);
      if (_canPlace(player, lifted)) {
        _setActive(player, lifted);
        return;
      }
    }
    gameOver = true;
  }

  void _spawn(CoopPlayer player) {
    final type = _bagFor(player).take();
    final width = type.rotations.first.map((cell) => cell.col).reduce(max) + 1;
    final piece = ActivePiece(
      type: type,
      row: 0,
      col: (config.cols - width) ~/ 2,
      mirrored: player == CoopPlayer.red ? _redMirrored : _blueMirrored,
    );
    _setActive(player, piece);
    if (!_canPlace(player, piece)) gameOver = true;
    revision++;
  }

  bool _canPlace(CoopPlayer player, ActivePiece piece) {
    if (!board.canPlace(piece)) return false;
    final other = activeFor(_other(player));
    if (other == null) return true;
    return !_piecesConflict(piece, other);
  }

  CoopGameSnapshot snapshot() {
    final cells = <int>[];
    for (final row in board.cells) {
      for (final cell in row) {
        var mask = 0;
        if (cell.bl != null) {
          mask |= cell.bl == duoTrColor ? 8 : 1;
        }
        if (cell.tr != null) {
          mask |= cell.tr == duoBlColor ? 16 : 2;
        }
        if (cell.full != null) mask |= 4;
        cells.add(mask);
      }
    }
    return CoopGameSnapshot(
      roundId: roundId,
      revision: revision,
      rows: board.config.rows,
      cols: board.config.cols,
      cells: cells,
      variant: variant,
      redPiece: _redPiece == null
          ? null
          : CoopActivePieceState.fromPiece(_redPiece!),
      bluePiece: _bluePiece == null
          ? null
          : CoopActivePieceState.fromPiece(_bluePiece!),
      score: score,
      lines: lines,
      locks: locks,
      fusions: fusions,
      combo: combo,
      bestCombo: bestCombo,
      backToBack: backToBack,
      redLines: redLines,
      blueLines: blueLines,
      effect: _effect,
      effects: List<CoopEffectState>.unmodifiable(_recentEffects),
      redCavityCharges: _redCavityCharges,
      blueCavityCharges: _blueCavityCharges,
      gameOver: gameOver,
      puzzleCleared: puzzleCleared,
      puzzleSpeedBonus: puzzleSpeedBonus,
    );
  }
}

class _CoopClearAward {
  const _CoopClearAward({
    this.linePoints = 0,
    this.comboBonus = 0,
    this.backToBackBonus = 0,
  });

  final int linePoints;
  final int comboBonus;
  final int backToBackBonus;
}

bool _piecesConflict(ActivePiece first, ActivePiece second) {
  for (final cell in first.cellsOnBoard()) {
    for (final otherCell in second.cellsOnBoard()) {
      if (cell.row != otherCell.row || cell.col != otherCell.col) continue;
      if (cell.kind == CellKind.full || otherCell.kind == CellKind.full) {
        return true;
      }
      if (cell.tri == otherCell.tri) return true;
    }
  }
  return false;
}
