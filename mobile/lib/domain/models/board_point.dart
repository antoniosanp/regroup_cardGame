import 'corner_attribute.dart';

/// Spatial layout only (NOT a game rule): a single occupied cell on a
/// player's board lattice, x increasing right, y increasing up.
class BoardPoint {
  final int x;
  final int y;
  final CornerAttribute attribute;

  const BoardPoint({required this.x, required this.y, required this.attribute});

  String get key => pointKey(x, y);

  factory BoardPoint.fromJson(Map<String, dynamic> json) {
    return BoardPoint(
      x: (json['x'] as num?)?.toInt() ?? 0,
      y: (json['y'] as num?)?.toInt() ?? 0,
      attribute: CornerAttribute.fromWire(json['attribute']),
    );
  }
}

String pointKey(int x, int y) => '$x,$y';
