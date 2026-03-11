import '../components/grid_manager.dart';
import '../core/hex_coords.dart';
import '../utils/pathfinder.dart';

/// AI controller for the Seeker role.
///
/// The AI has NO knowledge of the hider's position — it performs a
/// systematic grid exploration (nearest-unvisited BFS) to find the hider.
/// If every reachable tile has been visited the seeker is trapped → Hider wins.
class SeekerAI {
  final GridManager grid;

  SeekerAI({required this.grid});

  double _elapsed = 0;

  /// Delay between AI moves so the player can watch the trail build.
  static const double movePeriod = 0.72; // seconds

  /// Call every tick during the seeking phase.
  ///
  /// Returns the next [AxialCoord] the AI wants to move to, or null when
  /// it is not yet time to move.  Returns null permanently once trapped.
  AxialCoord? update(double dt, AxialCoord seekerPos, Set<AxialCoord> visited) {
    _elapsed += dt;
    if (_elapsed < movePeriod) return null;
    _elapsed = 0;

    // Blind exploration: find the nearest unvisited reachable tile.
    return HexPathfinder.nextExplorationStep(
      from: seekerPos,
      visited: visited,
      grid: grid,
    );
  }

  /// True when the seeker has no valid moves remaining → hider wins.
  bool isTrapped(AxialCoord seekerPos, Set<AxialCoord> visited) =>
      grid.validMoves(seekerPos, visited: visited).isEmpty;

  void reset() => _elapsed = 0;
}
