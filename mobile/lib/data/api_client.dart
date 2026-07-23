import 'dart:convert';
import 'dart:io' show Platform;

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/identity.dart';

const String _storageKey = 'regroup.identity';
const String _backendUrlKey = 'regroup.backendUrl';

/// Compile-time override: `--dart-define=BACKEND_URL=http://host:port`.
const String _backendUrlBuildOverride = String.fromEnvironment('BACKEND_URL');

/// Runtime override, set in-app (Server address field on the name screen) and
/// persisted. Cached synchronously so the sync [backendHttpUrl] can use it;
/// [loadBackendOverride] must run once at startup to populate it.
String? _runtimeOverride;

/// Loads the persisted in-app backend URL. Call once in main() before connecting.
Future<void> loadBackendOverride() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_backendUrlKey);
    _runtimeOverride = (v != null && v.trim().isNotEmpty) ? v.trim() : null;
  } catch (_) {
    _runtimeOverride = null;
  }
}

/// The current in-app override, or null if none (then the default is used).
String? backendOverride() => _runtimeOverride;

/// Persists (or clears, if null/empty) the in-app backend URL. Takes effect on
/// the next connection.
Future<void> setBackendOverride(String? url) async {
  final trimmed = url?.trim();
  _runtimeOverride = (trimmed != null && trimmed.isNotEmpty) ? trimmed : null;
  try {
    final prefs = await SharedPreferences.getInstance();
    if (_runtimeOverride == null) {
      await prefs.remove(_backendUrlKey);
    } else {
      await prefs.setString(_backendUrlKey, _runtimeOverride!);
    }
  } catch (_) {}
}

/// Base HTTP URL of the backend. Precedence: in-app runtime override →
/// build-time dart-define → platform default. On Android the default is
/// 10.0.2.2 (the emulator's alias for the host's localhost); real devices
/// need the in-app override pointed at the backend's reachable address.
String backendHttpUrl() {
  if (_runtimeOverride != null) return _normalize(_runtimeOverride!);
  if (_backendUrlBuildOverride.isNotEmpty) {
    return _normalize(_backendUrlBuildOverride);
  }
  if (!Platform.isAndroid) return 'http://localhost:8080';
  return 'http://10.0.2.2:8080';
}

/// Tolerates a bare `host:port` (adds http://) and strips a trailing slash, so
/// the in-app field is forgiving about exact formatting.
String _normalize(String url) {
  var u = url.trim();
  if (!u.startsWith('http://') && !u.startsWith('https://')) u = 'http://$u';
  if (u.endsWith('/')) u = u.substring(0, u.length - 1);
  return u;
}

String backendWsUrl() =>
    '${backendHttpUrl().replaceFirst(RegExp('^http'), 'ws')}/ws';

/// `POST /api/players {name}` -> `{playerId, token, name}` (WS_CONTRACT.md).
Future<Identity> registerPlayer(String name) async {
  final res = await http.post(
    Uri.parse('${backendHttpUrl()}/api/players'),
    headers: const {'Content-Type': 'application/json'},
    body: jsonEncode({'name': name}),
  );
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw Exception('Registration failed (${res.statusCode})');
  }
  final decoded = jsonDecode(res.body);
  if (decoded is! Map<String, dynamic>) {
    throw Exception('Registration returned an unexpected payload');
  }
  final identity = Identity.tryFromJson(decoded);
  if (identity == null) {
    throw Exception('Registration returned an unexpected payload');
  }
  // The server doesn't necessarily echo the exact name back verbatim in every
  // case; keep what we asked for, same as the web client's api.ts does.
  return Identity(
    playerId: identity.playerId,
    token: identity.token,
    name: name,
  );
}

Future<Identity?> loadIdentity() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_storageKey);
  if (raw == null) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    return Identity.tryFromJson(decoded);
  } catch (_) {
    return null;
  }
}

Future<void> saveIdentity(Identity identity) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_storageKey, jsonEncode(identity.toJson()));
}

Future<void> clearIdentity() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_storageKey);
}
