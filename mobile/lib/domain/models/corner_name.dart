/// Mirrors WS_CONTRACT.md's `corner` field and the backend's `CornerPosition`
/// enum (backend/src/main/java/com/regroup/engine/CornerPosition.java).
/// Each corner's `offset` is the same integer lattice offset the backend uses
/// to anchor a card: BOTTOM_LEFT=(0,0), BOTTOM_RIGHT=(1,0), TOP_LEFT=(0,1),
/// TOP_RIGHT=(1,1). Never change these without checking BoardEngineTest.java
/// on the backend — they encode the exact placement shape the server expects.
enum CornerName {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight;

  String get wireName => switch (this) {
    CornerName.topLeft => 'TOP_LEFT',
    CornerName.topRight => 'TOP_RIGHT',
    CornerName.bottomLeft => 'BOTTOM_LEFT',
    CornerName.bottomRight => 'BOTTOM_RIGHT',
  };

  /// Integer lattice offset (dx, dy) relative to the card's own bottom-left cell.
  (int, int) get offset => switch (this) {
    CornerName.topLeft => (0, 1),
    CornerName.topRight => (1, 1),
    CornerName.bottomLeft => (0, 0),
    CornerName.bottomRight => (1, 0),
  };

  static CornerName fromWire(Object? value) {
    return CornerName.values.firstWhere(
      (c) => c.wireName == value,
      orElse: () => CornerName.topLeft,
    );
  }
}
