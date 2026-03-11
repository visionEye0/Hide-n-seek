import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';

import '../core/hex_coords.dart';

/// Draws a coloured wall segment along the shared edge of two adjacent hexes.
/// Must be added to a parent whose local space is screen space (position 0,0).
class WallComponent extends Component {
  final AxialCoord coordA;
  final AxialCoord coordB;

  /// Screen-space centres of the two tiles this wall separates.
  final Vector2 centerA;
  final Vector2 centerB;

  late final ui.ImageShader wallShader;

  WallComponent({
    required this.coordA,
    required this.coordB,
    required this.centerA,
    required this.centerB,
  });

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final wallImage = Flame.images.fromCache('resources/wall_texture.png');
    wallShader = ui.ImageShader(
      wallImage,
      ui.TileMode.repeated,
      ui.TileMode.repeated,
      Float64List.fromList([
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
      ]),
    );
  }

  @override
  void render(Canvas canvas) {
    final mid = (centerA + centerB) * 0.5;
    final diff = centerB - centerA;
    // Perpendicular to the line connecting the two centres.
    final perp = Vector2(-diff.y, diff.x)..normalize();
    final halfLen = diff.length * 0.42;
    final start = mid + perp * halfLen;
    final end = mid - perp * halfLen;

    canvas.drawLine(
      Offset(start.x, start.y),
      Offset(end.x, end.y),
      Paint()
        ..shader = wallShader
        ..strokeWidth = 12.0
        ..strokeCap = StrokeCap.square,
    );
  }
}
