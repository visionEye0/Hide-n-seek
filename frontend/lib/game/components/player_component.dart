import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';

import '../core/hex_coords.dart';
import '../core/game_settings.dart';
import 'package:flame_audio/flame_audio.dart';
import 'player_sprite_config.dart';

enum PlayerType { hider, seeker }

// ─── Hex-direction → MoveDir mapping ─────────────────────────────────────────
//
//  Flat-top hex grid axial neighbour directions:
//   (dq, dr)  → compass bearing (screen-space, y grows down)
//   ( 1,  0)  → East    = MoveDir.right
//   ( 1, -1)  → NE      = MoveDir.upRight
//   ( 0, -1)  → NW      = MoveDir.upLeft
//   (-1,  0)  → West    = MoveDir.left
//   (-1,  1)  → SW      = MoveDir.downLeft
//   ( 0,  1)  → SE      = MoveDir.downRight
//
MoveDir _hexDeltaToDir(AxialCoord from, AxialCoord to) {
  final dq = to.q - from.q;
  final dr = to.r - from.r;

  if (dq == 1 && dr == 0) return MoveDir.downRight;
  if (dq == 1 && dr == -1) return MoveDir.upRight;
  if (dq == 0 && dr == -1) return MoveDir.up;
  if (dq == -1 && dr == 0) return MoveDir.upLeft;
  if (dq == -1 && dr == 1) return MoveDir.downLeft;
  if (dq == 0 && dr == 1) return MoveDir.down;

  // fallback for multi-step moves (leap)
  final deltaPixel = axialToPixel(AxialCoord(dq, dr), 1.0);
  return _pixelDeltaToDir(deltaPixel);
}

MoveDir _pixelDeltaToDir(Vector2 delta) {
  final len = delta.length;
  if (len < 0.01) return MoveDir.idle;

  final nx = delta.x / len;
  final ny = delta.y / len;

  // Mostly vertical movement -> Up or Down
  if (nx.abs() < 0.5) {
    return ny > 0 ? MoveDir.down : MoveDir.up;
  }

  // Horizontal + Vertical movement -> Diagonals
  if (nx > 0) {
    return ny > 0 ? MoveDir.downRight : MoveDir.upRight;
  } else {
    return ny > 0 ? MoveDir.downLeft : MoveDir.upLeft;
  }
}

// ─── Animation constants ──────────────────────────────────────────────────────
const double _cellW = 16.0;
const double _cellH = 24.0;
const int _framesPerAnim =
    3; // 3 animation frames vertically per character block
const double _frameDuration = 0.12; // seconds per frame

/// An animated sprite avatar for the Hider or Seeker.
///
/// On each move the direction is derived from the hex coordinate delta and the
/// matching sprite frame (from [globalSpriteConfig]) is played as a 4-frame
/// walk cycle. When idle the character shows the configured idle frame.
///
/// [renderOpacity] controls alpha:
///   1.0 = fully visible, 0.3 = 70% transparent (hider after hiding phase),
///   0.0 = fully invisible.
class PlayerComponent extends PositionComponent {
  PlayerType type;
  AxialCoord currentCoord;

  double renderOpacity;

  Vector2? _targetPos;
  static const double _speed = 280.0;

  // ── Animation state ────────────────────────────────────────────────────────
  MoveDir _facing = MoveDir.idle;
  int _frameIndex = 0;
  double _frameTimer = 0;

  late final ui.Image _sheet;

  PlayerComponent({
    required this.type,
    required this.currentCoord,
    required super.position,
    required double hexRadius,
    this.renderOpacity = 1.0,
  }) : super(size: Vector2.all(hexRadius * 1.6));

  bool get isHider => type == PlayerType.hider;
  CharSpriteConfig get _charConfig =>
      isHider ? globalSpriteConfig.hider : globalSpriteConfig.seeker;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _sheet = Flame.images.fromCache(
      'resources/Small-8-Direction-Characters_by_AxulArt.png',
    );
  }

  @override
  void update(double dt) {
    if (_targetPos != null) {
      final dir = _targetPos! - position;
      final dist = dir.length;
      final step = _speed * dt;

      // Advance animation frames while moving.
      _frameTimer += dt;
      if (_frameTimer >= _frameDuration) {
        _frameTimer -= _frameDuration;
        _frameIndex = (_frameIndex + 1) % _framesPerAnim;
      }

      if (step >= dist) {
        position.setFrom(_targetPos!);
        _targetPos = null;
        _frameIndex = 0;
        _frameTimer = 0;
        _facing = MoveDir.idle;
      } else {
        position.addScaled(dir.normalized(), step);
      }
    }
  }

  /// Move the player to [worldPos] with a smooth walk animation.
  /// [newCoord] is the destination hex — used to determine the exact direction.
  void moveTo(Vector2 worldPos, AxialCoord newCoord) {
    _facing = _hexDeltaToDir(currentCoord, newCoord);
    _targetPos = worldPos.clone();
    currentCoord = newCoord;
    _frameIndex = 0;
    _frameTimer = 0;

    if (globalSettings.soundEnabled) {
      FlameAudio.play('step.wav', volume: 0.4);
    }
  }

  /// Instantly teleport the player to [worldPos] (no animation).
  void teleportTo(Vector2 worldPos, AxialCoord newCoord) {
    _facing = MoveDir.idle;
    _targetPos = null;
    position.setFrom(worldPos);
    currentCoord = newCoord;
    _frameIndex = 0;
    _frameTimer = 0;
  }

  bool get isMoving => _targetPos != null;

  @override
  void render(Canvas canvas) {
    if (renderOpacity <= 0.01) return;

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
    final spriteHeight = size.y;
    final spriteWidth = spriteHeight * (_cellW / _cellH);
    final left = (size.x - spriteWidth) / 2;

    // Drop shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x / 2, size.y - 2),
        width: spriteWidth * 0.8,
        height: size.y * 0.25,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.28),
    );

    // Look up the configured frame for the current facing direction.
    final frame = _charConfig.frameFor(_facing);

    // To prevent walking out of the character's animation block if the user
    // selects the bottom frame of a cycle, we calculate the base row block
    // (White=1, Blue=5, Orange=9) based on what row they tapped.
    int baseRow = frame.row;
    if (baseRow >= 1 && baseRow <= 3) {
      baseRow = 1;
    } else if (baseRow >= 5 && baseRow <= 7) {
      baseRow = 5;
    } else if (baseRow >= 9 && baseRow <= 11) {
      baseRow = 9;
    }

    // Animate through rows 0-2 for the walk cycle (the sheet stores walk frames vertically).
    // Idle just shows the base frame (animRowOffset = 0).
    final animRowOffset = isMoving ? _frameIndex : 0;
    final srcX = frame.col * _cellW;
    final srcY = (baseRow + animRowOffset) * _cellH;
    final src = Rect.fromLTWH(srcX, srcY, _cellW, _cellH);
    final dst = Rect.fromLTWH(left, 0, spriteWidth, spriteHeight);

    if (frame.flip) {
      canvas.save();
      canvas.translate(left + spriteWidth / 2, 0);
      canvas.scale(-1, 1);
      canvas.translate(-(left + spriteWidth / 2), 0);
    }

    canvas.drawImageRect(
      _sheet,
      src,
      dst,
      Paint()..filterQuality = FilterQuality.none,
    );

    if (frame.flip) canvas.restore();
  }
}
