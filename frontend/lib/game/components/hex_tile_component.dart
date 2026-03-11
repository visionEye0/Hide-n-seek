import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../core/hex_coords.dart';

enum TileState { unvisited, visited, occupied }

/// A single flat-top hexagonal tile rendered on the Flame canvas.
class HexTileComponent extends PositionComponent with TapCallbacks {
  final AxialCoord coord;
  TileState state;
  bool isHighlighted; // hover / valid-move highlight
  int highlightHeat; // 0=far, 1=warm, 2=hot, 3=adjacent
  bool isSonarPinged;
  bool isDecoyScanned;
  final void Function(AxialCoord)? onTapped;

  static const Color _colUnvisited = Color(0xFF1E2244);
  static const Color _colVisited = Color(0xFF3B1FA3);
  static const Color _colOccupied = Color(0xFF7B61FF);
  static const Color _colHighlight = Color(0xFF4A3FBF);
  static const Color _colBorder = Color(0xFF7B61FF);

  HexTileComponent({
    required this.coord,
    required super.position,
    required double hexRadius,
    this.state = TileState.unvisited,
    this.isHighlighted = false,
    this.highlightHeat = 0,
    this.isSonarPinged = false,
    this.isDecoyScanned = false,
    this.onTapped,
  }) : super(size: Vector2(hexRadius * 2, sqrt(3) * hexRadius));

  double get _hexRadius => size.x / 2;

  @override
  void render(Canvas canvas) {
    final path = _buildPath();

    Color fill;
    if (state == TileState.visited) {
      fill = isHighlighted ? const Color(0xFF4A2FC0) : _colVisited;
    } else if (state == TileState.occupied) {
      fill = _colOccupied;
    } else {
      if (isHighlighted) {
        if (highlightHeat >= 3) {
          fill = const Color(0xFFFFAA99); // adjacent (bright peach/red)
        } else if (highlightHeat == 2) {
          fill = const Color(0xFFC4718D); // 2 steps (warm purple/orange)
        } else if (highlightHeat == 1) {
          fill = const Color(0xFF8152A3); // 3 steps (warm blue)
        } else {
          fill = _colHighlight;
        }
      } else {
        fill = _colUnvisited;
      }
    }

    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = _colBorder.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    if (isSonarPinged) {
      canvas.drawPath(
        path,
        Paint()..color = const Color(0xFF00FFC8).withValues(alpha: 0.35),
      );
    }

    if (isDecoyScanned) {
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFFF2244).withValues(alpha: 0.45)
          ..style = PaintingStyle.fill,
      );
    }
  }

  /// Flat-top hex path centred inside its bounding box.
  Path _buildPath() {
    final cx = size.x / 2;
    final cy = size.y / 2;
    final r = _hexRadius;
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (pi / 3) * i; // 0°, 60°, 120°, 180°, 240°, 300°
      final px = cx + r * cos(angle);
      final py = cy + r * sin(angle);
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    path.close();
    return path;
  }

  @override
  bool containsLocalPoint(Vector2 point) =>
      _buildPath().contains(Offset(point.x, point.y));

  @override
  void onTapDown(TapDownEvent event) {
    onTapped?.call(coord);
    event.handled = true;
  }
}
