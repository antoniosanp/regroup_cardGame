/// Guest identity per WS_CONTRACT.md: `POST /api/players {name}` returns
/// `{playerId, token, name}`. No accounts/login/JWT — just a name. The token
/// is replayed on STOMP CONNECT for reconnection (same token reconnecting is
/// recognized as the same player).
class Identity {
  final String playerId;
  final String token;
  final String name;

  const Identity({
    required this.playerId,
    required this.token,
    required this.name,
  });

  Map<String, dynamic> toJson() => {
    'playerId': playerId,
    'token': token,
    'name': name,
  };

  static Identity? tryFromJson(Map<String, dynamic> json) {
    final playerId = json['playerId'];
    final token = json['token'];
    final name = json['name'];
    if (playerId is! String || token is! String || name is! String) return null;
    if (playerId.isEmpty || token.isEmpty) return null;
    return Identity(playerId: playerId, token: token, name: name);
  }
}
