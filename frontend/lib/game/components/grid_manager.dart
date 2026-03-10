import 'dart:math';

import 'package:flame/components.dart';

import '../core/hex_coords.dart';
import 'hex_tile_component.dart';
import 'wall_component.dart';

typedef TileCallback = void Function(AxialCoord coord);

/// Manages a [gridCols]×[gridRows] hex grid, wall placement, and queries.
class GridManager extends Component {
  final int gridCols;
  final int gridRows;
  final double hexRadius;
  final Vector2 gridOffset;

  final Map<AxialCoord, HexTileComponent> tiles = {};
  final Set<String> _walls = {};
  TileCallback? onTileTapped;

  GridManager({
    required this.gridCols,
    required this.gridRows,
    required this.hexRadius,
    required this.gridOffset,
  });

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _buildTiles();
  }

  void _buildTiles() {
    for (int q = 0; q < gridCols; q++) {
      for (int r = 0; r < gridRows; r++) {
        final coord = AxialCoord(q, r);
        final center = tileCenter(coord);
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

  Vector2 tileCenter(AxialCoord coord) =>
      axialToPixel(coord, hexRadius, offset: gridOffset);

  void addWall(AxialCoord a, AxialCoord b) {
    _walls.add(_key(a, b));
    add(
      WallComponent(
        coordA: a,
        coordB: b,
        centerA: tileCenter(a),
        centerB: tileCenter(b),
      ),
    );
  }

  bool isWalled(AxialCoord a, AxialCoord b) => _walls.contains(_key(a, b));

  String _key(AxialCoord a, AxialCoord b) {
    if (a.q < b.q || (a.q == b.q && a.r <= b.r)) {
      return '${a.q},${a.r}-${b.q},${b.r}';
    }
    return '${b.q},${b.r}-${a.q},${a.r}';
  }

  bool isValid(AxialCoord c) =>
      c.q >= 0 && c.q < gridCols && c.r >= 0 && c.r < gridRows;

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

  void setTileState(AxialCoord coord, TileState state) {
    tiles[coord]?.state = state;
  }

  TileState? getTileState(AxialCoord coord) => tiles[coord]?.state;

  void setHighlighted(AxialCoord coord, bool value, {int heat = 0}) {
    if (tiles.containsKey(coord)) {
      tiles[coord]!.isHighlighted = value;
      tiles[coord]!.highlightHeat = heat;
    }
  }

  void clearAllHighlights() {
    for (final t in tiles.values) {
      t.isHighlighted = false;
      t.highlightHeat = 0;
    }
  }
}
