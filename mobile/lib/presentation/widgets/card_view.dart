import 'package:flutter/material.dart';

import '../../domain/models/card.dart' as domain;
import '../../domain/models/corner_attribute.dart';
import '../../domain/models/rotation.dart';
import '../assets/corner_art.dart';
import '../theme/app_colors.dart';

/// A card rendered as four corner attribute icons in a 2x2 grid. Pure
/// display — no drag/interaction here (see FE-02/FE-03 for that). Mirrors
/// the web client's CardView.tsx `.card`/`.corner` styling (iron background,
/// wood-dark border, rounded corners).
///
/// Layout is entirely flex-based (Expanded rows/cells) so it fills whatever
/// square box it's given and can NEVER overflow — the earlier
/// LayoutBuilder-with-computed-sizes version produced sub-pixel overflow
/// stripes on every card. [size] may be `double.infinity` to fill the
/// parent's constraints (the market slots give it a square via AspectRatio).
class CardView extends StatelessWidget {
  final domain.Card card;
  final double size;

  const CardView({super.key, required this.card, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.isFinite ? size : double.infinity,
      height: size.isFinite ? size : double.infinity,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.iron,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.woodDark, width: 2),
        ),
        padding: const EdgeInsets.all(3),
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _CornerCell(
                      attribute: card.topLeft,
                      rotation: card.rotation,
                    ),
                  ),
                  Expanded(
                    child: _CornerCell(
                      attribute: card.topRight,
                      rotation: card.rotation,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _CornerCell(
                      attribute: card.bottomLeft,
                      rotation: card.rotation,
                    ),
                  ),
                  Expanded(
                    child: _CornerCell(
                      attribute: card.bottomRight,
                      rotation: card.rotation,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CornerCell extends StatelessWidget {
  final CornerAttribute attribute;
  final Rotation rotation;

  const _CornerCell({required this.attribute, required this.rotation});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Tooltip(
        message: attribute.label,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Transform.rotate(
            angle: rotation.degrees * 3.1415926535 / 180,
            child: Image.asset(
              iconFor(attribute),
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
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
      width: size.isFinite ? size : double.infinity,
      height: size.isFinite ? size : double.infinity,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.iron,
          border: Border.all(color: AppColors.woodDark, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ),
        ),
      ),
    );
  }
}
