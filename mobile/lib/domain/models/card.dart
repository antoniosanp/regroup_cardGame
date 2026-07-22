import 'board_point.dart';
import 'corner_attribute.dart';
import 'corner_name.dart';
import 'rotation.dart';

/// A card's corner fields are always the current, already-oriented
/// arrangement (the server bakes rotation into them before broadcasting),
/// so `rotation` here is bookkeeping for the art transform only — it must
/// never be reapplied to topLeft/topRight/bottomLeft/bottomRight, or a
/// placement computed from the display would land on the wrong cells. The
/// one message that doesn't carry re-oriented corners is CARD_ROTATED; use
/// [rotateOnce] to mirror the server's own one-clockwise-step mutation.
class Card {
  final CornerAttribute topLeft;
  final CornerAttribute topRight;
  final CornerAttribute bottomLeft;
  final CornerAttribute bottomRight;
  final Rotation rotation;

  const Card({
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    required this.bottomRight,
    required this.rotation,
  });

  factory Card.fromJson(Map<String, dynamic> json) {
    return Card(
      topLeft: CornerAttribute.fromWire(json['topLeft']),
      topRight: CornerAttribute.fromWire(json['topRight']),
      bottomLeft: CornerAttribute.fromWire(json['bottomLeft']),
      bottomRight: CornerAttribute.fromWire(json['bottomRight']),
      rotation: Rotation.fromWire(json['rotation']),
    );
  }

  static Card? tryFromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return Card.fromJson(json);
  }

  CornerAttribute at(CornerName corner) => switch (corner) {
    CornerName.topLeft => topLeft,
    CornerName.topRight => topRight,
    CornerName.bottomLeft => bottomLeft,
    CornerName.bottomRight => bottomRight,
  };

  /// One clockwise quarter-turn of the corner arrangement — the exact client
  /// mirror of the backend's `Card.rotate()`. Only used when a CARD_ROTATED
  /// broadcast arrives, since that message carries the new rotation but not
  /// the re-oriented corners.
  Card rotateOnce(Rotation newRotation) {
    return Card(
      topLeft: bottomLeft,
      topRight: topLeft,
      bottomRight: topRight,
      bottomLeft: bottomRight,
      rotation: newRotation,
    );
  }
}

/// Solves for the card's own bottom-left lattice cell given which [corner]
/// anchors at board point ([x], [y]), then emits the four resulting points.
/// Mirrors the backend's CornerPosition offsets exactly
/// (backend/src/main/java/com/regroup/engine/BoardEngine.java#placeCard) —
/// this is spatial layout for display only; the server is authoritative for
/// legality.
List<BoardPoint> cardToPoints(Card card, CornerName corner, int x, int y) {
  int bx = x;
  int by = y;
  switch (corner) {
    case CornerName.topLeft:
      bx = x;
      by = y - 1;
    case CornerName.topRight:
      bx = x - 1;
      by = y - 1;
    case CornerName.bottomLeft:
      bx = x;
      by = y;
    case CornerName.bottomRight:
      bx = x - 1;
      by = y;
  }
  return [
    BoardPoint(x: bx, y: by, attribute: card.bottomLeft),
    BoardPoint(x: bx + 1, y: by, attribute: card.bottomRight),
    BoardPoint(x: bx, y: by + 1, attribute: card.topLeft),
    BoardPoint(x: bx + 1, y: by + 1, attribute: card.topRight),
  ];
}
