import 'package:flutter/material.dart';

import '../../domain/models/card.dart' as domain;
import '../../sfx/sfx.dart';
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
        // Feedback centered on the finger. CRITICAL: feedbackOffset stays zero
        // so the DragTarget hit-test point is exactly the finger — the same
        // point BoardDropTarget converts into a board position. A non-zero
        // feedbackOffset shifts the hit-test away from where the placement is
        // computed, which made drops land off the (small) board and register
        // as "can't place any card". The card is lifted purely visually with
        // a Transform below (drawing only, no effect on hit-testing) so the
        // finger doesn't hide it.
        dragAnchorStrategy: pointerDragAnchorStrategy,
        onDragStarted: () => playSfx(SfxName.cardDragStart),
        feedback: Material(
          color: Colors.transparent,
          child: Transform.translate(
            offset: Offset(0, -size * 0.85),
            child: Opacity(
              opacity: 0.9,
              child: CardView(card: card, size: size),
            ),
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
