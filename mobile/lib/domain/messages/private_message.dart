// Typed WS_CONTRACT.md private messages (`/user/queue/game`) + defensive
// parsing. Regroup has no hidden information, so — unlike a reference project
// with secret state — there is nothing to strip for secrecy here; parsing is
// purely about tolerating malformed/partial frames and giving the app
// well-shaped values, mirroring the web client's messages.ts.

import '../models/board_point.dart';
import '../models/card.dart';
import '../models/market.dart';
import '../models/phase.dart';
import '../models/player.dart';

sealed class PrivateMessage {
  const PrivateMessage();

  static PrivateMessage? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    return switch (raw['type']) {
      'MATCH_FOUND' => MatchFoundMessage.fromJson(raw),
      'RESUME_STATE' => ResumeStateMessage.fromJson(raw),
      'ERROR' => ErrorMessage.fromJson(raw),
      _ => null,
    };
  }
}

class MatchFoundMessage extends PrivateMessage {
  final String matchId;
  final List<PlayerRef> players;
  final int yourSeat;

  const MatchFoundMessage({
    required this.matchId,
    required this.players,
    required this.yourSeat,
  });

  factory MatchFoundMessage.fromJson(Map<String, dynamic> json) {
    return MatchFoundMessage(
      matchId: json['matchId'] as String? ?? '',
      players: PlayerRef.listFromJson(json['players']),
      yourSeat: (json['yourSeat'] as num?)?.toInt() ?? 0,
    );
  }
}

class ResumeStateMessage extends PrivateMessage {
  final String matchId;
  final Phase phase;
  final int round;
  final int currentSeat;
  final bool finalRound;
  final List<PlayerState> players;
  final Map<String, List<BoardPoint>> boards;
  final Market market;
  final int deckRemaining;
  final Card? heldCard;

  const ResumeStateMessage({
    required this.matchId,
    required this.phase,
    required this.round,
    required this.currentSeat,
    required this.finalRound,
    required this.players,
    required this.boards,
    required this.market,
    required this.deckRemaining,
    required this.heldCard,
  });

  factory ResumeStateMessage.fromJson(Map<String, dynamic> json) {
    return ResumeStateMessage(
      matchId: json['matchId'] as String? ?? '',
      phase: Phase.fromWire(json['phase']),
      round: (json['round'] as num?)?.toInt() ?? 0,
      currentSeat: (json['currentSeat'] as num?)?.toInt() ?? 0,
      finalRound: json['finalRound'] == true,
      players: PlayerState.listFromJson(json['players']),
      boards: _parseBoards(json['boards']),
      market: Market.fromJson(json['market']),
      deckRemaining: (json['deckRemaining'] as num?)?.toInt() ?? 0,
      heldCard: Card.tryFromJson(json['heldCard']),
    );
  }

  static Map<String, List<BoardPoint>> _parseBoards(Object? json) {
    final out = <String, List<BoardPoint>>{};
    if (json is! Map<String, dynamic>) return out;
    for (final entry in json.entries) {
      final cells = entry.value;
      if (cells is! List) continue;
      out[entry.key] = cells
          .whereType<Map<String, dynamic>>()
          .map(BoardPoint.fromJson)
          .toList();
    }
    return out;
  }
}

class ErrorMessage extends PrivateMessage {
  final String code;
  final String message;

  const ErrorMessage({required this.code, required this.message});

  factory ErrorMessage.fromJson(Map<String, dynamic> json) {
    return ErrorMessage(
      code: json['code'] as String? ?? '',
      message: json['message'] as String? ?? '',
    );
  }
}
