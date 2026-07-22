/// Mirrors WS_CONTRACT.md's `Stats` shape.
class Stats {
  final int hp;
  final int pa;
  final int pd;
  final int ma;
  final int md;
  final int cn;
  final int hpp;

  const Stats({
    required this.hp,
    required this.pa,
    required this.pd,
    required this.ma,
    required this.md,
    required this.cn,
    required this.hpp,
  });

  static const zero = Stats(hp: 0, pa: 0, pd: 0, ma: 0, md: 0, cn: 0, hpp: 0);

  /// The starting stats every player has before any card is placed.
  static const starting = Stats(
    hp: 30,
    pa: 0,
    pd: 0,
    ma: 0,
    md: 0,
    cn: 0,
    hpp: 0,
  );

  factory Stats.fromJson(Object? json) {
    final o = json is Map<String, dynamic> ? json : const <String, dynamic>{};
    return Stats(
      hp: (o['hp'] as num?)?.toInt() ?? 0,
      pa: (o['pa'] as num?)?.toInt() ?? 0,
      pd: (o['pd'] as num?)?.toInt() ?? 0,
      ma: (o['ma'] as num?)?.toInt() ?? 0,
      md: (o['md'] as num?)?.toInt() ?? 0,
      cn: (o['cn'] as num?)?.toInt() ?? 0,
      hpp: (o['hpp'] as num?)?.toInt() ?? 0,
    );
  }

  Stats copyWith({int? hp}) => Stats(
    hp: hp ?? this.hp,
    pa: pa,
    pd: pd,
    ma: ma,
    md: md,
    cn: cn,
    hpp: hpp,
  );
}
