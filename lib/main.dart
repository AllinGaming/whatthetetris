import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const HalfBlockPyramidApp());
}

class HalfBlockPyramidApp extends StatelessWidget {
  const HalfBlockPyramidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'What The Tetris',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF66E0F4),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0D0F16),
        useMaterial3: true,
      ),
      home: const GamePage(),
    );
  }
}

class Config {
  const Config({this.rows = 20, this.cols = 10});
  final int rows;
  final int cols;
}

/// Two diagonals per square.
enum TriHalf { bl, tr }

extension TriHalfRotation on TriHalf {
  TriHalf rotateCW() => this == TriHalf.bl ? TriHalf.tr : TriHalf.bl;
}

enum CellKind { full, tri }

class PieceCell {
  const PieceCell({
    required this.row,
    required this.col,
    required this.kind,
    this.tri,
  });

  final int row;
  final int col;
  final CellKind kind;
  final TriHalf? tri;
}

class PieceDefinition {
  PieceDefinition({
    required this.name,
    required List<PieceCell> base,
    required this.color,
  }) : rotations = _buildRotations(base);

  final String name;
  final List<List<PieceCell>> rotations;
  final Color color;

  static List<List<PieceCell>> _buildRotations(List<PieceCell> base) {
    final rotations = <List<PieceCell>>[];
    List<PieceCell> current = base;
    for (int i = 0; i < 4; i++) {
      rotations.add(_normalize(current));
      current = current.map(_rotateCW).toList();
    }
    return rotations;
  }

  static PieceCell _rotateCW(PieceCell cell) {
    final newRow = cell.col;
    final newCol = -cell.row;
    return PieceCell(
      row: newRow,
      col: newCol,
      kind: cell.kind,
      tri: cell.tri?.rotateCW(),
    );
  }

  static List<PieceCell> _normalize(List<PieceCell> cells) {
    final minR = cells.map((c) => c.row).reduce(min);
    final minC = cells.map((c) => c.col).reduce(min);
    return cells
        .map(
          (c) => PieceCell(
            row: c.row - minR,
            col: c.col - minC,
            kind: c.kind,
            tri: c.tri,
          ),
        )
        .toList();
  }
}

class ActivePiece {
  ActivePiece({
    required this.type,
    this.rotation = 0,
    required this.row,
    required this.col,
    this.mirrored = false,
  });

  final PieceDefinition type;
  final int rotation;
  final int row;
  final int col;
  final bool mirrored;

  ActivePiece copyWith({int? rotation, int? row, int? col, bool? mirrored}) {
    return ActivePiece(
      type: type,
      rotation: rotation ?? this.rotation,
      row: row ?? this.row,
      col: col ?? this.col,
      mirrored: mirrored ?? this.mirrored,
    );
  }
}

class CellOccupancy {
  Color? full;
  Color? bl;
  Color? tr;

  CellOccupancy clone() {
    final copy = CellOccupancy();
    copy.full = full;
    copy.bl = bl;
    copy.tr = tr;
    return copy;
  }

  bool get isFullyFilled {
    return full != null || (bl != null && tr != null);
  }
}

enum GameState { playing, paused, over }

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  static const _config = Config();
  static List<PieceCell> _triangulate(
    List<({int row, int col})> squares, {
    TriHalf tri = TriHalf.bl,
  }) {
    // Convert each square coordinate to a single triangle (uniform diagonal)
    // so an entire piece shares one orientation and flips together on rotate.
    return squares
        .map(
          (sq) =>
              PieceCell(row: sq.row, col: sq.col, kind: CellKind.tri, tri: tri),
        )
        .toList();
  }

  late List<List<CellOccupancy>> _board;
  ActivePiece? _active;
  GameState _state = GameState.paused;
  int _score = 0;
  int _lines = 0;
  Timer? _timer;
  final _focusNode = FocusNode();
  final _rand = Random();
  int _cavityCharges = 1;
  int _speedBoost = 0;

  int get _level => 1 + (_lines ~/ 10);

  List<PieceDefinition> get _pieces => [
    // Size 4 only
    PieceDefinition(
      name: 'I4',
      base: _triangulate([
        (row: 0, col: 0),
        (row: 0, col: 1),
        (row: 0, col: 2),
        (row: 0, col: 3),
      ]),
      color: const Color(0xFF8AE66E),
    ),
    PieceDefinition(
      name: 'L4',
      base: _triangulate([
        (row: 0, col: 0),
        (row: 1, col: 0),
        (row: 2, col: 0),
        (row: 2, col: 1),
      ]),
      color: const Color(0xFF9B7BFF),
    ),
    PieceDefinition(
      name: 'T4',
      base: _triangulate([
        (row: 0, col: 0),
        (row: 0, col: 1),
        (row: 0, col: 2),
        (row: 1, col: 1),
      ]),
      color: const Color(0xFFFF8FB1),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _resetBoard();
    _startGame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _resetBoard() {
    _board = List.generate(
      _config.rows,
      (_) => List.generate(_config.cols, (_) => CellOccupancy()),
    );
    _cavityCharges = 1;
  }

  Duration get _tickSpeed {
    final baseMs = (700 - (_level - 1) * 40).clamp(120, 700);
    final boosted = (baseMs / (1 + (_speedBoost * 0.2))).clamp(
      60,
      baseMs.toDouble(),
    );
    return Duration(milliseconds: boosted.round());
  }

  void _startGame() {
    _resetBoard();
    _score = 0;
    _lines = 0;
    _cavityCharges = 1;
    _speedBoost = 0;
    _state = GameState.playing;
    _spawnPiece();
    _restartTimer();
    setState(() {});
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_tickSpeed, (_) {
      if (_state == GameState.playing) {
        _tick();
      }
    });
  }

  void _fillCavities() {
    if (_cavityCharges <= 0) return;
    int filled = 0;
    for (int r = _config.rows - 1; r >= 0 && filled < 1; r--) {
      for (int c = 0; c < _config.cols && filled < 1; c++) {
        final cell = _board[r][c];
        if (cell.full != null) continue;
        final hasBl = cell.bl != null;
        final hasTr = cell.tr != null;
        if (hasBl == hasTr) continue; // skip empty or already full
        final color = hasBl ? cell.bl! : cell.tr!;
        if (!hasBl) {
          cell.bl = color;
        } else {
          cell.tr = color;
        }
        filled++;
      }
    }
    if (filled > 0) {
      _cavityCharges--;
      final cleared = _clearLines();
      if (cleared > 0) {
        _score += _pointsForLines(cleared);
        _lines += cleared;
        _cavityCharges += cleared;
      }
      _restartTimer();
      setState(() {});
    }
  }

  void _speedUp() {
    _speedBoost++;
    _score += 25 * _speedBoost;
    _restartTimer();
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
    if (_active == null) return;
    final next = _active!.copyWith(row: _active!.row + 1);
    final moved = _attemptMove(next);
    if (!moved) {
      _lockPiece();
    }
  }

  PieceDefinition _nextPiece() => _pieces[_rand.nextInt(_pieces.length)];

  int _pieceWidth(PieceDefinition def) {
    final rotation = def.rotations.first;
    final maxCol = rotation.map((c) => c.col).reduce(max);
    final minCol = rotation.map((c) => c.col).reduce(min);
    return maxCol - minCol + 1;
  }

  void _spawnPiece() {
    final type = _nextPiece();
    final width = _pieceWidth(type);
    final spawnCol = ((_config.cols - width) ~/ 2).clamp(0, _config.cols - 1);
    _active = ActivePiece(type: type, row: 0, col: spawnCol);
    if (!_canPlace(_active!)) {
      _state = GameState.over;
      _active = null;
    }
  }

  List<PieceCell> _cellsFor(ActivePiece piece) {
    final rot =
        piece.type.rotations[piece.rotation % piece.type.rotations.length];
    return rot
        .map(
          (c) => PieceCell(
            row: piece.row + c.row,
            col: piece.col + c.col,
            kind: c.kind,
            tri: piece.mirrored ? c.tri?.rotateCW() : c.tri,
          ),
        )
        .toList();
  }

  bool _canPlace(ActivePiece piece) {
    for (final cell in _cellsFor(piece)) {
      if (cell.row < 0 || cell.row >= _config.rows) {
        return false;
      }
      if (cell.col < 0 || cell.col >= _config.cols) {
        return false;
      }
      final target = _board[cell.row][cell.col];
      if (target.full != null) return false;
      // Stop only on same-orientation triangles; opposite halves can be entered
      // so they merge when the piece eventually locks.
      if (cell.tri == TriHalf.bl && target.bl != null) return false;
      if (cell.tri == TriHalf.tr && target.tr != null) return false;
    }
    return true;
  }

  bool _attemptMove(ActivePiece next) {
    if (!_canPlace(next)) return false;
    setState(() => _active = next);
    return true;
  }

  void _mirrorActive() {
    if (_active == null) return;
    final toggled = _active!.copyWith(mirrored: !_active!.mirrored);
    _attemptMove(toggled);
  }

  bool _tryMove({int dx = 0, int dy = 0, int rotDelta = 0}) {
    if (_active == null) return false;
    final rotCount = _active!.type.rotations.length;
    final rawRot = (_active!.rotation + rotDelta) % rotCount;
    final nextRot = rawRot < 0 ? rawRot + rotCount : rawRot;
    final next = _active!.copyWith(
      row: _active!.row + dy,
      col: _active!.col + dx,
      rotation: nextRot,
    );
    return _attemptMove(next);
  }

  void _hardDrop() {
    if (_active == null) return;
    int steps = 0;
    while (true) {
      final next = _active!.copyWith(row: _active!.row + 1);
      final moved = _attemptMove(next);
      if (!moved) break;
      steps++;
    }
    _score += steps * 2;
    _lockPiece();
  }

  void _lockPiece() {
    if (_active == null) return;
    for (final cell in _cellsFor(_active!)) {
      final target = _board[cell.row][cell.col];
      if (cell.kind == CellKind.full) {
        target.full = _active!.type.color;
      } else {
        if (cell.tri == TriHalf.bl) {
          target.bl = _active!.type.color;
        } else {
          target.tr = _active!.type.color;
        }
      }
    }
    _active = null;
    final cleared = _clearLines();
    _score += _pointsForLines(cleared);
    _lines += cleared;
    _cavityCharges += cleared; // one charge per cleared line
    _restartTimer();
    _spawnPiece();
    setState(() {});
  }

  int _clearLines() {
    int cleared = 0;
    for (int r = _config.rows - 1; r >= 0; r--) {
      final fullRow = _board[r].every((c) => c.isFullyFilled);
      if (fullRow) {
        cleared++;
        for (int i = r; i > 0; i--) {
          _board[i] = _board[i - 1].map((c) => c.clone()).toList();
        }
        _board[0] = List.generate(_config.cols, (_) => CellOccupancy());
        r++;
      }
    }
    return cleared;
  }

  void _togglePause() {
    setState(() {
      _state = _state == GameState.playing
          ? GameState.paused
          : GameState.playing;
    });
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (_state == GameState.over && event.logicalKey.keyLabel == ' ') {
      _startGame();
      return;
    }
    switch (event.logicalKey.keyLabel) {
      case 'Arrow Left':
        _tryMove(dx: -1);
        break;
      case 'Arrow Right':
        _tryMove(dx: 1);
        break;
      case 'Arrow Down':
        _tryMove(dy: 1);
        break;
      case 'Arrow Up':
      case 'w':
      case 'W':
        _tryMove(rotDelta: 1);
        break;
      case 'm':
      case 'M':
        _mirrorActive();
        break;
      case 'Key M':
        _mirrorActive();
        break;
      case ' ':
        _hardDrop();
        break;
      case 'g':
      case 'G':
        _fillCavities();
        break;
      case 'p':
      case 'P':
        _togglePause();
        break;
    }
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
            final panelWidth = min(260.0, constraints.maxWidth * 0.28);
            return Row(
              children: [
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: _config.cols / _config.rows,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: CustomPaint(
                            painter: BoardPainter(
                              board: _board,
                              active: _active,
                              config: _config,
                              state: _state,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: panelWidth,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    border: const Border(
                      left: BorderSide(color: Colors.white12),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What The Tetris',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Every block is a single glowing triangle now—rotate to flip its diagonal. Land triangles in every cell of a row to clear it. Finish a clean row to unlock a cavity filler.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      _Stat(label: 'Score', value: _score.toString()),
                      _Stat(label: 'Lines', value: _lines.toString()),
                      _Stat(label: 'Level', value: _level.toString()),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton(
                            onPressed: _state == GameState.over
                                ? _startGame
                                : _togglePause,
                            child: Text(
                              _state == GameState.paused ? 'Play' : 'Pause',
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _hardDrop,
                            child: const Text('Hard Drop'),
                          ),
                          ElevatedButton(
                            onPressed: _speedUp,
                            child: Text('Speed Up (x${1 + _speedBoost * 0.2})'),
                          ),
                          ElevatedButton(
                            onPressed: _mirrorActive,
                            child: const Text('Mirror (M)'),
                          ),
                          ElevatedButton(
                            onPressed: _cavityCharges > 0
                                ? _fillCavities
                                : null,
                            child: Text('Fill Cavities (G)  x$_cavityCharges'),
                          ),
                        ],
                      ),
                      const Spacer(),
                      if (_state == GameState.over)
                        FilledButton(
                          onPressed: _startGame,
                          child: const Text('Play Again'),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class BoardPainter extends CustomPainter {
  BoardPainter({
    required this.board,
    required this.active,
    required this.config,
    required this.state,
  });

  final List<List<CellOccupancy>> board;
  final ActivePiece? active;
  final Config config;
  final GameState state;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / config.cols;
    final startY = size.height - config.rows * cell;

    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF0F131D), Color(0xFF0B0E14)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    void drawTri(int row, int col, TriHalf tri, Color color) {
      final x = col * cell;
      final y = startY + row * cell;
      final rect = Rect.fromLTWH(x + 1, y + 1, cell - 2, cell - 2);
      final path = Path();
      switch (tri) {
        case TriHalf.bl:
          path
            ..moveTo(rect.left, rect.bottom)
            ..lineTo(rect.left, rect.top)
            ..lineTo(rect.right, rect.bottom);
          break;
        case TriHalf.tr:
          path
            ..moveTo(rect.right, rect.top)
            ..lineTo(rect.right, rect.bottom)
            ..lineTo(rect.left, rect.top);
          break;
      }
      path.close();
      final paint = Paint()
        ..shader = LinearGradient(
          colors: [color.withValues(alpha: 0.95), color.withValues(alpha: 0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect);
      canvas.drawPath(path, paint);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.white.withValues(alpha: 0.18)
          ..strokeWidth = 1,
      );
    }

    void drawFull(int row, int col, Color color) {
      drawTri(row, col, TriHalf.bl, color);
      drawTri(row, col, TriHalf.tr, color);
    }

    for (int r = 0; r < config.rows; r++) {
      for (int c = 0; c < config.cols; c++) {
        final cellData = board[r][c];
        if (cellData.full != null) {
          drawFull(r, c, cellData.full!);
        } else {
          if (cellData.bl != null) drawTri(r, c, TriHalf.bl, cellData.bl!);
          if (cellData.tr != null) drawTri(r, c, TriHalf.tr, cellData.tr!);
        }
      }
    }

    if (active != null) {
      for (final cellPos in _cellsFor(active!)) {
        if (cellPos.kind == CellKind.full) {
          drawFull(cellPos.row, cellPos.col, active!.type.color);
        } else {
          drawTri(cellPos.row, cellPos.col, cellPos.tri!, active!.type.color);
        }
      }
    }

    canvas.drawRect(
      Rect.fromLTWH(0, startY, config.cols * cell, config.rows * cell),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.white24
        ..strokeWidth = 1.5,
    );

    if (state == GameState.paused || state == GameState.over) {
      final overlay = Paint()
        ..color = Colors.black.withValues(
          alpha: state == GameState.over ? 0.55 : 0.35,
        );
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), overlay);
      final textPainter = TextPainter(
        text: TextSpan(
          text: state == GameState.over ? 'Game Over' : 'Paused',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);
      textPainter.paint(
        canvas,
        Offset(
          (size.width - textPainter.width) / 2,
          (size.height - textPainter.height) / 2,
        ),
      );
    }
  }

  List<PieceCell> _cellsFor(ActivePiece piece) {
    final rot =
        piece.type.rotations[piece.rotation % piece.type.rotations.length];
    return rot
        .map(
          (c) => PieceCell(
            row: piece.row + c.row,
            col: piece.col + c.col,
            kind: c.kind,
            tri: piece.mirrored ? c.tri?.rotateCW() : c.tri,
          ),
        )
        .toList();
  }

  @override
  bool shouldRepaint(covariant BoardPainter oldDelegate) {
    return oldDelegate.board != board ||
        oldDelegate.active != active ||
        oldDelegate.state != state;
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
