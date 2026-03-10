import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'ai/hider_ai.dart';
import 'ai/seeker_ai.dart';
import 'components/grid_manager.dart';
import 'components/hex_tile_component.dart';
import 'components/player_component.dart';
import 'core/game_state.dart';
import 'core/hex_coords.dart';
import 'utils/level_generator.dart';

export 'core/game_state.dart';

class HideAndSeekGame extends FlameGame {
  final PlayerRole playerRole;

  HideAndSeekGame({required this.playerRole});

  // ── Grid ──────────────────────────────────────────────────────────────────
  late GridManager _grid;
  late double _hexRadius;

  // ── Players ───────────────────────────────────────────────────────────────
  late PlayerComponent _hider;
  late PlayerComponent _seeker;

  // ── Game state ────────────────────────────────────────────────────────────
  GamePhase _phase = GamePhase.hiding;
  double _hideTimer = 10.0; // seconds remaining in hiding phase
  final Set<AxialCoord> _visited = {};

  // ── AI ────────────────────────────────────────────────────────────────────
  HiderAI? _hiderAI;
  SeekerAI? _seekerAI;

  // ── HUD ───────────────────────────────────────────────────────────────────
  late TextComponent _hudText;

  // ── Constants ─────────────────────────────────────────────────────────────
  static const int _gridSize = 12;
  static const String overlayWin = 'winOverlay';
  static const String overlayLose = 'loseOverlay';

  // ── onLoad ────────────────────────────────────────────────────────────────
  @override
  Future<void> onLoad() async {
    await super.onLoad();

    _hexRadius = _computeHexRadius();

    // Centre grid on screen.
    final offset = _computeGridOffset(_hexRadius);

    _grid = GridManager(
      gridSize: _gridSize,
      hexRadius: _hexRadius,
      gridOffset: offset,
    );
    _grid.onTileTapped = _onTileTapped;
    await add(_grid);

    // Level generation.
    final gen = LevelGenerator();
    final data = playerRole == PlayerRole.hider
        ? gen.generateForHider()
        : gen.generateForSeeker();

    for (final w in data.walls) {
      _grid.addWall(w.a, w.b);
    }

    // Spawn players.
    _hider = PlayerComponent(
      type: PlayerType.hider,
      currentCoord: data.hiderStart,
      position: _playerTopLeft(data.hiderStart, _hexRadius),
      hexRadius: _hexRadius,
    );

    _seeker = PlayerComponent(
      type: PlayerType.seeker,
      currentCoord: data.seekerStart,
      position: _playerTopLeft(data.seekerStart, _hexRadius),
      hexRadius: _hexRadius,
    );

    await add(_hider);
    await add(_seeker);

    _grid.setTileState(data.hiderStart, TileState.occupied);
    _grid.setTileState(data.seekerStart, TileState.occupied);

    // AI controllers.
    if (playerRole == PlayerRole.seeker) {
      _hiderAI = HiderAI(grid: _grid, seekerStart: data.seekerStart);
    } else {
      _seekerAI = SeekerAI(grid: _grid);
    }

    // HUD.
    _hudText = TextComponent(
      text: '',
      position: Vector2(size.x / 2, 24),
      anchor: Anchor.topCenter,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFB29CFF),
          fontSize: 18,
          fontWeight: FontWeight.w700,
          fontFamily: 'monospace',
        ),
      ),
    );
    await add(_hudText);

    _updateHintHighlights();
  }

  // ── Game loop ─────────────────────────────────────────────────────────────
  @override
  void update(double dt) {
    super.update(dt);

    switch (_phase) {
      case GamePhase.hiding:
        _tickHiding(dt);
      case GamePhase.seeking:
        _tickSeeking(dt);
      case GamePhase.seekerWins:
      case GamePhase.hiderWins:
        break;
    }

    _hudText.text = _buildHUD();
  }

  // ── Hiding phase ──────────────────────────────────────────────────────────
  void _tickHiding(double dt) {
    _hideTimer -= dt;

    // AI Hider moves during hiding phase (Scenario B).
    if (_hiderAI != null) {
      final next = _hiderAI!.update(dt, _hider.currentCoord);
      if (next != null) _moveHider(next);
    }

    if (_hideTimer <= 0) {
      _startSeekingPhase();
    }
  }

  void _startSeekingPhase() {
    _phase = GamePhase.seeking;
    _hideTimer = 0;

    // Hide the hider from the player when the player is the seeker.
    if (playerRole == PlayerRole.seeker) {
      _hider.isVisible = false;
    }

    _grid.clearAllHighlights();
    _updateHintHighlights();
  }

  // ── Seeking phase ─────────────────────────────────────────────────────────
  void _tickSeeking(double dt) {
    if (_seekerAI != null && !_seeker.isMoving) {
      final next = _seekerAI!.update(
        dt,
        _seeker.currentCoord,
        _hider.currentCoord,
        _visited,
      );
      if (next != null) {
        _moveSeeker(next);
      } else if (_seekerAI!.isTrapped(_seeker.currentCoord, _visited)) {
        _endGame(GamePhase.hiderWins);
      }
    }
  }

  // ── Tile tap handler ──────────────────────────────────────────────────────
  void _onTileTapped(AxialCoord coord) {
    if (_phase == GamePhase.hiding && playerRole == PlayerRole.hider) {
      _tryMoveHider(coord);
    } else if (_phase == GamePhase.seeking && playerRole == PlayerRole.seeker) {
      _tryMoveSeeker(coord);
    }
  }

  void _tryMoveHider(AxialCoord target) {
    if (_hider.isMoving) return;
    final moves = _grid.validMoves(_hider.currentCoord);
    if (moves.contains(target)) _moveHider(target);
  }

  void _tryMoveSeeker(AxialCoord target) {
    if (_seeker.isMoving) return;
    final moves = _grid.validMoves(_seeker.currentCoord, visited: _visited);
    if (!moves.contains(target)) return;
    _moveSeeker(target);
  }

  // ── Movement helpers ──────────────────────────────────────────────────────
  void _moveHider(AxialCoord next) {
    _grid.setTileState(_hider.currentCoord, TileState.unvisited);
    _hider.moveTo(
      _grid.tileCenter(next) - Vector2(_hexRadius * 0.8, _hexRadius * 0.8),
      next,
    );
    _grid.setTileState(next, TileState.occupied);
  }

  void _moveSeeker(AxialCoord next) {
    final prev = _seeker.currentCoord;

    // Mark previous tile visited.
    _visited.add(prev);
    _grid.setTileState(prev, TileState.visited);

    // Move.
    _seeker.moveTo(
      _grid.tileCenter(next) - Vector2(_hexRadius * 0.8, _hexRadius * 0.8),
      next,
    );
    _grid.setTileState(next, TileState.occupied);

    _grid.clearAllHighlights();
    _updateHintHighlights();

    // Win check: seeker lands on hider's tile.
    if (next == _hider.currentCoord) {
      _hider.isVisible = true;
      _endGame(GamePhase.seekerWins);
      return;
    }

    // Trap check: no moves left after arriving.
    if (_seekerAI == null) {
      // Player is seeker — check immediately.
      if (_grid.validMoves(next, visited: _visited).isEmpty) {
        _endGame(GamePhase.hiderWins);
      }
    }
  }

  // ── Win / lose ────────────────────────────────────────────────────────────
  void _endGame(GamePhase result) {
    _phase = result;
    _grid.clearAllHighlights();
    _hider.isVisible = true;

    final isPlayerWin =
        (result == GamePhase.seekerWins && playerRole == PlayerRole.seeker) ||
        (result == GamePhase.hiderWins && playerRole == PlayerRole.hider);

    overlays.add(isPlayerWin ? overlayWin : overlayLose);
  }

  // ── Highlight valid moves ─────────────────────────────────────────────────
  void _updateHintHighlights() {
    if (_phase == GamePhase.hiding && playerRole == PlayerRole.hider) {
      for (final c in _grid.validMoves(_hider.currentCoord)) {
        _grid.setHighlighted(c, true);
      }
    } else if (_phase == GamePhase.seeking && playerRole == PlayerRole.seeker) {
      for (final c in _grid.validMoves(
        _seeker.currentCoord,
        visited: _visited,
      )) {
        _grid.setHighlighted(c, true);
      }
    }
  }

  // ── HUD text ──────────────────────────────────────────────────────────────
  String _buildHUD() {
    switch (_phase) {
      case GamePhase.hiding:
        final s = _hideTimer.ceil();
        return playerRole == PlayerRole.hider
            ? 'HIDING PHASE — Find a safe spot!  $s s'
            : 'HIDING PHASE — AI hider is moving…  $s s';
      case GamePhase.seeking:
        return playerRole == PlayerRole.seeker
            ? 'SEEKING — Tap an adjacent tile to move'
            : 'AI SEEKING — Watch the trail…';
      case GamePhase.seekerWins:
        return '🔍 SEEKER FOUND THE HIDER!';
      case GamePhase.hiderWins:
        return '🙈 HIDER ESCAPED — Seeker is trapped!';
    }
  }

  // ── Layout helpers ────────────────────────────────────────────────────────
  double _computeHexRadius() {
    const cols = _gridSize;
    const rows = _gridSize;
    const sqrt3 = 1.7320508;
    // Full grid bounding box formula for flat-top:
    //  width  = hexRadius * (1.5*(cols-1) + 2)
    //  height = hexRadius * (sqrt3 * (rows-1) * 1.5 + sqrt3)
    final rFromWidth = (size.x - 48) / (1.5 * (cols - 1) + 2);
    final rFromHeight = (size.y - 96) / (sqrt3 * ((rows - 1) * 1.5 + 1));
    return min(rFromWidth, rFromHeight).clamp(10.0, 32.0);
  }

  Vector2 _computeGridOffset(double r) {
    const sqrt3 = 1.7320508;
    final gridW = r * (1.5 * (_gridSize - 1) + 2);
    final gridH = r * sqrt3 * ((_gridSize - 1) * 1.5 + 1);
    return Vector2(
      (size.x - gridW) / 2 + r,
      (size.y - gridH) / 2 + sqrt3 / 2 * r + 48,
    );
  }

  Vector2 _playerTopLeft(AxialCoord coord, double r) {
    final center = _grid.tileCenter(coord);
    final playerR = r * 0.8;
    return center - Vector2(playerR, playerR);
  }
}
