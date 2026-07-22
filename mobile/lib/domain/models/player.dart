import 'stats.dart';

/// Mirrors WS_CONTRACT.md's `PlayerRef` shape (seen in MATCH_FOUND).
class PlayerRef {
  final String playerId;
  final String name;
  final int seat;

  const PlayerRef({
    required this.playerId,
    required this.name,
    required this.seat,
  });

  factory PlayerRef.fromJson(Map<String, dynamic> json) {
    return PlayerRef(
      playerId: json['playerId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      seat: (json['seat'] as num?)?.toInt() ?? 0,
    );
  }

  static List<PlayerRef> listFromJson(Object? json) {
    if (json is! List) return const [];
    return json
        .whereType<Map<String, dynamic>>()
        .map(PlayerRef.fromJson)
        .toList();
  }
}

/// Mirrors WS_CONTRACT.md's `PlayerState` shape (seen in RESUME_STATE).
class PlayerState {
  final String playerId;
  final String name;
  final int seat;
  final bool alive;
  final Stats stats;

  const PlayerState({
    required this.playerId,
    required this.name,
    required this.seat,
    required this.alive,
    required this.stats,
  });

  factory PlayerState.fromJson(Map<String, dynamic> json) {
    return PlayerState(
      playerId: json['playerId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      seat: (json['seat'] as num?)?.toInt() ?? 0,
      alive: json['alive'] != false,
      stats: Stats.fromJson(json['stats']),
    );
  }

  factory PlayerState.fromRef(PlayerRef ref) {
    return PlayerState(
      playerId: ref.playerId,
      name: ref.name,
      seat: ref.seat,
      alive: true,
      stats: Stats.starting,
    );
  }

  PlayerState copyWith({bool? alive, Stats? stats}) => PlayerState(
    playerId: playerId,
    name: name,
    seat: seat,
    alive: alive ?? this.alive,
    stats: stats ?? this.stats,
  );

  static List<PlayerState> listFromJson(Object? json) {
    if (json is! List) return const [];
    return json
        .whereType<Map<String, dynamic>>()
        .map(PlayerState.fromJson)
        .toList();
  }
}
