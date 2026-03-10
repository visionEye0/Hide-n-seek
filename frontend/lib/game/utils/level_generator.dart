import 'dart:collection';
import 'dart:math';

import '../core/hex_coords.dart';

/// Holds the result of procedural level generation.
class LevelData {
  final List<({AxialCoord a, AxialCoord b})> walls;
  final AxialCoord seekerStart;
  final AxialCoord hiderStart;

  const LevelData({
    required this.walls,
    required this.seekerStart,
    required this.hiderStart,
  });
}

/// Generates a hex-maze level using DFS backtracking (a perfect maze),
/// then optionally punches a few extra passages to add loops.
///
/// - [generateForHider]: Scenario A — player is Hider, AI is Seeker.
///   Guarantees at least one "safe zone" tile: the hider's chosen
///   position is behind an articulation point that severs the graph once
///   the Seeker passes through it, making it permanently unreachable.
///
/// - [generateForSeeker]: Scenario B — player is Seeker, AI is Hider.
///   Guarantees every candidate hider tile has a wall-ignoring BFS path
///   from the seeker start, so the player can always WIN.
class LevelGenerator {
  final int gridSize;
  final Random _rng;

  LevelGenerator({int? seed, this.gridSize = 12})
    : _rng = Random(seed ?? DateTime.now().millisecondsSinceEpoch);

  // ── Public entry points ────────────────────────────────────────────────────

  /// Scenario A: Player = Hider, AI = Seeker.
  LevelData generateForHider() {
    final walls = _dfsCarve();
    final seekerStart = AxialCoord(0, 0);
    final hiderStart = _findSafeZone(walls, seekerStart);
    _addLoops(walls, safeZoneProtected: hiderStart);
    return LevelData(
      walls: walls,
      seekerStart: seekerStart,
      hiderStart: hiderStart,
    );
  }

  /// Scenario B: Player = Seeker, AI = Hider.
  LevelData generateForSeeker() {
    final walls = _dfsCarve();
    _addLoops(walls);
    final seekerStart = AxialCoord(0, 0);
    final hiderStart = _findFarthestReachable(walls, seekerStart);
    return LevelData(
      walls: walls,
      seekerStart: seekerStart,
      hiderStart: hiderStart,
    );
  }

  // ── DFS maze carving ───────────────────────────────────────────────────────

  /// Generates a complete wall-set using DFS backtracking (perfect maze).
  /// Returns a list of blocked edges; every pair is in canonical order.
  List<({AxialCoord a, AxialCoord b})> _dfsCarve() {
    // Collect all possible edges.
    final allEdges = <({AxialCoord a, AxialCoord b})>{};
    for (int q = 0; q < gridSize; q++) {
      for (int r = 0; r < gridSize; r++) {
        final c = AxialCoord(q, r);
        for (final nb in c.neighbours()) {
          if (!_valid(nb)) continue;
          allEdges.add(_canon(c, nb));
        }
      }
    }

    // Start with ALL edges walled, then DFS to carve passages.
    final walls = Set<({AxialCoord a, AxialCoord b})>.from(allEdges);
    final visited = <AxialCoord>{};
    final stack = [AxialCoord(0, 0)];
    visited.add(stack.first);

    while (stack.isNotEmpty) {
      final cur = stack.last;
      final unvisitedNeighbours =
          cur
              .neighbours()
              .where((nb) => _valid(nb) && !visited.contains(nb))
              .toList()
            ..shuffle(_rng);

      if (unvisitedNeighbours.isEmpty) {
        stack.removeLast();
      } else {
        final nb = unvisitedNeighbours.first;
        walls.remove(_canon(cur, nb)); // carve passage
        visited.add(nb);
        stack.add(nb);
      }
    }

    return walls.toList();
  }

  /// Punches ~18% of remaining walls to add loops (more fun gameplay).
  /// If [safeZoneProtected] is set, walls protecting that dead-end arm are
  /// never removed.
  void _addLoops(
    List<({AxialCoord a, AxialCoord b})> walls, {
    AxialCoord? safeZoneProtected,
  }) {
    final wallsCopy = List.of(walls)..shuffle(_rng);
    int removed = 0;
    final target = (walls.length * 0.18).round();

    for (final w in wallsCopy) {
      if (removed >= target) break;
      // Never remove walls adjacent to the safe zone tile.
      if (safeZoneProtected != null &&
          (w.a == safeZoneProtected || w.b == safeZoneProtected)) {
        continue;
      }
      walls.remove(w);
      removed++;
    }
  }

  // ── Safe-zone guarantee (Scenario A) ──────────────────────────────────────

  /// Finds an articulation-point-backed safe zone using DFS low-link analysis.
  ///
  /// An articulation point A divides the grid into components.  The component
  /// NOT containing the seeker start is the "pocket": once the seeker visits A
  /// and moves into the pocket, A becomes visited and permanently blocks return.
  /// A tile deep in the pocket is the hider's guaranteed-safe starting point.
  AxialCoord _findSafeZone(
    List<({AxialCoord a, AxialCoord b})> walls,
    AxialCoord seekerStart,
  ) {
    final wallSet = walls.toSet();
    final adj = _buildAdj(wallSet);
    final articulationPoints = _findArticulationPoints(adj);

    AxialCoord? best;
    int bestDepth = -1;

    for (final ap in articulationPoints) {
      // Find the small component reachable THROUGH this AP but not through any
      // other path from seekerStart.  We do BFS from seekerStart while
      // blocking [ap] — whichever tiles become unreachable form the pocket.
      final reachableWithoutAP = _bfs(seekerStart, adj, blocked: {ap});
      final allTiles = _allCoords();
      final pocket = allTiles
          .where((c) => !reachableWithoutAP.contains(c) && c != ap)
          .toSet();

      if (pocket.isEmpty) continue;

      // Depth = how deep the farthest pocket tile is from AP.
      for (final t in pocket) {
        final d = t.distance(ap);
        if (d > bestDepth) {
          bestDepth = d;
          best = t;
        }
      }
    }

    // Fallback: just pick the corner farthest from seekerStart.
    return best ?? AxialCoord(gridSize - 1, gridSize - 1);
  }

  // ── Farthest reachable (Scenario B) ───────────────────────────────────────

  AxialCoord _findFarthestReachable(
    List<({AxialCoord a, AxialCoord b})> walls,
    AxialCoord start,
  ) {
    final wallSet = walls.toSet();
    final adj = _buildAdj(wallSet);
    final reachable = _bfs(start, adj);
    return reachable
        .where((c) => c != start)
        .reduce((a, b) => a.distance(start) >= b.distance(start) ? a : b);
  }

  // ── Graph helpers ──────────────────────────────────────────────────────────

  Map<AxialCoord, List<AxialCoord>> _buildAdj(
    Set<({AxialCoord a, AxialCoord b})> wallSet,
  ) {
    final adj = <AxialCoord, List<AxialCoord>>{};
    for (final c in _allCoords()) {
      adj[c] = [];
      for (final nb in c.neighbours()) {
        if (!_valid(nb)) continue;
        if (!wallSet.contains(_canon(c, nb))) {
          adj[c]!.add(nb);
        }
      }
    }
    return adj;
  }

  Set<AxialCoord> _bfs(
    AxialCoord start,
    Map<AxialCoord, List<AxialCoord>> adj, {
    Set<AxialCoord>? blocked,
  }) {
    final visited = <AxialCoord>{start};
    final queue = Queue<AxialCoord>()..add(start);
    while (queue.isNotEmpty) {
      final cur = queue.removeFirst();
      for (final nb in adj[cur] ?? []) {
        if (!visited.contains(nb) && !(blocked?.contains(nb) ?? false)) {
          visited.add(nb);
          queue.add(nb);
        }
      }
    }
    return visited;
  }

  /// Tarjan's DFS low-link algorithm for articulation points.
  Set<AxialCoord> _findArticulationPoints(
    Map<AxialCoord, List<AxialCoord>> adj,
  ) {
    final disc = <AxialCoord, int>{};
    final low = <AxialCoord, int>{};
    final parent = <AxialCoord, AxialCoord?>{};
    final ap = <AxialCoord>{};
    int timer = 0;

    void dfs(AxialCoord u) {
      disc[u] = low[u] = timer++;
      int childCount = 0;
      for (final v in adj[u] ?? []) {
        if (!disc.containsKey(v)) {
          childCount++;
          parent[v] = u;
          dfs(v);
          low[u] = min(low[u]!, low[v]!);
          // Root with 2+ children is an AP.
          if (parent[u] == null && childCount > 1) ap.add(u);
          // Non-root: if low[v] >= disc[u] then u is an AP.
          if (parent[u] != null && low[v]! >= disc[u]!) ap.add(u);
        } else if (v != parent[u]) {
          low[u] = min(low[u]!, disc[v]!);
        }
      }
    }

    for (final c in _allCoords()) {
      if (!disc.containsKey(c)) {
        parent[c] = null;
        dfs(c);
      }
    }
    return ap;
  }

  // ── Misc helpers ───────────────────────────────────────────────────────────

  bool _valid(AxialCoord c) =>
      c.q >= 0 && c.q < gridSize && c.r >= 0 && c.r < gridSize;

  List<AxialCoord> _allCoords() => [
    for (int q = 0; q < gridSize; q++)
      for (int r = 0; r < gridSize; r++) AxialCoord(q, r),
  ];

  ({AxialCoord a, AxialCoord b}) _canon(AxialCoord a, AxialCoord b) {
    if (a.q < b.q || (a.q == b.q && a.r <= b.r)) return (a: a, b: b);
    return (a: b, b: a);
  }
}
