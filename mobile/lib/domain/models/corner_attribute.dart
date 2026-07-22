/// Mirrors WS_CONTRACT.md's `CornerAttribute` symbols exactly (see backend/gameRules.md).
enum CornerAttribute {
  empty,
  hpPotionCoin,
  coins2,
  pa1,
  pa2,
  pd1,
  pd2,
  ma1,
  ma2,
  md1,
  md2;

  String get wireName => switch (this) {
    CornerAttribute.empty => 'EMPTY',
    CornerAttribute.hpPotionCoin => 'HP_POTION_COIN',
    CornerAttribute.coins2 => 'COINS_2',
    CornerAttribute.pa1 => 'PA_1',
    CornerAttribute.pa2 => 'PA_2',
    CornerAttribute.pd1 => 'PD_1',
    CornerAttribute.pd2 => 'PD_2',
    CornerAttribute.ma1 => 'MA_1',
    CornerAttribute.ma2 => 'MA_2',
    CornerAttribute.md1 => 'MD_1',
    CornerAttribute.md2 => 'MD_2',
  };

  /// Human-readable label, used as a tooltip/accessibility label.
  String get label => switch (this) {
    CornerAttribute.empty => 'Empty',
    CornerAttribute.hpPotionCoin => '1 HP potion + 1 coin',
    CornerAttribute.coins2 => '2 coins',
    CornerAttribute.pa1 => '1 physical attack',
    CornerAttribute.pa2 => '2 physical attack',
    CornerAttribute.pd1 => '1 physical defense',
    CornerAttribute.pd2 => '2 physical defense',
    CornerAttribute.ma1 => '1 magic attack',
    CornerAttribute.ma2 => '2 magic attack',
    CornerAttribute.md1 => '1 magic defense',
    CornerAttribute.md2 => '2 magic defense',
  };

  static CornerAttribute fromWire(Object? value) {
    return CornerAttribute.values.firstWhere(
      (a) => a.wireName == value,
      orElse: () => CornerAttribute.empty,
    );
  }
}
