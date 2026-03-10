import 'dart:math';

import 'package:flame/components.dart';

import '../core/hex_coords.dart';
import 'hex_tile_component.dart';
import 'wall_component.dart';

typedef TileCallback = void Function(AxialCoord coord);

/// Manages the entire 12×12 hex grid, wall placement, and movement queries.
///
/// This is a plain [Component] (no own position/size) so its children's
/// screen-space positions are used as-is.
class GridManager extends Component {
  final int gridSize;
  final double hexRadius;

  /// Pixel offset applied to every tile centre so the grid is centred on screen.
  final Vector2 gridOffset;

  /// All tiles indexed by their [AxialCoord].
  final Map<AxialCoord, HexTileComponent> tiles = {};

  /// Canonical wall set – each pair stored once (smaller q first, tie-break r).
  final Set<String> _walls = {};

  /// Called when the player taps a tile.
  TileCallback? onTileTapped;

  GridManager({
    required this.gridSize,
    required this.hexRadius,
    required this.gridOffset,
  });

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _buildTiles();
  }

  void _buildTiles() {
    for (int q = 0; q < gridSize; q++) {
      for (int r = 0; r < gridSize; r++) {
        final coord = AxialCoord(q, r);
        final center = tileCenter(coord);
        // PositionComponent.position is top-left of bounding box.
        final topLeft = center - Vector2(hexRadius, sqrt(3) / 2 * hexRadius);
        final tile = HexTileComponent(
          coord: coord,
          position: topLeft,
          hexRadius: hexRadius,
          onTapped: (c) => onTileTapped?.call(c),
        );
        tiles[coord] = tile;
        add(tile);
      }
    }
  }

  // ── Coordinate conversion ──────────────────────────────────────────────────

  /// Screen-space centre of the hex at [coord].
  Vector2 tileCenter(AxialCoord coord) =>
      axialToPixel(coord, hexRadius, offset: gridOffset);

  // ── Wall API ───────────────────────────────────────────────────────────────

  void addWall(AxialCoord a, AxialCoord b) {
    _walls.add(_key(a, b));
    final ca = tileCenter(a);
    final cb = tileCenter(b);
    add(WallComponent(coordA: a, coordB: b, centerA: ca, centerB: cb));
  }

  bool isWalled(AxialCoord a, AxialCoord b) => _walls.contains(_key(a, b));

  String _key(AxialCoord a, AxialCoord b) {
    // Canonical: smaller q first; tie-break by r.
    if (a.q < b.q || (a.q == b.q && a.r <= b.r)) {
      return '${a.q},${a.r}-${b.q},${b.r}';
    }
    return '${b.q},${b.r}-${a.q},${a.r}';
  }

  // ── Grid queries ───────────────────────────────────────────────────────────

  bool isValid(AxialCoord c) =>
      c.q >= 0 && c.q < gridSize && c.r >= 0 && c.r < gridSize;

  /// Returns valid moves from [from], optionally excluding [visited] tiles
  /// (the Seeker's no-repeat rule).
  List<AxialCoord> validMoves(AxialCoord from, {Set<AxialCoord>? visited}) {
    final result = <AxialCoord>[];
    for (final nb in from.neighbours()) {
      if (!isValid(nb)) continue;
      if (isWalled(from, nb)) continue;
      if (visited != null && visited.contains(nb)) continue;
      result.add(nb);
    }
    return result;
  }

  // ── Tile state helpers ─────────────────────────────────────────────────────

  void setTileState(AxialCoord coord, TileState state) {
    tiles[coord]?.state = state;
  }

  TileState? getTileState(AxialCoord coord) => tiles[coord]?.state;

  void setHighlighted(AxialCoord coord, bool value) {
    tiles[coord]?.isHighlighted = value;
  }

  void clearAllHighlights() {
    for (final t in tiles.values) {
      t.isHighlighted = false;
    }
  }
}
