import 'dart:collection';

import '../components/grid_manager.dart';
import '../core/hex_coords.dart';

/// A* pathfinder adapted for the hex grid.
///
/// When [visited] is provided, those tiles are treated as impassable —
/// modelling the Seeker's "no-repeat" rule.
class HexPathfinder {
  /// Returns the shortest path from [from] to [to], or null if unreachable.
  static List<AxialCoord>? findPath({
    required AxialCoord from,
    required AxialCoord to,
    required GridManager grid,
    Set<AxialCoord>? visited,
  }) {
    if (from == to) return [from];

    // g-cost, f-cost and parent maps.
    final gScore = <AxialCoord, int>{from: 0};
    final fScore = <AxialCoord, int>{from: from.distance(to)};
    final cameFrom = <AxialCoord, AxialCoord>{};

    // Open set as a List used as a min-heap via manual sort on each add.
    // For a 12×12 grid (144 nodes) this is fast enough.
    final openSet = <AxialCoord>[from];
    final inOpen = <AxialCoord>{from};

    while (openSet.isNotEmpty) {
      // Pop node with lowest f-score.
      openSet.sort(
        (a, b) => (fScore[a] ?? 999999).compareTo(fScore[b] ?? 999999),
      );
      final current = openSet.removeAt(0);
      inOpen.remove(current);

      if (current == to) return _reconstruct(cameFrom, current);

      for (final nb in grid.validMoves(current, visited: visited)) {
        final tentative = (gScore[current] ?? 999999) + 1;
        if (tentative < (gScore[nb] ?? 999999)) {
          cameFrom[nb] = current;
          gScore[nb] = tentative;
          fScore[nb] = tentative + nb.distance(to);
          if (!inOpen.contains(nb)) {
            openSet.add(nb);
            inOpen.add(nb);
          }
        }
      }
    }
    return null;
  }

  static List<AxialCoord> _reconstruct(
    Map<AxialCoord, AxialCoord> cameFrom,
    AxialCoord current,
  ) {
    final path = [current];
    var node = current;
    while (cameFrom.containsKey(node)) {
      node = cameFrom[node]!;
      path.insert(0, node);
    }
    return path;
  }

  /// Returns the next best move for the Seeker toward [target],
  /// or null if completely trapped.
  static AxialCoord? bestSeekerMove({
    required AxialCoord from,
    required AxialCoord target,
    required GridManager grid,
    required Set<AxialCoord> visited,
  }) {
    final path = findPath(from: from, to: target, grid: grid, visited: visited);
    if (path != null && path.length >= 2) return path[1];

    // Fallback: pick any valid move that minimises raw hex distance.
    final moves = grid.validMoves(from, visited: visited);
    if (moves.isEmpty) return null;
    moves.sort((a, b) => a.distance(target).compareTo(b.distance(target)));
    return moves.first;
  }

  /// Returns the next best move for the Hider to maximise distance from [threat].
  static AxialCoord bestHiderMove({
    required AxialCoord from,
    required AxialCoord threat,
    required GridManager grid,
  }) {
    final moves = grid.validMoves(from);
    if (moves.isEmpty) return from;
    moves.sort((a, b) => b.distance(threat).compareTo(a.distance(threat)));
    return moves.first;
  }

  /// BFS reachability from [start] (wall-only, ignores visited rule).
  static Set<AxialCoord> reachableFrom(
    AxialCoord start,
    GridManager grid, {
    Set<AxialCoord>? blocked,
  }) {
    final seen = <AxialCoord>{start};
    final queue = Queue<AxialCoord>()..add(start);
    while (queue.isNotEmpty) {
      final cur = queue.removeFirst();
      for (final nb in grid.validMoves(cur)) {
        if (!seen.contains(nb) && !(blocked?.contains(nb) ?? false)) {
          seen.add(nb);
          queue.add(nb);
        }
      }
    }
    return seen;
  }
}
