import 'package:flutter/material.dart';

/// Confirm/Cancel bar shown once a placement is pending (dropped on the
/// board but not yet sent to the server). "Confirm" commits it — the only
/// point at which anything actually reaches the server; "Cancel" just clears
/// local state and the card visually returns to the hand. Nothing about the
/// market or the held card itself is touched by Cancel — it only undoes the
/// *position* on the board, never the pick (see WS_CONTRACT.md: there is no
/// unpick action, and there doesn't need to be one for this to work, since
/// the pick was already committed before the drag ever started).
class ActionButtons extends StatelessWidget {
  final bool hasPendingPlacement;
  final bool confirming;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const ActionButtons({
    super.key,
    required this.hasPendingPlacement,
    required this.onConfirm,
    required this.onCancel,
    this.confirming = false,
  });

  @override
  Widget build(BuildContext context) {
    // Nothing to show until a card has been dropped on the board (the earlier
    // "Drag your card onto the board" hint was unnecessary clutter).
    if (!hasPendingPlacement) {
      return const SizedBox.shrink();
    }

    // Stacked, not side-by-side — this only renders inside the narrow hand
    // panel beside the board now, where a Row of two icon+label buttons
    // wouldn't fit. No icons either, and an explicit compact style: the
    // default FilledButton.icon/OutlinedButton.icon sizing (icon + label +
    // Material's default padding/min-tap-target) was wider than the ~116px
    // this panel actually has, so "Confirm" was wrapping onto a second line
    // and the button was spilling past the panel's edge.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: confirming ? null : onConfirm,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(fontSize: 13),
              ),
              child: confirming
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Confirm'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: confirming ? null : onCancel,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(fontSize: 13),
              ),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }
}
