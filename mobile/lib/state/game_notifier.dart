import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api_client.dart' as api;
import '../data/stomp_game_socket.dart';
import '../domain/messages/private_message.dart';
import '../domain/messages/topic_message.dart';
import '../domain/models/board_point.dart';
import '../domain/models/card.dart' as domain;
import '../domain/models/corner_name.dart';
import '../domain/models/identity.dart';
import '../domain/models/phase.dart';
import '../domain/models/player.dart';
import 'game_state.dart';

/// How long an optimistic pick/place lock is allowed to stay `true` with no
/// server response before it force-clears itself. Mirrors the same failsafe
/// added to the web client's `onlineStore.ts` (BE-03 bug fix): without this,
/// a single dropped/reordered WS frame leaves the player permanently unable
/// to act — not even the free deck pick — since every future pick()/place()
/// call silently no-ops while `busy` is stuck true.
const Duration _busyFailsafe = Duration(seconds: 8);

Map<String, List<BoardPoint>> _mergePoints(
  Map<String, List<BoardPoint>> boards,
  String playerId,
  List<BoardPoint> added,
) {
  final existing = boards[playerId] ?? const <BoardPoint>[];
  final byKey = {for (final p in existing) p.key: p};
  for (final p in added) {
    byKey[p.key] = p;
  }
  return {...boards, playerId: byKey.values.toList()};
}

/// Orchestrates the online match over STOMP: the backend is the single
/// source of truth. This notifier never computes game rules itself (no stat
/// calculation, no placement legality, no battle math) — it only reflects
/// WS_CONTRACT.md messages into [GameState] and translates UI actions into
/// wire messages. Mirrors the web client's `onlineStore.ts` action-by-action.
class GameNotifier extends StateNotifier<GameState> {
  final GameSocket Function() _socketFactory;
  GameSocket? _socket;
  Timer? _busyFailsafeTimer;

  GameNotifier({GameSocket Function()? socketFactory})
    : _socketFactory = socketFactory ?? StompGameSocket.new,
      super(const GameState());

  @override
  void dispose() {
    _busyFailsafeTimer?.cancel();
    _socket?.deactivate();
    super.dispose();
  }

  Future<void> start(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    state = state.copyWith(error: null, conn: ConnStatus.connecting);
    try {
      final stored = await api.loadIdentity();
      final identity = stored != null && stored.name == trimmed
          ? stored
          : await api.registerPlayer(trimmed);
      await api.saveIdentity(identity);
      state = state.copyWith(identity: identity);
      _connect(identity);
    } catch (e) {
      await api.clearIdentity();
      state = state.copyWith(
        conn: ConnStatus.failed,
        error: GameError(code: 'REGISTER_FAILED', message: '$e'),
      );
    }
  }

  /// Connects with an identity already held (e.g. loaded from storage)
  /// without a fresh HTTP registration round trip.
  void startWithIdentity(Identity identity) {
    state = state.copyWith(error: null, identity: identity);
    _connect(identity);
  }

  void joinQueue() {
    state = state.copyWith(stage: Stage.queue, error: null);
    _socket?.publish('/app/queue.join', {});
  }

  void leaveQueue() {
    _socket?.publish('/app/queue.leave', {});
    state = state.copyWith(stage: Stage.lobby);
  }

  /// Offline single-player vs 3 server-side bots. The server forms the
  /// 4-seat match instantly and replies with the same MATCH_FOUND private
  /// message as a real queue match.
  void playOffline() {
    state = state.copyWith(error: null);
    _socket?.publish('/app/queue.joinOffline', {});
  }

  void pick(Slot slot) {
    final s = state;
    if (s.stage != Stage.match || s.phase != Phase.turn) return;
    if (s.currentSeat != s.yourSeat || s.heldBy != null || s.busy) return;
    state = s.copyWith(busy: true);
    _socket?.publish('/app/match.${s.matchId}.pick', {'slot': slot.wireName});
    _armBusyFailsafe();
  }

  void rotate() {
    final s = state;
    if (s.heldBy != s.identity?.playerId) return;
    _socket?.publish('/app/match.${s.matchId}.rotate', {});
  }

  void place(CornerName corner, int x, int y) {
    final s = state;
    if (s.heldBy != s.identity?.playerId || s.busy) return;
    state = s.copyWith(busy: true);
    _socket?.publish('/app/match.${s.matchId}.place', {
      'corner': corner.wireName,
      'x': x,
      'y': y,
    });
    _armBusyFailsafe();
  }

  void dismissError() => state = state.copyWith(error: null);

  void leave() {
    final s = state;
    // Tell the server we're forfeiting so it frees us up to queue again;
    // harmless no-op if the match already finished or there wasn't one.
    if (s.matchId != null) {
      _socket?.publish('/app/match.${s.matchId}.leave', {});
    }
    _socket?.deactivate();
    _socket = null;
    state = const GameState(conn: ConnStatus.idle, stage: Stage.name);
  }

  void _armBusyFailsafe() {
    _busyFailsafeTimer?.cancel();
    _busyFailsafeTimer = Timer(_busyFailsafe, () {
      if (state.busy) state = state.copyWith(busy: false);
    });
  }

  void _connect(Identity identity) {
    final socket = _socketFactory();
    _socket = socket;
    state = state.copyWith(conn: ConnStatus.connecting);
    socket.activate(
      identity.token,
      GameSocketHandlers(
        onConnect: () {
          final s = state;
          final wasNameStage = s.stage == Stage.name;
          state = s.copyWith(
            conn: ConnStatus.connected,
            stage: wasNameStage ? Stage.lobby : s.stage,
          );
          if (s.matchId != null) {
            _socket?.publish('/app/match.${s.matchId}.resume', {});
          } else if (s.stage == Stage.queue) {
            _socket?.publish('/app/queue.join', {});
          }
        },
        onDisconnect: () {
          if (state.conn == ConnStatus.connected) {
            state = state.copyWith(conn: ConnStatus.reconnecting);
          }
        },
        // The socket has already stopped retrying by the time this fires.
        // Most likely cause is a token from a previous server run (e.g. the
        // backend restarted) — drop it so the next attempt registers fresh
        // instead of replaying the same dead token forever.
        onFatalError: (message) async {
          await api.clearIdentity();
          _socket = null;
          state = state.copyWith(
            conn: ConnStatus.failed,
            stage: Stage.name,
            identity: null,
            error: const GameError(
              code: 'CONNECT_FAILED',
              message: 'Your session expired — please sign in again.',
            ),
          );
        },
        onPrivateMessage: _handlePrivate,
        onMatchMessage: _handleTopic,
      ),
    );
  }

  void _handlePrivate(Object? raw) {
    final msg = PrivateMessage.tryParse(raw);
    if (msg == null) return;
    switch (msg) {
      case MatchFoundMessage():
        _socket?.subscribeMatch(msg.matchId);
        state = state.resetMatch().copyWith(
          stage: Stage.match,
          matchId: msg.matchId,
          yourSeat: msg.yourSeat,
          players: msg.players.map(PlayerState.fromRef).toList(),
          connected: {for (final p in msg.players) p.playerId: true},
        );
        // MATCH_FOUND carries no market/board; pull the initial snapshot.
        _socket?.publish('/app/match.${msg.matchId}.resume', {});
      case ResumeStateMessage():
        _socket?.subscribeMatch(msg.matchId);
        final prev = state;
        final isSelfTurn = msg.currentSeat == prev.yourSeat;
        state = prev.copyWith(
          stage: Stage.match,
          matchId: msg.matchId,
          phase: msg.phase,
          round: msg.round,
          currentSeat: msg.currentSeat,
          // Matches MatchEngine's fixed 4-seat rotation.
          startingSeat: (msg.round - 1) % 4,
          finalRound: msg.finalRound,
          players: msg.players,
          connected: {for (final p in msg.players) p.playerId: true},
          boards: msg.boards,
          market: msg.market,
          deckRemaining: msg.deckRemaining,
          // RESUME_STATE only carries OUR held card. If someone else is
          // acting, keep whatever we learned from their CARD_PICKED broadcast.
          heldCard: isSelfTurn ? msg.heldCard : prev.heldCard,
          heldBy: isSelfTurn
              ? (msg.heldCard != null ? prev.identity?.playerId : null)
              : prev.heldBy,
          busy: false,
        );
      case ErrorMessage():
        final s = state;
        if (msg.code == 'NOT_IN_MATCH' && s.stage == Stage.match) {
          state = s.resetMatch().copyWith(
            stage: Stage.lobby,
            error: GameError(code: msg.code, message: msg.message),
          );
        } else {
          // Any rejected action unlocks the UI so the player can retry.
          state = s.copyWith(
            busy: false,
            error: GameError(code: msg.code, message: msg.message),
          );
        }
    }
  }

  void _handleTopic(Object? raw) {
    final msg = TopicMessage.tryParse(raw);
    if (msg == null) return;
    switch (msg) {
      case RoundStartMessage():
        state = state.copyWith(
          round: msg.round,
          phase: Phase.turn,
          currentSeat: msg.startingSeat,
          startingSeat: msg.startingSeat,
          finalRound: msg.finalRound,
          heldCard: null,
          heldBy: null,
          busy: false,
          lastBattle: null,
        );
      case TurnStartMessage():
        state = state.copyWith(
          currentSeat: msg.seat,
          heldCard: null,
          heldBy: null,
          busy: false,
        );
      case CardPickedMessage():
        state = state.copyWith(
          heldCard: msg.card,
          heldBy: msg.playerId,
          market: msg.market,
          deckRemaining: msg.deckRemaining,
          busy: false,
        );
      case CardRotatedMessage():
        final s = state;
        if (s.heldCard != null) {
          state = s.copyWith(heldCard: s.heldCard!.rotateOnce(msg.rotation));
        }
      case CardPlacedMessage():
        final points = domain.cardToPoints(msg.card, msg.corner, msg.x, msg.y);
        state = state.copyWith(
          boards: _mergePoints(state.boards, msg.playerId, points),
          heldCard: null,
          heldBy: null,
          busy: false,
        );
      case StatsUpdatedMessage():
        state = state.copyWith(
          players: [
            for (final p in state.players)
              p.playerId == msg.playerId ? p.copyWith(stats: msg.stats) : p,
          ],
        );
      case BattleResultMessage():
        final byPlayer = {for (final o in msg.outcomes) o.playerId: o};
        state = state.copyWith(
          phase: Phase.battle,
          lastBattle: BattleVm(
            round: msg.round,
            attacks: msg.attacks,
            outcomes: msg.outcomes,
          ),
          // outcomes[].hpAfter is the authoritative post-battle hp for every
          // player who was alive at battle start — apply it directly.
          players: [
            for (final p in state.players)
              if (byPlayer[p.playerId] case final o?)
                p.copyWith(
                  alive: !o.eliminated,
                  stats: p.stats.copyWith(hp: o.hpAfter),
                )
              else
                p,
          ],
        );
      case PlayerEliminatedMessage():
        state = state.copyWith(
          players: [
            for (final p in state.players)
              p.playerId == msg.playerId
                  ? p.copyWith(
                      alive: false,
                      stats: p.stats.copyWith(hp: msg.finalHp),
                    )
                  : p,
          ],
        );
      case MatchResultMessage():
        state = state.copyWith(
          phase: Phase.matchOver,
          winners: msg.winners,
          reason: msg.reason,
        );
      case PlayerDisconnectedMessage():
        state = state.copyWith(
          connected: {...state.connected, msg.playerId: false},
        );
      case PlayerReconnectedMessage():
        state = state.copyWith(
          connected: {...state.connected, msg.playerId: true},
        );
    }
  }
}

final gameNotifierProvider = StateNotifierProvider<GameNotifier, GameState>((
  ref,
) {
  final notifier = GameNotifier();
  ref.onDispose(notifier.dispose);
  return notifier;
});
