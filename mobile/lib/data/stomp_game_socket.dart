import 'dart:async';
import 'dart:convert';

import 'package:stomp_dart_client/stomp_dart_client.dart';

import 'api_client.dart';

/// Fired on every successful (re)connect.
typedef OnConnect = void Function();

/// Fired when the underlying socket drops; the client keeps retrying.
typedef OnDisconnect = void Function();

/// Fired when the connection cannot succeed on its own: the broker rejected
/// CONNECT (e.g. a stale token from a previous server run) or nothing
/// answered within the connect timeout. Retrying is stopped before this
/// fires, since replaying the same bad token forever would just hang.
typedef OnFatalError = void Function(String message);

typedef OnPrivateMessage = void Function(Object? raw);
typedef OnMatchMessage = void Function(Object? raw);

class GameSocketHandlers {
  final OnConnect onConnect;
  final OnDisconnect onDisconnect;
  final OnFatalError onFatalError;
  final OnPrivateMessage onPrivateMessage;
  final OnMatchMessage onMatchMessage;

  const GameSocketHandlers({
    required this.onConnect,
    required this.onDisconnect,
    required this.onFatalError,
    required this.onPrivateMessage,
    required this.onMatchMessage,
  });
}

/// Thin abstraction over the STOMP client so [GameNotifier] can be driven by
/// a fake socket in tests (no live backend needed to verify the contract)
/// and so the transport can be swapped later. Mirrors the web client's
/// socket.ts (`GameSocket` interface).
abstract class GameSocket {
  void activate(String token, GameSocketHandlers handlers);

  /// Subscribe `/topic/match.{matchId}`; re-subscribed automatically after reconnect.
  void subscribeMatch(String matchId);
  void unsubscribeMatch();
  void publish(String destination, Object? body);
  void deactivate();
}

/// If CONNECT hasn't succeeded by the time this fires, something is wrong
/// that a STOMP ERROR frame won't necessarily tell us about (e.g. the server
/// is simply unreachable) — treat it the same as an explicit rejection
/// rather than let the UI wait on "Connecting…" forever.
const Duration _connectTimeout = Duration(seconds: 8);
const String _privateQueue = '/user/queue/game';

class StompGameSocket implements GameSocket {
  StompClient? _client;
  GameSocketHandlers? _handlers;
  String? _matchId;
  Timer? _connectTimer;

  @override
  void activate(String token, GameSocketHandlers handlers) {
    _handlers = handlers;
    final client = StompClient(
      config: StompConfig(
        url: backendWsUrl(),
        stompConnectHeaders: {'token': token},
        reconnectDelay: const Duration(seconds: 2),
        onConnect: (frame) {
          _clearConnectTimer();
          _subscribePrivate();
          final matchId = _matchId;
          if (matchId != null) _doSubscribeMatch(matchId);
          handlers.onConnect();
        },
        onWebSocketDone: () => handlers.onDisconnect(),
        onStompError: (frame) {
          _clearConnectTimer();
          _client?.deactivate();
          handlers.onFatalError(
            frame.headers['message'] ?? 'Connection rejected',
          );
        },
        onWebSocketError: (error) {
          _clearConnectTimer();
          handlers.onDisconnect();
        },
      ),
    );
    _client = client;
    client.activate();
    _connectTimer = Timer(_connectTimeout, () {
      _connectTimer = null;
      if (_client?.connected != true) {
        _client?.deactivate();
        handlers.onFatalError('Could not reach the server');
      }
    });
  }

  void _clearConnectTimer() {
    _connectTimer?.cancel();
    _connectTimer = null;
  }

  void _subscribePrivate() {
    _client?.subscribe(
      destination: _privateQueue,
      callback: (frame) => _handlers?.onPrivateMessage(_safeJson(frame.body)),
    );
  }

  void _doSubscribeMatch(String matchId) {
    _client?.subscribe(
      destination: '/topic/match.$matchId',
      callback: (frame) => _handlers?.onMatchMessage(_safeJson(frame.body)),
    );
  }

  @override
  void subscribeMatch(String matchId) {
    if (_matchId == matchId) return;
    _matchId = matchId;
    if (_client?.connected == true) _doSubscribeMatch(matchId);
  }

  @override
  void unsubscribeMatch() {
    _matchId = null;
  }

  @override
  void publish(String destination, Object? body) {
    _client?.send(destination: destination, body: jsonEncode(body));
  }

  @override
  void deactivate() {
    _clearConnectTimer();
    _matchId = null;
    _client?.deactivate();
    _client = null;
  }
}

Object? _safeJson(String? body) {
  if (body == null) return null;
  try {
    return jsonDecode(body);
  } catch (_) {
    return null;
  }
}
