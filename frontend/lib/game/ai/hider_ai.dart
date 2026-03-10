import '../components/grid_manager.dart';
import '../core/hex_coords.dart';
import '../utils/pathfinder.dart';

/// AI controller for the Hider role.
///
/// During the 10-second hiding phase the AI hider greedily moves away from the
/// seeker's starting position every [movePeriod] seconds then stays put.
class HiderAI {
  final GridManager grid;
  final AxialCoord seekerStart;

  HiderAI({required this.grid, required this.seekerStart});

  double _elapsed = 0;
  static const double movePeriod = 1.2; // seconds between AI moves

  /// Call once per game tick during the hiding phase.
  /// Returns the [AxialCoord] the hider moved to, or null if no move was made.
  AxialCoord? update(double dt, AxialCoord hiderPos) {
    _elapsed += dt;
    if (_elapsed < movePeriod) return null;
    _elapsed = 0;

    final next = HexPathfinder.bestHiderMove(
      from: hiderPos,
      threat: seekerStart,
      grid: grid,
    );
    return (next != hiderPos) ? next : null;
  }

  void reset() => _elapsed = 0;
}
