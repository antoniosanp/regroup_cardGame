import '../domain/models/battle.dart';
import '../domain/models/board_point.dart';
import '../domain/models/card.dart' as domain;
import '../domain/models/identity.dart';
import '../domain/models/market.dart';
import '../domain/models/phase.dart';
import '../domain/models/player.dart';

enum ConnStatus { idle, connecting, connected, reconnecting, failed }

enum Stage { name, lobby, queue, match }

class GameError {
  final String code;
  final String message;

  const GameError({required this.code, required this.message});
}

class BattleVm {
  final int round;
  final List<BattleAttack> attacks;
  final List<BattleOutcome> outcomes;

  const BattleVm({
    required this.round,
    required this.attacks,
    required this.outcomes,
  });
}

/// All match-scoped fields reset to this whenever a new match starts
/// (MATCH_FOUND) — mirrors the web client's MATCH_RESET constant in
/// onlineStore.ts.
const _matchDefaults = (
  matchId: null,
  yourSeat: -1,
  players: <PlayerState>[],
  connected: <String, bool>{},
  phase: Phase.turn,
  round: 0,
  currentSeat: -1,
  startingSeat: -1,
  finalRound: false,
  boards: <String, List<BoardPoint>>{},
  market: Market.empty,
  deckRemaining: 0,
  heldCard: null,
  heldBy: null,
  busy: false,
  lastBattle: null,
  winners: null,
  reason: null,
);

/// Mirrors the web client's `OnlineState` (onlineStore.ts) — the backend is
/// the source of truth; this state only reflects WS_CONTRACT.md messages and
/// never computes game rules itself (no stat calculation, no placement
/// legality, no battle math — the server owns all of it).
class GameState {
  final ConnStatus conn;
  final Stage stage;
  final Identity? identity;
  final GameError? error;

  final String? matchId;
  final int yourSeat;
  final List<PlayerState> players;
  final Map<String, bool> connected;

  final Phase phase;
  final int round;
  final int currentSeat;
  final int startingSeat;
  final bool finalRound;

  final Map<String, List<BoardPoint>> boards;
  final Market market;
  final int deckRemaining;

  /// The in-progress card of whoever is acting. Public (no hidden info):
  /// learned from CARD_PICKED broadcasts for everyone, and from
  /// RESUME_STATE for self.
  final domain.Card? heldCard;
  final String? heldBy;

  /// In-flight pick/place lock to prevent double submits until the server
  /// echoes. See [GameNotifier]'s failsafe — this must never stick forever.
  final bool busy;

  final BattleVm? lastBattle;
  final List<String>? winners;
  final String? reason;

  const GameState({
    this.conn = ConnStatus.idle,
    this.stage = Stage.name,
    this.identity,
    this.error,
    this.matchId,
    this.yourSeat = -1,
    this.players = const [],
    this.connected = const {},
    this.phase = Phase.turn,
    this.round = 0,
    this.currentSeat = -1,
    this.startingSeat = -1,
    this.finalRound = false,
    this.boards = const {},
    this.market = Market.empty,
    this.deckRemaining = 0,
    this.heldCard,
    this.heldBy,
    this.busy = false,
    this.lastBattle,
    this.winners,
    this.reason,
  });

  GameState copyWith({
    ConnStatus? conn,
    Stage? stage,
    Object? identity = _unset,
    Object? error = _unset,
    Object? matchId = _unset,
    int? yourSeat,
    List<PlayerState>? players,
    Map<String, bool>? connected,
    Phase? phase,
    int? round,
    int? currentSeat,
    int? startingSeat,
    bool? finalRound,
    Map<String, List<BoardPoint>>? boards,
    Market? market,
    int? deckRemaining,
    Object? heldCard = _unset,
    Object? heldBy = _unset,
    bool? busy,
    Object? lastBattle = _unset,
    Object? winners = _unset,
    Object? reason = _unset,
  }) {
    return GameState(
      conn: conn ?? this.conn,
      stage: stage ?? this.stage,
      identity: identical(identity, _unset)
          ? this.identity
          : identity as Identity?,
      error: identical(error, _unset) ? this.error : error as GameError?,
      matchId: identical(matchId, _unset) ? this.matchId : matchId as String?,
      yourSeat: yourSeat ?? this.yourSeat,
      players: players ?? this.players,
      connected: connected ?? this.connected,
      phase: phase ?? this.phase,
      round: round ?? this.round,
      currentSeat: currentSeat ?? this.currentSeat,
      startingSeat: startingSeat ?? this.startingSeat,
      finalRound: finalRound ?? this.finalRound,
      boards: boards ?? this.boards,
      market: market ?? this.market,
      deckRemaining: deckRemaining ?? this.deckRemaining,
      heldCard: identical(heldCard, _unset)
          ? this.heldCard
          : heldCard as domain.Card?,
      heldBy: identical(heldBy, _unset) ? this.heldBy : heldBy as String?,
      busy: busy ?? this.busy,
      lastBattle: identical(lastBattle, _unset)
          ? this.lastBattle
          : lastBattle as BattleVm?,
      winners: identical(winners, _unset)
          ? this.winners
          : winners as List<String>?,
      reason: identical(reason, _unset) ? this.reason : reason as String?,
    );
  }

  /// Resets every match-scoped field back to its pre-match default while
  /// keeping connection/identity fields untouched — mirrors onlineStore.ts's
  /// `...MATCH_RESET` spread used on MATCH_FOUND/leave.
  GameState resetMatch() {
    return copyWith(
      matchId: _matchDefaults.matchId,
      yourSeat: _matchDefaults.yourSeat,
      players: _matchDefaults.players,
      connected: _matchDefaults.connected,
      phase: _matchDefaults.phase,
      round: _matchDefaults.round,
      currentSeat: _matchDefaults.currentSeat,
      startingSeat: _matchDefaults.startingSeat,
      finalRound: _matchDefaults.finalRound,
      boards: _matchDefaults.boards,
      market: _matchDefaults.market,
      deckRemaining: _matchDefaults.deckRemaining,
      heldCard: _matchDefaults.heldCard,
      heldBy: _matchDefaults.heldBy,
      busy: _matchDefaults.busy,
      lastBattle: _matchDefaults.lastBattle,
      winners: _matchDefaults.winners,
      reason: _matchDefaults.reason,
    );
  }
}

/// Sentinel distinguishing "not passed" from "explicitly passed null" in
/// [GameState.copyWith], since several fields are legitimately nullable
/// (identity, error, matchId, heldCard, heldBy, lastBattle, winners, reason).
const Object _unset = Object();
