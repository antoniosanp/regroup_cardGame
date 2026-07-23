import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A scrollable rules summary. Content is taken from backend/gameRules.md
/// (the digital game's source of truth) — the same source the web client's
/// RulesPage uses. Condensed to the essentials for a mobile dialog; the web's
/// full illustrated rulebook + interactive tutorial aren't ported here.
Future<void> showRulesDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: AppColors.parchment,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: AppColors.wood,
              child: const Text(
                'Regroup — Rules of play',
                style: TextStyle(
                  color: AppColors.textLight,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: DefaultTextStyle(
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                    height: 1.4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Heading('Goal'),
                      Text(
                        'Four players. Each starts with 30 HP. Build your board of cards to '
                        'raise your attack/defense, then survive the battle each round. Last '
                        'player standing (or highest HP when the deck runs out) wins.',
                      ),
                      _Heading('Cards'),
                      Text(
                        'Every card is a square with four corners. A corner can be empty, coins, '
                        'a potion+coin, or one/two points of a stat: PA (physical attack), PD '
                        '(physical defense), MA (magic attack), MD (magic defense).',
                      ),
                      _Heading('Your turn'),
                      Text(
                        'Pick one of the three face-up market cards — A is free, B costs 1 coin, '
                        'C costs 2 coins — or draw the top deck card for free. You may rotate the '
                        'held card as many times as you like, then place it on your board. Your '
                        'first card can go anywhere; every card after that must share at least one '
                        'corner with a card already on your board.',
                      ),
                      _Heading('Stats'),
                      Text(
                        'Coins and potions count every matching symbol on your board. For '
                        'PA/PD/MA/MD, matching symbols only count when they sit next to each other '
                        '— e.g. a 1-PA corner adjacent to a 2-PA corner gives you 3 PA. Isolated '
                        'stat corners score nothing.',
                      ),
                      _Heading('Battle'),
                      Text(
                        'After everyone has placed a card, the round\'s first player attacks all '
                        'others. Physical damage = attacker PA − defender PD; magic damage = '
                        'attacker MA − defender MD (never below 0). Survivors then heal by their '
                        'potion count. Drop below 1 HP and you\'re out.',
                      ),
                      _Heading('End of game'),
                      Text(
                        'The match ends when one player remains, or the deck/market runs low '
                        '(the "final round", where every market card is free). Highest HP wins; '
                        'ties share the win.',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Heading extends StatelessWidget {
  final String text;

  const _Heading(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
