/// Mirrors WS_CONTRACT.md's match phase.
enum Phase {
  turn,
  battle,
  matchOver;

  static Phase fromWire(Object? value) {
    return switch (value) {
      'BATTLE' => Phase.battle,
      'MATCH_OVER' => Phase.matchOver,
      _ => Phase.turn,
    };
  }
}

/// Mirrors WS_CONTRACT.md's pick `slot` field: A/B/C (market) or DECK (free face-down draw).
enum Slot {
  a,
  b,
  c,
  deck;

  String get wireName => switch (this) {
    Slot.a => 'A',
    Slot.b => 'B',
    Slot.c => 'C',
    Slot.deck => 'DECK',
  };

  static Slot fromWire(Object? value) {
    return switch (value) {
      'A' => Slot.a,
      'B' => Slot.b,
      'C' => Slot.c,
      _ => Slot.deck,
    };
  }
}
