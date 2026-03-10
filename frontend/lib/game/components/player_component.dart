import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../core/hex_coords.dart';

enum PlayerType { hider, seeker }

/// An animated circular avatar for the Hider or Seeker.
///
/// [renderOpacity] controls alpha:
///   1.0 = fully visible, 0.3 = 70% transparent (hider after hiding phase
///   from the player's own perspective), 0.0 = fully invisible (hider hidden
///   from the opposing player).
class PlayerComponent extends PositionComponent {
  PlayerType type;
  AxialCoord currentCoord;

  /// 0.0 = invisible  /  0.3 = 70% transparent  /  1.0 = fully visible.
  double renderOpacity;

  Vector2? _targetPos;
  static const double _speed = 280.0; // px / s

  PlayerComponent({
    required this.type,
    required this.currentCoord,
    required super.position,
    required double hexRadius,
    this.renderOpacity = 1.0,
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

  /// Move the player to [worldPos] with a smooth animation.
  void moveTo(Vector2 worldPos, AxialCoord newCoord) {
    _targetPos = worldPos.clone();
    currentCoord = newCoord;
  }

  /// Instantly teleport the player to [worldPos] (no animation).
  void teleportTo(Vector2 worldPos, AxialCoord newCoord) {
    _targetPos = null;
    position.setFrom(worldPos);
    currentCoord = newCoord;
  }

  bool get isMoving => _targetPos != null;

  @override
  void render(Canvas canvas) {
    if (renderOpacity <= 0.01) return;

    // Wrap the whole draw in a saveLayer so renderOpacity applies uniformly.
    final bounds = Rect.fromLTWH(0, 0, size.x, size.y);
    if (renderOpacity < 0.99) {
      canvas.saveLayer(
        bounds,
        Paint()..color = Color.fromRGBO(255, 255, 255, renderOpacity),
      );
    }

    _drawAvatar(canvas);

    if (renderOpacity < 0.99) canvas.restore();
  }

  void _drawAvatar(Canvas canvas) {
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

    // Inner icon (square for hider, diamond for seeker).
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
