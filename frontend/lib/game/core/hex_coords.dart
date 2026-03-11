import 'dart:math';

import 'package:flame/components.dart';

/// Axial coordinate for a flat-top hex grid.
class AxialCoord {
  final int q;
  final int r;

  const AxialCoord(this.q, this.r);

  /// The 6 neighbour directions for a flat-top hex grid in axial coordinates.
  static const List<AxialCoord> directions = [
    AxialCoord(1, 0),
    AxialCoord(1, -1),
    AxialCoord(0, -1),
    AxialCoord(-1, 0),
    AxialCoord(-1, 1),
    AxialCoord(0, 1),
  ];

  /// Returns all 6 axial neighbours.
  List<AxialCoord> neighbours() =>
      directions.map((d) => AxialCoord(q + d.q, r + d.r)).toList();

  /// Cube-coordinate hex distance.
  int distance(AxialCoord other) {
    final dq = (q - other.q).abs();
    final dr = (r - other.r).abs();
    final ds = ((q + r) - (other.q + other.r)).abs();
    return (dq + dr + ds) ~/ 2;
  }

  AxialCoord operator +(AxialCoord other) =>
      AxialCoord(q + other.q, r + other.r);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AxialCoord && q == other.q && r == other.r);

  @override
  int get hashCode => Object.hash(q, r);

  @override
  String toString() => 'Axial($q,$r)';
}

/// Converts an axial coord to a screen-space pixel Vector2 (flat-top layout).
/// [hexRadius] is the circumradius (center-to-corner) of the hex.
/// [offset] shifts the whole grid (e.g. to centre it on screen).
Vector2 axialToPixel(AxialCoord c, double hexRadius, {Vector2? offset}) {
  final x = hexRadius * 1.5 * c.q;
  final y = hexRadius * (sqrt(3) / 2 * c.q + sqrt(3) * c.r);
  final result = Vector2(x, y);
  if (offset != null) result.add(offset);
  return result;
}
