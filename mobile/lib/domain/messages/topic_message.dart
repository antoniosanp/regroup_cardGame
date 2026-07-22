// Typed WS_CONTRACT.md broadcast messages (`/topic/match.{matchId}`) +
// defensive parsing. Mirrors the web client's messages.ts `TopicMessage`.

import '../models/battle.dart';
import '../models/card.dart';
import '../models/corner_name.dart';
import '../models/market.dart';
import '../models/phase.dart';
import '../models/rotation.dart';
import '../models/stats.dart';

sealed class TopicMessage {
  const TopicMessage();

  static TopicMessage? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    return switch (raw['type']) {
      'ROUND_START' => RoundStartMessage.fromJson(raw),
      'TURN_START' => TurnStartMessage.fromJson(raw),
      'CARD_PICKED' => CardPickedMessage.tryFromJson(raw),
      'CARD_ROTATED' => CardRotatedMessage.fromJson(raw),
      'CARD_PLACED' => CardPlacedMessage.tryFromJson(raw),
      'STATS_UPDATED' => StatsUpdatedMessage.fromJson(raw),
      'BATTLE_RESULT' => BattleResultMessage.fromJson(raw),
      'PLAYER_ELIMINATED' => PlayerEliminatedMessage.fromJson(raw),
      'MATCH_RESULT' => MatchResultMessage.fromJson(raw),
      'PLAYER_DISCONNECTED' => PlayerDisconnectedMessage.fromJson(raw),
      'PLAYER_RECONNECTED' => PlayerReconnectedMessage.fromJson(raw),
      _ => null,
    };
  }
}

class RoundStartMessage extends TopicMessage {
  final int round;
  final int startingSeat;
  final bool finalRound;

  const RoundStartMessage({
    required this.round,
    required this.startingSeat,
    required this.finalRound,
  });

  factory RoundStartMessage.fromJson(Map<String, dynamic> json) {
    return RoundStartMessage(
      round: (json['round'] as num?)?.toInt() ?? 0,
      startingSeat: (json['startingSeat'] as num?)?.toInt() ?? 0,
      finalRound: json['finalRound'] == true,
    );
  }
}

class TurnStartMessage extends TopicMessage {
  final String playerId;
  final int seat;

  const TurnStartMessage({required this.playerId, required this.seat});

  factory TurnStartMessage.fromJson(Map<String, dynamic> json) {
    return TurnStartMessage(
      playerId: json['playerId'] as String? ?? '',
      seat: (json['seat'] as num?)?.toInt() ?? 0,
    );
  }
}

class CardPickedMessage extends TopicMessage {
  final String playerId;
  final Slot slot;
  final Card card;
  final Market market;
  final int deckRemaining;

  const CardPickedMessage({
    required this.playerId,
    required this.slot,
    required this.card,
    required this.market,
    required this.deckRemaining,
  });

  /// Returns null if `card` is missing/malformed — same defensive behavior as
  /// the web client, which drops CARD_PICKED frames it can't fully parse.
  static CardPickedMessage? tryFromJson(Map<String, dynamic> json) {
    final card = Card.tryFromJson(json['card']);
    if (card == null) return null;
    return CardPickedMessage(
      playerId: json['playerId'] as String? ?? '',
      slot: Slot.fromWire(json['slot']),
      card: card,
      market: Market.fromJson(json['market']),
      deckRemaining: (json['deckRemaining'] as num?)?.toInt() ?? 0,
    );
  }
}

class CardRotatedMessage extends TopicMessage {
  final String playerId;
  final Rotation rotation;

  const CardRotatedMessage({required this.playerId, required this.rotation});

  factory CardRotatedMessage.fromJson(Map<String, dynamic> json) {
    return CardRotatedMessage(
      playerId: json['playerId'] as String? ?? '',
      rotation: Rotation.fromWire(json['rotation']),
    );
  }
}

class CardPlacedMessage extends TopicMessage {
  final String playerId;
  final CornerName corner;
  final int x;
  final int y;
  final Card card;

  const CardPlacedMessage({
    required this.playerId,
    required this.corner,
    required this.x,
    required this.y,
    required this.card,
  });

  static CardPlacedMessage? tryFromJson(Map<String, dynamic> json) {
    final card = Card.tryFromJson(json['card']);
    if (card == null) return null;
    return CardPlacedMessage(
      playerId: json['playerId'] as String? ?? '',
      corner: CornerName.fromWire(json['corner']),
      x: (json['x'] as num?)?.toInt() ?? 0,
      y: (json['y'] as num?)?.toInt() ?? 0,
      card: card,
    );
  }
}

class StatsUpdatedMessage extends TopicMessage {
  final String playerId;
  final Stats stats;

  const StatsUpdatedMessage({required this.playerId, required this.stats});

  factory StatsUpdatedMessage.fromJson(Map<String, dynamic> json) {
    return StatsUpdatedMessage(
      playerId: json['playerId'] as String? ?? '',
      stats: Stats.fromJson(json['stats']),
    );
  }
}

class BattleResultMessage extends TopicMessage {
  final int round;
  final List<BattleAttack> attacks;
  final List<BattleOutcome> outcomes;

  const BattleResultMessage({
    required this.round,
    required this.attacks,
    required this.outcomes,
  });

  factory BattleResultMessage.fromJson(Map<String, dynamic> json) {
    return BattleResultMessage(
      round: (json['round'] as num?)?.toInt() ?? 0,
      attacks: BattleAttack.listFromJson(json['attacks']),
      outcomes: BattleOutcome.listFromJson(json['outcomes']),
    );
  }
}

class PlayerEliminatedMessage extends TopicMessage {
  final String playerId;
  final int finalHp;

  const PlayerEliminatedMessage({
    required this.playerId,
    required this.finalHp,
  });

  factory PlayerEliminatedMessage.fromJson(Map<String, dynamic> json) {
    return PlayerEliminatedMessage(
      playerId: json['playerId'] as String? ?? '',
      finalHp: (json['finalHp'] as num?)?.toInt() ?? 0,
    );
  }
}

class MatchResultMessage extends TopicMessage {
  final List<String> winners;
  final String reason;

  const MatchResultMessage({required this.winners, required this.reason});

  factory MatchResultMessage.fromJson(Map<String, dynamic> json) {
    final winners = json['winners'];
    return MatchResultMessage(
      winners: winners is List
          ? winners.whereType<String>().toList()
          : const [],
      reason: json['reason'] as String? ?? '',
    );
  }
}

class PlayerDisconnectedMessage extends TopicMessage {
  final String playerId;

  const PlayerDisconnectedMessage({required this.playerId});

  factory PlayerDisconnectedMessage.fromJson(Map<String, dynamic> json) {
    return PlayerDisconnectedMessage(
      playerId: json['playerId'] as String? ?? '',
    );
  }
}

class PlayerReconnectedMessage extends TopicMessage {
  final String playerId;

  const PlayerReconnectedMessage({required this.playerId});

  factory PlayerReconnectedMessage.fromJson(Map<String, dynamic> json) {
    return PlayerReconnectedMessage(
      playerId: json['playerId'] as String? ?? '',
    );
  }
}
