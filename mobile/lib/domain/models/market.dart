import 'card.dart';

/// Mirrors WS_CONTRACT.md's market shape: three face-up slots, A/B/C.
class Market {
  final Card? a;
  final Card? b;
  final Card? c;

  const Market({this.a, this.b, this.c});

  static const empty = Market();

  factory Market.fromJson(Object? json) {
    final o = json is Map<String, dynamic> ? json : const <String, dynamic>{};
    return Market(
      a: Card.tryFromJson(o['A']),
      b: Card.tryFromJson(o['B']),
      c: Card.tryFromJson(o['C']),
    );
  }
}
