import 'package:flutter/material.dart';

import '../../domain/models/card.dart' as domain;
import '../../domain/models/market.dart';
import '../../domain/models/phase.dart';
import '../../sfx/sfx.dart';
import '../assets/board_art.dart';
import '../theme/app_colors.dart';
import 'card_view.dart';

const Map<Slot, int> _slotPrice = {Slot.a: 0, Slot.b: 1, Slot.c: 2};

/// Horizontal market frame (`marketFrame.png`, aspect 1063/288) with four
/// slots placed over the painted card windows — a faithful port of the web's
/// `.market`/`.market-slots`. The window/gap fractions come straight from the
/// web CSS grid (`210fr 30fr 213fr 36fr 216fr 33fr 207fr` inside padded
/// insets measured on the 1063×288 art). Slots are tap-to-pick with a small
/// cost badge, since stacking a Pick button under each card doesn't fit this
/// short, wide frame on a phone.
class MarketPanel extends StatelessWidget {
  final Market market;
  final int deckRemaining;
  final bool canPick;
  final int yourCoins;
  final bool finalRound;
  final ValueChanged<Slot> onPick;

  const MarketPanel({
    super.key,
    this.market = Market.empty,
    this.deckRemaining = 0,
    this.canPick = false,
    this.yourCoins = 0,
    this.finalRound = false,
    this.onPick = _noOpPick,
  });

  static void _noOpPick(Slot slot) {}

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: 1063 / 288,
        child: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage(BoardArt.marketFrame),
              fit: BoxFit.fill,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              // Outer painted border of the frame (fractions of the art).
              final padLeft = w * (63 / 1063);
              final padRight = w * (55 / 1063);
              final padTop = h * (62 / 288);
              final padBottom = h * (40 / 288);
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  padLeft,
                  padTop,
                  padRight,
                  padBottom,
                ),
                child: Row(
                  children: [
                    // Window/gap track weights, matching the web CSS grid.
                    Expanded(
                      flex: 210,
                      child: _MarketSlot(
                        card: market.a,
                        price: finalRound ? 0 : _slotPrice[Slot.a]!,
                        canPick: canPick,
                        yourCoins: yourCoins,
                        onPick: () => onPick(Slot.a),
                      ),
                    ),
                    const Spacer(flex: 30),
                    Expanded(
                      flex: 213,
                      child: _MarketSlot(
                        card: market.b,
                        price: finalRound ? 0 : _slotPrice[Slot.b]!,
                        canPick: canPick,
                        yourCoins: yourCoins,
                        onPick: () => onPick(Slot.b),
                      ),
                    ),
                    const Spacer(flex: 36),
                    Expanded(
                      flex: 216,
                      child: _MarketSlot(
                        card: market.c,
                        price: finalRound ? 0 : _slotPrice[Slot.c]!,
                        canPick: canPick,
                        yourCoins: yourCoins,
                        onPick: () => onPick(Slot.c),
                      ),
                    ),
                    const Spacer(flex: 33),
                    Expanded(
                      flex: 207,
                      child: _DeckSlot(
                        deckRemaining: deckRemaining,
                        canPick: canPick,
                        onPick: () => onPick(Slot.deck),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MarketSlot extends StatelessWidget {
  final domain.Card? card;
  final int price;
  final bool canPick;
  final int yourCoins;
  final VoidCallback onPick;

  const _MarketSlot({
    required this.card,
    required this.price,
    required this.canPick,
    required this.yourCoins,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final affordable = yourCoins >= price;
    final enabled = canPick && card != null && affordable;
    final priceText = price == 0 ? 'Free' : '$price';

    // Card on top, price floating BELOW it (feedback) so the badge never
    // covers a card corner.
    return _TapSlot(
      enabled: enabled,
      onTap: onPick,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: card != null
                ? CardView(card: card!, size: double.infinity)
                : const EmptyCard(label: '—', size: double.infinity),
          ),
          if (card != null) ...[
            const SizedBox(height: 2),
            _CostBadge(
              text: priceText,
              blocked: canPick && !affordable,
              free: price == 0,
            ),
          ],
        ],
      ),
    );
  }
}

class _DeckSlot extends StatelessWidget {
  final int deckRemaining;
  final bool canPick;
  final VoidCallback onPick;

  const _DeckSlot({
    required this.deckRemaining,
    required this.canPick,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = canPick && deckRemaining > 0;
    return _TapSlot(
      enabled: enabled,
      onTap: onPick,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.asset(BoardArt.cardBack, fit: BoxFit.contain),
                Text(
                  '$deckRemaining',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppColors.textLight,
                    shadows: [Shadow(color: Colors.black, blurRadius: 3)],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          const _CostBadge(text: 'Free', blocked: false, free: true),
        ],
      ),
    );
  }
}

/// A tappable market window: dims when not pickable, and shows an ink ripple.
class _TapSlot extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  final Widget child;

  const _TapSlot({
    required this.enabled,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.75,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          // A disabled slot still responds with the "locked drawer" denied
          // sound, mirroring the web Market's pick-denied on disabled clicks.
          onTap: enabled ? onTap : () => playSfx(SfxName.pickDenied),
          borderRadius: BorderRadius.circular(6),
          child: Padding(padding: const EdgeInsets.all(2), child: child),
        ),
      ),
    );
  }
}

class _CostBadge extends StatelessWidget {
  final String text;
  final bool blocked;
  final bool free;

  const _CostBadge({
    required this.text,
    required this.blocked,
    required this.free,
  });

  @override
  Widget build(BuildContext context) {
    final bg = blocked
        ? AppColors.bad
        : free
        ? AppColors.good
        : AppColors.wood;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.gold, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!free) ...[
            Image.asset(BoardArt.coin, width: 11, height: 11),
            const SizedBox(width: 2),
          ],
          Text(
            text,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }
}
