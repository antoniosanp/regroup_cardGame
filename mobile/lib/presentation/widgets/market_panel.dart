import 'package:flutter/material.dart';

import '../../domain/models/card.dart' as domain;
import '../../domain/models/market.dart';
import '../../domain/models/phase.dart';
import '../assets/board_art.dart';
import '../theme/app_colors.dart';
import 'card_detail.dart';
import 'card_view.dart';

const Map<Slot, int> _slotPrice = {Slot.a: 0, Slot.b: 1, Slot.c: 2};

/// Left-side panel: while no card is held, a 2-column grid of the three
/// market slots (A/B/C) plus the free face-down deck draw; once a card is
/// picked, the same space switches to [CardDetail] (mirrors the web
/// client's Market.tsx + the "held card" display it used to render
/// elsewhere — moving it into this panel's space is the actual UX
/// improvement this HU makes for the landscape mobile layout). Once the
/// card has been dropped on the board and is awaiting Confirm/Cancel
/// (FE-07), this panel shows neither — the card visually "moved" to the
/// board's pending preview, so dragging it again from here would be
/// confusing.
class MarketPanel extends StatelessWidget {
  final Market market;
  final int deckRemaining;
  final bool canPick;
  final int yourCoins;
  final bool finalRound;
  final domain.Card? heldCard;
  final bool placementPending;
  final ValueChanged<Slot> onPick;
  final VoidCallback onRotate;

  const MarketPanel({
    super.key,
    this.market = Market.empty,
    this.deckRemaining = 0,
    this.canPick = false,
    this.yourCoins = 0,
    this.finalRound = false,
    this.heldCard,
    this.placementPending = false,
    this.onPick = _noOpPick,
    this.onRotate = _noOp,
  });

  static void _noOpPick(Slot slot) {}
  static void _noOp() {}

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.parchmentDark,
        border: Border(right: BorderSide(color: AppColors.woodDark, width: 2)),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        // While a placement is pending, the card is shown on the board as a
        // preview and the Confirm/Cancel buttons sit in the bottom bar — so
        // this panel just stays empty (no big redundant "card placed" notice).
        child: placementPending
            ? const SizedBox.expand(key: ValueKey('pending'))
            : heldCard != null
            ? CardDetail(
                key: const ValueKey('detail'),
                card: heldCard!,
                onRotate: onRotate,
              )
            : _MarketGrid(
                key: const ValueKey('grid'),
                market: market,
                deckRemaining: deckRemaining,
                canPick: canPick,
                yourCoins: yourCoins,
                finalRound: finalRound,
                onPick: onPick,
              ),
      ),
    );
  }
}

class _MarketGrid extends StatelessWidget {
  final Market market;
  final int deckRemaining;
  final bool canPick;
  final int yourCoins;
  final bool finalRound;
  final ValueChanged<Slot> onPick;

  const _MarketGrid({
    super.key,
    required this.market,
    required this.deckRemaining,
    required this.canPick,
    required this.yourCoins,
    required this.finalRound,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    // Single column of 4 compact rows (A/B/C + deck) instead of a 2x2 grid —
    // the 2x2 wasted space in this narrow vertical panel. Each row splits
    // its 1/4 of the panel height between a card thumbnail and its pick
    // button, so it always fits without overflow no matter how tall the
    // panel is (Expanded rows).
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Column(
        children: [
          Expanded(
            child: _MarketSlot(
              card: market.a,
              price: finalRound ? 0 : _slotPrice[Slot.a]!,
              canPick: canPick,
              yourCoins: yourCoins,
              onPick: () => onPick(Slot.a),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: _MarketSlot(
              card: market.b,
              price: finalRound ? 0 : _slotPrice[Slot.b]!,
              canPick: canPick,
              yourCoins: yourCoins,
              onPick: () => onPick(Slot.b),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: _MarketSlot(
              card: market.c,
              price: finalRound ? 0 : _slotPrice[Slot.c]!,
              canPick: canPick,
              yourCoins: yourCoins,
              onPick: () => onPick(Slot.c),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: _DeckSlot(
              deckRemaining: deckRemaining,
              canPick: canPick,
              onPick: () => onPick(Slot.deck),
            ),
          ),
        ],
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
    final blockedByCoins = canPick && card != null && !affordable;
    final priceText = price == 0
        ? 'Free'
        : '$price coin${price > 1 ? 's' : ''}';
    final label = !affordable && card != null
        ? 'Not enough coins'
        : 'Pick · $priceText';

    // Horizontal: card thumbnail on the left, pick button filling the rest.
    return Row(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: card != null
              ? CardView(card: card!, size: double.infinity)
              : const EmptyCard(label: 'empty', size: double.infinity),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: FilledButton(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              backgroundColor: blockedByCoins ? Colors.red.shade900 : null,
            ),
            onPressed: enabled ? onPick : null,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
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
    return Row(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(BoardArt.cardBack, fit: BoxFit.contain),
              Text(
                '$deckRemaining',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: FilledButton(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            onPressed: enabled ? onPick : null,
            child: const Text('Draw · Free', style: TextStyle(fontSize: 11)),
          ),
        ),
      ],
    );
  }
}
