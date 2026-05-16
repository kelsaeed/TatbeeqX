import 'package:flutter/material.dart';

/// One entry in a row's action menu.
class RowAction {
  const RowAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  // Renders the entry in the error colour (delete, reset, etc.).
  final bool destructive;
}

/// Replaces the row of 3-4 unlabeled icon buttons that every list page
/// used to render in its trailing column. One always-the-same `⋮`
/// affordance, labeled actions, destructive ones colour-coded — far
/// less visual noise per row and no guessing what each glyph does.
///
/// Pass `null` actions (e.g. permission-gated ones) and they're simply
/// skipped, so call sites can keep their `if (canEdit) ...` shape.
class RowActionsMenu extends StatelessWidget {
  const RowActionsMenu({super.key, required this.actions});

  final List<RowAction?> actions;

  @override
  Widget build(BuildContext context) {
    final items = actions.whereType<RowAction>().toList();
    if (items.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerRight,
      child: PopupMenuButton<int>(
        tooltip: MaterialLocalizations.of(context).showMenuTooltip,
        icon: const Icon(Icons.more_vert, size: 18),
        position: PopupMenuPosition.under,
        onSelected: (i) => items[i].onTap(),
        itemBuilder: (_) => [
          for (var i = 0; i < items.length; i++)
            PopupMenuItem<int>(
              value: i,
              child: Row(
                children: [
                  Icon(
                    items[i].icon,
                    size: 18,
                    color: items[i].destructive ? cs.error : cs.onSurface,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    items[i].label,
                    style: items[i].destructive
                        ? TextStyle(color: cs.error)
                        : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
