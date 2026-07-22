/// Mirrors WS_CONTRACT.md's `Rotation` enum ("DEG_0"|"DEG_90"|"DEG_180"|"DEG_270").
enum Rotation {
  deg0,
  deg90,
  deg180,
  deg270;

  String get wireName => switch (this) {
    Rotation.deg0 => 'DEG_0',
    Rotation.deg90 => 'DEG_90',
    Rotation.deg180 => 'DEG_180',
    Rotation.deg270 => 'DEG_270',
  };

  int get degrees => switch (this) {
    Rotation.deg0 => 0,
    Rotation.deg90 => 90,
    Rotation.deg180 => 180,
    Rotation.deg270 => 270,
  };

  static Rotation fromWire(Object? value) {
    return Rotation.values.firstWhere(
      (r) => r.wireName == value,
      orElse: () => Rotation.deg0,
    );
  }
}
