import 'package:flutter/material.dart';

class Config {
  const Config({this.rows = 20, this.cols = 10});
  final int rows;
  final int cols;
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
