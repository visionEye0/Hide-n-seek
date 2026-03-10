import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ai/seeker_ai.dart';
import 'components/grid_manager.dart';
import 'components/hex_tile_component.dart';
import 'components/player_component.dart';
import 'core/game_state.dart';
import 'core/hex_coords.dart';
import 'utils/level_generator.dart';
import 'utils/pathfinder.dart';

export 'core/game_state.dart';

class HideAndSeekGame extends FlameGame {
  final PlayerRole playerRole;
  final int level;

  HideAndSeekGame({required this.playerRole, this.level = 1});

  // ── Grid ──────────────────────────────────────────────────────────────────
  late GridManager _grid;
  late double _hexRadius;
  late int _gridCols;
  late int _gridRows;

  // ── Players ───────────────────────────────────────────────────────────────
  late PlayerComponent _hider;
  late PlayerComponent _seeker;

  // ── Game state ────────────────────────────────────────────────────────────
  GamePhase _phase = GamePhase.hiding;
  double _hideTimer = 10.0; // seconds remaining in hiding phase
  final Set<AxialCoord> _visited = {};

  // ── AI ────────────────────────────────────────────────────────────────────
  SeekerAI? _seekerAI;

  // ── HUD ───────────────────────────────────────────────────────────────────
  late TextComponent _hudText;

  // ── Constants ─────────────────────────────────────────────────────────────
  static const String overlayWin = 'winOverlay';
  static const String overlayLose = 'loseOverlay';
  static const String overlayPowerups = 'powerupsOverlay';

  // ── Power-Ups ─────────────────────────────────────────────────────────────
  bool usedSonar = false;
  bool usedLeap = false;
  bool usedDecoyScan = false;
  final ValueNotifier<int> powerupStateNotifier = ValueNotifier(0);
  bool _isLeapModeActive = false;

  /// Returns (cols, rows) for a given level.
  ///  Level 1 → 3×3,  Level 2 → 3×4,  Level 3 → 4×4,
  ///  Level 4 → 4×5,  Level 5 → 5×5,  …
  static (int cols, int rows) gridSizeForLevel(int lvl) {
    return (3 + lvl ~/ 2, 3 + (lvl - 1) ~/ 2);
  }

  // ── onLoad ────────────────────────────────────────────────────────────────
  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final gridDims = gridSizeForLevel(level);
    _gridCols = gridDims.$1;
    _gridRows = gridDims.$2;

    _hexRadius = _computeHexRadius();
    final offset = _computeGridOffset(_hexRadius);

    _grid = GridManager(
      gridCols: _gridCols,
      gridRows: _gridRows,
      hexRadius: _hexRadius,
      gridOffset: offset,
    );
    _grid.onTileTapped = _onTileTapped;
    await add(_grid);

    // Level generation.
    final gen = LevelGenerator(gridCols: _gridCols, gridRows: _gridRows);
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

    // When the player is the seeker, the hider is invisible from the very
    // start (during hiding phase AND seeking phase).
    if (playerRole == PlayerRole.seeker) {
      _hider.renderOpacity = 0.0;
    }

    // Only mark the hider's tile as 'occupied' (distinct colour) when the
    // player is the hider — otherwise it gives away the AI hider's position.
    if (playerRole == PlayerRole.hider) {
      _grid.setTileState(data.hiderStart, TileState.occupied);
    }
    _grid.setTileState(data.seekerStart, TileState.occupied);

    // AI controllers & phase overrides.
    if (playerRole == PlayerRole.seeker) {
      // AI hider already placed perfectly by level generator. Skip hiding phase.
      _startSeekingPhase();
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

    if (_phase == GamePhase.hiding) {
      _updateHintHighlights();
    }
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

    if (_hideTimer <= 0) {
      _startSeekingPhase();
    }
  }

  void _startSeekingPhase() {
    _phase = GamePhase.seeking;
    _hideTimer = 0;

    if (playerRole == PlayerRole.seeker) {
      // Player is seeking — hider is completely invisible (0% opacity).
      _hider.renderOpacity = 0.0;
      overlays.add(overlayPowerups);
    } else {
      // Player is hiding — show their own sprite at 70% transparent so they
      // can remember where they hid, but the AI seeker has no visual.
      _hider.renderOpacity = 0.3;
    }

    _grid.clearAllHighlights();
    _updateHintHighlights();
  }

  // ── Seeking phase ─────────────────────────────────────────────────────────
  void _tickSeeking(double dt) {
    if (_seekerAI != null && !_seeker.isMoving) {
      // AI seeker has NO knowledge of hider position — exploration only.
      final next = _seekerAI!.update(dt, _seeker.currentCoord, _visited);
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
    // During hiding phase the player may teleport to ANY tile on the grid.
    if (!_grid.isValid(target)) return;
    if (target == _hider.currentCoord) return;

    _grid.setTileState(_hider.currentCoord, TileState.unvisited);
    _hider.teleportTo(_playerTopLeft(target, _hexRadius), target);
    _grid.setTileState(target, TileState.occupied);

    // Refresh highlights so current tile stays unlit.
    _grid.clearAllHighlights();
    _updateHintHighlights();
  }

  void _tryMoveSeeker(AxialCoord target) {
    if (_seeker.isMoving) return;

    if (_isLeapModeActive) {
      final dist = target.distance(_seeker.currentCoord);
      if (dist > 0 &&
          dist <= 2 &&
          !_visited.contains(target) &&
          _grid.isValid(target)) {
        _isLeapModeActive = false;
        _moveSeeker(target);
      }
      return;
    }

    final moves = _grid.validMoves(_seeker.currentCoord, visited: _visited);
    if (!moves.contains(target)) return;
    _moveSeeker(target);
  }

  // ── Movement helpers ──────────────────────────────────────────────────────
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

    if (playerRole == PlayerRole.seeker) {
      final dist = next.distance(_hider.currentCoord);
      if (dist <= 1) {
        HapticFeedback.heavyImpact();
      } else if (dist == 2) {
        HapticFeedback.mediumImpact();
      }
    }

    _grid.clearAllHighlights();
    _updateHintHighlights();

    // Win check: seeker lands on hider's tile.
    if (next == _hider.currentCoord) {
      _hider.renderOpacity = 1.0; // reveal on catch
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
    // Always fully reveal the hider when the game ends.
    _hider.renderOpacity = 1.0;

    final isPlayerWin =
        (result == GamePhase.seekerWins && playerRole == PlayerRole.seeker) ||
        (result == GamePhase.hiderWins && playerRole == PlayerRole.hider);

    overlays.add(isPlayerWin ? overlayWin : overlayLose);
  }

  // ── Power-Up Actions ──────────────────────────────────────────────────────
  void useSonar() {
    if (usedSonar || _phase != GamePhase.seeking) return;
    usedSonar = true;
    powerupStateNotifier.value++;

    final hiderPos = _hider.currentCoord;
    for (final t in _grid.tiles.values) {
      if (t.coord.distance(hiderPos) <= 4) {
        t.isSonarPinged = true;
      }
    }

    Future.delayed(const Duration(seconds: 2), () {
      if (!isMounted) return;
      for (final t in _grid.tiles.values) {
        t.isSonarPinged = false;
      }
    });
  }

  void useLeap() {
    if (usedLeap || _phase != GamePhase.seeking) return;
    usedLeap = true;
    _isLeapModeActive = true;
    powerupStateNotifier.value++;
    _updateHintHighlights();
  }

  void useDecoyScan() {
    if (usedDecoyScan || _phase != GamePhase.seeking) return;
    usedDecoyScan = true;
    powerupStateNotifier.value++;

    final winningPath = HexPathfinder.findPath(
      from: _seeker.currentCoord,
      to: _hider.currentCoord,
      visited: _visited,
      grid: _grid,
    );
    final winSet = winningPath?.toSet() ?? {};

    for (final t in _grid.tiles.values) {
      if (t.state != TileState.visited && !winSet.contains(t.coord)) {
        t.isDecoyScanned = true;
      }
    }

    Future.delayed(const Duration(seconds: 3), () {
      if (!isMounted) return;
      for (final t in _grid.tiles.values) {
        t.isDecoyScanned = false;
      }
    });
  }

  // ── Highlight valid moves ─────────────────────────────────────────────────
  void _updateHintHighlights() {
    if (_phase == GamePhase.hiding && playerRole == PlayerRole.hider) {
      // All tiles are valid teleport targets — highlight everything except
      // the hider's current tile.
      for (final coord in _grid.tiles.keys) {
        if (coord != _hider.currentCoord) {
          _grid.setHighlighted(coord, true);
        }
      }
    } else if (_phase == GamePhase.seeking && playerRole == PlayerRole.seeker) {
      if (_isLeapModeActive) {
        for (final c in _grid.tiles.keys) {
          final dist = c.distance(_seeker.currentCoord);
          if (dist > 0 && dist <= 2 && !_visited.contains(c)) {
            _grid.setHighlighted(
              c,
              true,
              heat: c.distance(_hider.currentCoord) <= 2 ? 2 : 0,
            );
          }
        }
      } else {
        for (final c in _grid.validMoves(
          _seeker.currentCoord,
          visited: _visited,
        )) {
          final dist = c.distance(_hider.currentCoord);
          int heat = 0;
          if (dist <= 1) {
            heat = 3;
          } else if (dist == 2) {
            heat = 2;
          } else if (dist == 3) {
            heat = 1;
          }

          _grid.setHighlighted(c, true, heat: heat);
        }
      }
    }
  }

  // ── HUD text ──────────────────────────────────────────────────────────────
  String _buildHUD() {
    final lvl = 'LVL $level';
    switch (_phase) {
      case GamePhase.hiding:
        final s = _hideTimer.ceil();
        return '$lvl  HIDING — Find a safe spot!  ${s}s';
      case GamePhase.seeking:
        return playerRole == PlayerRole.seeker
            ? '$lvl  SEEKING — Tap an adjacent tile'
            : '$lvl  AI SEEKING — Watch the trail…';
      case GamePhase.seekerWins:
        return '🔍  SEEKER FOUND THE HIDER!';
      case GamePhase.hiderWins:
        return '🙈  HIDER ESCAPED — Seeker is trapped!';
    }
  }

  // ── Layout helpers ────────────────────────────────────────────────────────
  double _computeHexRadius() {
    const sqrt3 = 1.7320508;
    // Flat-top bounding box:
    //   width  = hexRadius * (1.5*(cols-1) + 2)
    //   height = hexRadius * sqrt3 * (0.5*(cols-1) + rows)
    final rFromWidth = (size.x - 48) / (1.5 * (_gridCols - 1) + 2);
    final rFromHeight =
        (size.y - 96) / (sqrt3 * (0.5 * (_gridCols - 1) + _gridRows));
    return min(rFromWidth, rFromHeight).clamp(10.0, 80.0);
  }

  Vector2 _computeGridOffset(double r) {
    const sqrt3 = 1.7320508;
    final gridW = r * (1.5 * (_gridCols - 1) + 2);
    final gridH = r * sqrt3 * (0.5 * (_gridCols - 1) + _gridRows);
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
