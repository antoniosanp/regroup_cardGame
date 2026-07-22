import 'dart:convert';
import 'dart:io' show Platform;

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/identity.dart';

const String _storageKey = 'regroup.identity';

/// Override at build time with `--dart-define=BACKEND_URL=http://host:port`.
/// Without an override: 10.0.2.2 is the Android emulator's alias for the
/// host machine's localhost (plain "localhost" from inside the emulator
/// resolves to the emulator itself, not the host running the backend) —
/// iOS simulators and physical devices on the same network need their own
/// override, since neither of those aliases apply to them.
const String _backendUrlOverride = String.fromEnvironment('BACKEND_URL');

String backendHttpUrl() {
  if (_backendUrlOverride.isNotEmpty) return _backendUrlOverride;
  if (!Platform.isAndroid) return 'http://localhost:8080';
  return 'http://10.0.2.2:8080';
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
