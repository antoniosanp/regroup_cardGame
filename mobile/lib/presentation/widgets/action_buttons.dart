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

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: confirming ? null : onCancel,
          icon: const Icon(Icons.close),
          label: const Text('Cancel'),
        ),
        const SizedBox(width: 16),
        FilledButton.icon(
          onPressed: confirming ? null : onConfirm,
          icon: confirming
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check),
          label: Text(confirming ? 'Confirming…' : 'Confirm'),
        ),
      ],
    );
  }
}
