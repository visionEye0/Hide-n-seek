import 'dart:math';

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/flame.dart';
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

  static const Color _colOccupied = Color(0xFF7B61FF);
  static const Color _colHighlight = Color(0xFF4A3FBF);
  static const Color _colBorder = Color(0xFF7B61FF);

  late final ui.ImageShader grassShader;
  late final ui.ImageShader steppedGrassShader;

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
  Future<void> onLoad() async {
    await super.onLoad();
    final grassImage = Flame.images.fromCache('resources/grass_texture.png');
    final steppedGrassImage = Flame.images.fromCache(
      'resources/stepped_grass_texture.png',
    );

    final matrix = Float64List.fromList([
      1.0,
      0.0,
      0.0,
      0.0,
      0.0,
      1.0,
      0.0,
      0.0,
      0.0,
      0.0,
      1.0,
      0.0,
      0.0,
      0.0,
      0.0,
      1.0,
    ]);

    grassShader = ui.ImageShader(
      grassImage,
      ui.TileMode.repeated,
      ui.TileMode.repeated,
      matrix,
    );

    steppedGrassShader = ui.ImageShader(
      steppedGrassImage,
      ui.TileMode.repeated,
      ui.TileMode.repeated,
      matrix,
    );
  }

  @override
  void render(Canvas canvas) {
    final path = _buildPath();

    if (state == TileState.visited) {
      canvas.drawPath(path, Paint()..shader = steppedGrassShader);
    } else {
      canvas.drawPath(path, Paint()..shader = grassShader);
    }

    Color? overlayColor;
    if (state == TileState.visited) {
      if (isHighlighted) {
        overlayColor = const Color(0xFF4A2FC0).withValues(alpha: 0.6);
      }
    } else if (state == TileState.occupied) {
      overlayColor = _colOccupied.withValues(alpha: 0.4);
    } else {
      if (isHighlighted) {
        if (highlightHeat >= 3) {
          overlayColor = const Color(
            0xFFFFAA99,
          ).withValues(alpha: 0.6); // adjacent
        } else if (highlightHeat == 2) {
          overlayColor = const Color(
            0xFFC4718D,
          ).withValues(alpha: 0.6); // 2 steps
        } else if (highlightHeat == 1) {
          overlayColor = const Color(
            0xFF8152A3,
          ).withValues(alpha: 0.6); // 3 steps
        } else {
          overlayColor = _colHighlight.withValues(alpha: 0.6);
        }
      }
    }

    if (overlayColor != null) {
      canvas.drawPath(path, Paint()..color = overlayColor);
    }

    if (state != TileState.visited) {
      canvas.drawPath(
        path,
        Paint()
          ..color = _colBorder.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

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
