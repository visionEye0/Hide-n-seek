import '../components/grid_manager.dart';
import '../core/hex_coords.dart';
import '../utils/pathfinder.dart';

/// AI controller for the Seeker role.
///
/// Uses modified A* (respecting the no-repeat rule) to navigate toward the
/// hider.  If no path exists the seeker is trapped → Hider wins.
class SeekerAI {
  final GridManager grid;

  SeekerAI({required this.grid});

  double _elapsed = 0;

  /// Delay between AI moves so the player can watch the trail form.
  static const double movePeriod = 0.72; // seconds

  /// Call every tick during the seeking phase.
  /// [seekerPos] current seeker position.
  /// [hiderPos]  known hider position (used for A* goal).
  /// [visited]   tiles already visited by the seeker.
  ///
  /// Returns the [AxialCoord] to move to, or null if it's not yet time
  /// or there are no valid moves.
  AxialCoord? update(
    double dt,
    AxialCoord seekerPos,
    AxialCoord hiderPos,
    Set<AxialCoord> visited,
  ) {
    _elapsed += dt;
    if (_elapsed < movePeriod) return null;
    _elapsed = 0;

    return HexPathfinder.bestSeekerMove(
      from: seekerPos,
      target: hiderPos,
      grid: grid,
      visited: visited,
    );
  }

  /// Returns true when the seeker has no moves remaining (hider wins).
  bool isTrapped(AxialCoord seekerPos, Set<AxialCoord> visited) =>
      grid.validMoves(seekerPos, visited: visited).isEmpty;

  void reset() => _elapsed = 0;
}
