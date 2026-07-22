import 'package:flutter/material.dart';

import '../../domain/models/card.dart' as domain;
import 'card_view.dart';

/// The held card, made draggable from anywhere on its surface — no need to
/// grab a specific corner (see FE-03's [BoardDropTarget] for how the actual
/// placement corner gets chosen automatically once dropped). Ghost lifts
/// above the finger so the card being placed isn't hidden by the hand
/// doing the dragging (see mobile_patterns.md, agent memory).
class DraggableHeldCard extends StatelessWidget {
  final domain.Card card;
  final double size;

  const DraggableHeldCard({super.key, required this.card, this.size = 128});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Held card: ${card.topLeft.label}, ${card.topRight.label}, ${card.bottomLeft.label}, ${card.bottomRight.label}. Drag onto the board to place it.',
      child: Draggable<domain.Card>(
        data: card,
        // Anchors the feedback at the pointer itself (centered under the
        // finger, then lifted by feedbackOffset) rather than at wherever on
        // the card you happened to grab it (the default). This matters
        // beyond looks: BoardDropTarget's hit-testing (FE-03) always uses
        // the raw pointer position, not the feedback widget's position — with
        // the default anchor strategy, grabbing the card off-center made the
        // ghost visually drift away from the point that actually counts for
        // placement, which is exactly the "doesn't feel natural" complaint.
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedbackOffset: const Offset(0, -80),
        feedback: Material(
          color: Colors.transparent,
          child: Opacity(
            opacity: 0.9,
            child: CardView(card: card, size: size),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.3,
          child: CardView(card: card, size: size),
        ),
        child: CardView(card: card, size: size),
      ),
    );
  }
}
