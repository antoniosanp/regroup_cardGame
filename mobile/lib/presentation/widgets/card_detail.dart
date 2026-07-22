import 'package:flutter/material.dart';

import '../../domain/models/card.dart' as domain;
import 'draggable_card.dart';

/// Shown in the market panel's own space once a card has actually been
/// picked (i.e. the server has already committed the pick — see
/// WS_CONTRACT.md, `pick` has no corresponding "unpick"/undo message). There
/// is deliberately no "Cancel" button here: once picked, the only way this
/// state ends is placing the card (which the board's Confirm/Cancel flow in
/// FE-07 governs) or the turn/round ending. Rotating is free to repeat any
/// number of times before placing.
///
/// The card itself is draggable straight from here (FE-02) — anywhere on its
/// surface, not just a specific corner — over to the board (FE-03's
/// BoardDropTarget figures out the placement automatically). No text labels
/// under the card describing each corner's stat — the icons speak for
/// themselves, same as the web client's CardView.
class CardDetail extends StatefulWidget {
  final domain.Card card;
  final VoidCallback onRotate;

  const CardDetail({super.key, required this.card, required this.onRotate});

  @override
  State<CardDetail> createState() => _CardDetailState();
}

class _CardDetailState extends State<CardDetail> {
  // Gives an immediate visual "the tap registered" pulse on the Rotate
  // button, independent of the network round trip to the server (which is
  // what actually reshuffles the card's corners once CARD_ROTATED comes
  // back) — see the Rotate button's own doc note below for why this exists.
  int _pulse = 0;

  @override
  Widget build(BuildContext context) {
    // Size the card from the actual available space so it never overflows the
    // panel (the source of the red overflow stripes on a short/stacked
    // panel). Reserve room for the Rotate button + gaps, then take the
    // smaller of what width or height allows so the card stays square.
    return LayoutBuilder(
      builder: (context, constraints) {
        const reservedForButton = 64.0;
        const padding = 12.0;
        final availW = constraints.maxWidth - padding * 2;
        final availH = constraints.maxHeight - padding * 2 - reservedForButton;
        final cardSize = availW < availH ? availW : availH;
        final safeSize = cardSize.clamp(48.0, 160.0);

        return Padding(
          padding: const EdgeInsets.all(padding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                key: ValueKey(_pulse),
                tween: Tween(begin: 0.9, end: 1),
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: DraggableHeldCard(card: widget.card, size: safeSize),
              ),
              const SizedBox(height: 12),
              // Rotate: the actual reshuffle only happens once the server's
              // CARD_ROTATED broadcast comes back (round trip over the
              // network) — the pulse above fires immediately on tap so the
              // button never *feels* unresponsive while that's in flight.
              FilledButton.icon(
                onPressed: () {
                  setState(() => _pulse++);
                  widget.onRotate();
                },
                icon: const Icon(Icons.rotate_right),
                label: const Text('Rotate'),
              ),
            ],
          ),
        );
      },
    );
  }
}
