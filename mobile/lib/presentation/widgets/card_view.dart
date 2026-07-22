import 'package:flutter/material.dart';

import '../../domain/models/card.dart' as domain;
import '../../domain/models/corner_attribute.dart';
import '../../domain/models/rotation.dart';
import '../assets/corner_art.dart';
import '../theme/app_colors.dart';

/// A card rendered as four corner attribute icons in a 2x2 grid. Pure
/// display — no drag/interaction here (see FE-02/FE-03 for that). Mirrors
/// the web client's CardView.tsx, including its `.card`/`.corner` styling
/// (iron background, wood-dark border, rounded corners).
///
/// [size] may be `double.infinity` to fill the parent's constraints (used by
/// the market slots, which give it a square via AspectRatio). Internal
/// proportions are computed from the actually-laid-out size via LayoutBuilder
/// so both a fixed size and an infinite (fill) size work.
class CardView extends StatelessWidget {
  final domain.Card card;
  final double size;

  const CardView({super.key, required this.card, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.isFinite ? size : null,
      height: size.isFinite ? size : null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = constraints.biggest.shortestSide;
          final gap = side * 0.06;
          final padding = side * 0.05;
          final cell = (side - gap - padding * 2) / 2;
          return Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: AppColors.iron,
              borderRadius: BorderRadius.circular(side * 0.08),
              border: Border.all(color: AppColors.woodDark, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CornerCell(
                      attribute: card.topLeft,
                      rotation: card.rotation,
                      size: cell,
                    ),
                    SizedBox(width: gap),
                    _CornerCell(
                      attribute: card.topRight,
                      rotation: card.rotation,
                      size: cell,
                    ),
                  ],
                ),
                SizedBox(height: gap),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CornerCell(
                      attribute: card.bottomLeft,
                      rotation: card.rotation,
                      size: cell,
                    ),
                    SizedBox(width: gap),
                    _CornerCell(
                      attribute: card.bottomRight,
                      rotation: card.rotation,
                      size: cell,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CornerCell extends StatelessWidget {
  final CornerAttribute attribute;
  final Rotation rotation;
  final double size;

  const _CornerCell({
    required this.attribute,
    required this.rotation,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: attribute.label,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.12),
        child: Transform.rotate(
          angle: rotation.degrees * 3.1415926535 / 180,
          child: Image.asset(
            iconFor(attribute),
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

/// A face-down or missing hand slot placeholder.
class EmptyCard extends StatelessWidget {
  final String label;
  final double size;

  const EmptyCard({super.key, required this.label, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.isFinite ? size : null,
      height: size.isFinite ? size : null,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.iron,
          border: Border.all(color: AppColors.woodDark, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted, fontSize: 11),
        ),
      ),
    );
  }
}
