/// A pure damage instance from the all-vs-all battle resolution
/// (WS_CONTRACT.md's documented ruling): every attacker->defender pair,
/// computed from one shared pre-battle stat snapshot. Per-player results
/// (final hp, who healed, who died) are NOT here — see [BattleOutcome],
/// since a defender can be hit by several attackers and healedHp is a
/// once-per-player value.
class BattleAttack {
  final String attackerId;
  final String defenderId;
  final int physicalDamage;
  final int magicDamage;
  final int totalDamage;

  const BattleAttack({
    required this.attackerId,
    required this.defenderId,
    required this.physicalDamage,
    required this.magicDamage,
    required this.totalDamage,
  });

  factory BattleAttack.fromJson(Map<String, dynamic> json) {
    return BattleAttack(
      attackerId: json['attackerId'] as String? ?? '',
      defenderId: json['defenderId'] as String? ?? '',
      physicalDamage: (json['physicalDamage'] as num?)?.toInt() ?? 0,
      magicDamage: (json['magicDamage'] as num?)?.toInt() ?? 0,
      totalDamage: (json['totalDamage'] as num?)?.toInt() ?? 0,
    );
  }

  static List<BattleAttack> listFromJson(Object? json) {
    if (json is! List) return const [];
    return json
        .whereType<Map<String, dynamic>>()
        .map(BattleAttack.fromJson)
        .toList();
  }
}

/// One row per player who was alive at the start of the battle: hp before,
/// total damage taken from every attacker, how much they healed (0 if
/// eliminated), and their authoritative final hp. Derive post-battle hp from
/// here, not by summing [BattleAttack.totalDamage] client-side.
class BattleOutcome {
  final String playerId;
  final int hpBefore;
  final int damageTaken;
  final int healedHp;
  final int hpAfter;
  final bool eliminated;

  const BattleOutcome({
    required this.playerId,
    required this.hpBefore,
    required this.damageTaken,
    required this.healedHp,
    required this.hpAfter,
    required this.eliminated,
  });

  factory BattleOutcome.fromJson(Map<String, dynamic> json) {
    return BattleOutcome(
      playerId: json['playerId'] as String? ?? '',
      hpBefore: (json['hpBefore'] as num?)?.toInt() ?? 0,
      damageTaken: (json['damageTaken'] as num?)?.toInt() ?? 0,
      healedHp: (json['healedHp'] as num?)?.toInt() ?? 0,
      hpAfter: (json['hpAfter'] as num?)?.toInt() ?? 0,
      eliminated: json['eliminated'] == true,
    );
  }

  static List<BattleOutcome> listFromJson(Object? json) {
    if (json is! List) return const [];
    return json
        .whereType<Map<String, dynamic>>()
        .map(BattleOutcome.fromJson)
        .toList();
  }
}
