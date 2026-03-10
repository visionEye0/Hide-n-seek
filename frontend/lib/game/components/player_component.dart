import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../core/hex_coords.dart';

enum PlayerType { hider, seeker }

/// An animated circular avatar for the Hider or Seeker.
class PlayerComponent extends PositionComponent {
  PlayerType type;
  AxialCoord currentCoord;

  /// When false the hider is hidden from the opposing player (Scenario B).
  bool isVisible;

  Vector2? _targetPos;
  static const double _speed = 280.0; // px / s

  PlayerComponent({
    required this.type,
    required this.currentCoord,
    required super.position,
    required double hexRadius,
    this.isVisible = true,
  }) : super(size: Vector2.all(hexRadius * 1.6));

  bool get isHider => type == PlayerType.hider;

  @override
  void update(double dt) {
    if (_targetPos != null) {
      final dir = _targetPos! - position;
      final dist = dir.length;
      final step = _speed * dt;
      if (step >= dist) {
        position.setFrom(_targetPos!);
        _targetPos = null;
      } else {
        position.addScaled(dir.normalized(), step);
      }
    }
  }

  /// Move the player to [worldPos] and update its logical coordinate.
  void moveTo(Vector2 worldPos, AxialCoord newCoord) {
    _targetPos = worldPos.clone();
    currentCoord = newCoord;
  }

  bool get isMoving => _targetPos != null;

  @override
  void render(Canvas canvas) {
    if (!isVisible) return;

    final cx = size.x / 2;
    final cy = size.y / 2;
    final r = size.x * 0.42;

    // Drop shadow.
    canvas.drawCircle(
      Offset(cx, cy + 2),
      r,
      Paint()..color = Colors.black.withValues(alpha: 0.28),
    );

    // Body.
    final bodyColor = isHider
        ? const Color(0xFF00C896)
        : const Color(0xFFFF6B35);
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = bodyColor);

    // White ring.
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Inner icon (simple geometric: square for hider, diamond for seeker).
    final iconSize = r * 0.55;
    final iconPaint = Paint()..color = Colors.white.withValues(alpha: 0.85);
    if (isHider) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx, cy),
            width: iconSize,
            height: iconSize,
          ),
          const Radius.circular(2),
        ),
        iconPaint,
      );
    } else {
      final path = Path()
        ..moveTo(cx, cy - iconSize * 0.7)
        ..lineTo(cx + iconSize * 0.6, cy)
        ..lineTo(cx, cy + iconSize * 0.7)
        ..lineTo(cx - iconSize * 0.6, cy)
        ..close();
      canvas.drawPath(path, iconPaint);
    }
  }
}
