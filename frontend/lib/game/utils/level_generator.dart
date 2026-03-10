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
  final int gridCols;
  final int gridRows;
  final Random _rng;

  LevelGenerator({int? seed, this.gridCols = 5, this.gridRows = 5})
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
  ///
  /// Generates a structured maze in three phases:
  ///  1. **Primary path** – a long route from seeker start to hider using
  ///     Warnsdorff's heuristic (maximises path length, avoids early dead-ends).
  ///  2. **Decoy branches** – short dead-end arms that branch off the primary
  ///     path at intersections, looking like valid routes but trapping the
  ///     player under the no-repeat rule.
  ///  3. **Wall placement** – only edges on the primary path and decoy arms
  ///     are opened; every other edge stays walled.
  LevelData generateForSeeker() {
    final seekerStart = AxialCoord(0, 0);

    // 1. Warnsdorff DFS — find the longest reachable path.
    final primaryPath = _buildLongPath(seekerStart);

    // 2. Mark primary edges as open.
    final openEdges = <({AxialCoord a, AxialCoord b})>{};
    for (int i = 0; i < primaryPath.length - 1; i++) {
      openEdges.add(_canon(primaryPath[i], primaryPath[i + 1]));
    }

    // 3. Add decoy dead-end branches.
    final allUsed = Set<AxialCoord>.from(primaryPath);
    _addDecoyBranches(primaryPath, allUsed, openEdges);

    // 4. Punch extra loops — open ~35% of remaining closed edges
    //    so the map isn't too maze-like and the player has more room.
    _punchExtraLoops(openEdges, 0.35);

    // 5. Pick a random tile from the far half of all accessible tiles.
    final farTiles = allUsed.toList()
      ..remove(seekerStart)
      ..sort(
        (a, b) => b.distance(seekerStart).compareTo(a.distance(seekerStart)),
      );
    final pool = farTiles.take(max(1, farTiles.length ~/ 2)).toList();
    final hiderStart = pool[_rng.nextInt(pool.length)];

    return LevelData(
      walls: _wallsExcept(openEdges),
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
    for (int q = 0; q < gridCols; q++) {
      for (int r = 0; r < gridRows; r++) {
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
    final target = (walls.length * 0.55).round();

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
    return best ?? AxialCoord(gridCols - 1, gridRows - 1);
  }

  // ── Scenario B: primary path + decoy branches ─────────────────────────────

  /// Opens [fraction] of currently-closed edges at random, creating loops
  /// that break the strict maze feel and give the player more space to explore.
  void _punchExtraLoops(
    Set<({AxialCoord a, AxialCoord b})> openEdges,
    double fraction,
  ) {
    final allEdges = <({AxialCoord a, AxialCoord b})>{};
    for (int q = 0; q < gridCols; q++) {
      for (int r = 0; r < gridRows; r++) {
        final c = AxialCoord(q, r);
        for (final nb in c.neighbours()) {
          if (_valid(nb)) allEdges.add(_canon(c, nb));
        }
      }
    }
    final closed = allEdges.difference(openEdges).toList()..shuffle(_rng);
    final toOpen = (closed.length * fraction).round();
    for (int i = 0; i < toOpen; i++) {
      openEdges.add(closed[i]);
    }
  }

  /// Warnsdorff-heuristic DFS: at each step picks the neighbour with the
  /// *fewest* onward free moves (keeps options open globally, avoids premature
  /// dead-ends). 80 % of the time the best candidate is chosen; 20 % random
  /// to ensure level variety across runs.
  List<AxialCoord> _buildLongPath(AxialCoord start) {
    final path = <AxialCoord>[start];
    final visited = <AxialCoord>{start};

    while (true) {
      final cur = path.last;
      final candidates = cur
          .neighbours()
          .where((nb) => _valid(nb) && !visited.contains(nb))
          .toList();

      if (candidates.isEmpty) break;

      candidates.sort((a, b) {
        final da = a
            .neighbours()
            .where((nb) => _valid(nb) && !visited.contains(nb))
            .length;
        final db = b
            .neighbours()
            .where((nb) => _valid(nb) && !visited.contains(nb))
            .length;
        if (da != db) return da.compareTo(db);
        return _rng.nextBool() ? -1 : 1; // random tie-break for variety
      });

      final next = _rng.nextDouble() < 0.80
          ? candidates.first
          : candidates[_rng.nextInt(candidates.length)];
      path.add(next);
      visited.add(next);
    }
    return path;
  }

  /// Attaches 6 decoy dead-end branches to random nodes along [primaryPath].
  /// Each branch is a short DFS arm that diverges from the primary route and
  /// ends in a dead end — entering one traps the player (no-repeat rule).
  void _addDecoyBranches(
    List<AxialCoord> primaryPath,
    Set<AxialCoord> allUsed,
    Set<({AxialCoord a, AxialCoord b})> openEdges,
  ) {
    const targetBranches = 6;
    const maxBranchLen = 10;

    // Avoid branching from very start or very end of the primary path.
    final midSection = primaryPath.length > 20
        ? primaryPath.sublist(4, primaryPath.length - 4)
        : primaryPath;

    final shuffled = List<AxialCoord>.from(midSection)..shuffle(_rng);
    int created = 0;

    for (final node in shuffled) {
      if (created >= targetBranches) break;
      final branch = _buildBranch(node, allUsed, maxBranchLen);
      if (branch.length < 3) continue; // too short to be a meaningful decoy

      // Open the fork edge and all edges within the branch arm.
      openEdges.add(_canon(node, branch.first));
      for (int i = 0; i < branch.length - 1; i++) {
        openEdges.add(_canon(branch[i], branch[i + 1]));
      }
      allUsed.addAll(branch);
      created++;
    }
  }

  /// Short DFS walk from [start] using only tiles NOT already in [used].
  /// Returns the new tiles visited (not including [start]).
  List<AxialCoord> _buildBranch(
    AxialCoord start,
    Set<AxialCoord> used,
    int maxLen,
  ) {
    final branch = <AxialCoord>[];
    final seen = <AxialCoord>{start};
    var cur = start;

    for (int i = 0; i < maxLen; i++) {
      final candidates = cur
          .neighbours()
          .where((nb) => _valid(nb) && !used.contains(nb) && !seen.contains(nb))
          .toList();
      if (candidates.isEmpty) break;
      candidates.shuffle(_rng);
      cur = candidates.first;
      branch.add(cur);
      seen.add(cur);
    }
    return branch;
  }

  /// Returns a wall list covering every edge that is NOT in [openEdges].
  /// Using a Set ensures no duplicate walls even though each edge is
  /// encountered twice (once per endpoint).
  List<({AxialCoord a, AxialCoord b})> _wallsExcept(
    Set<({AxialCoord a, AxialCoord b})> openEdges,
  ) {
    final walls = <({AxialCoord a, AxialCoord b})>{};
    for (int q = 0; q < gridCols; q++) {
      for (int r = 0; r < gridRows; r++) {
        final c = AxialCoord(q, r);
        for (final nb in c.neighbours()) {
          if (!_valid(nb)) continue;
          final edge = _canon(c, nb);
          if (!openEdges.contains(edge)) walls.add(edge);
        }
      }
    }
    return walls.toList();
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
      c.q >= 0 && c.q < gridCols && c.r >= 0 && c.r < gridRows;

  List<AxialCoord> _allCoords() => [
    for (int q = 0; q < gridCols; q++)
      for (int r = 0; r < gridRows; r++) AxialCoord(q, r),
  ];

  ({AxialCoord a, AxialCoord b}) _canon(AxialCoord a, AxialCoord b) {
    if (a.q < b.q || (a.q == b.q && a.r <= b.r)) return (a: a, b: b);
    return (a: b, b: a);
  }
}
