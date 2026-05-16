import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One jump target in the command palette.
class CommandItem {
  const CommandItem({
    required this.label,
    required this.icon,
    required this.onSelect,
    this.group,
  });

  final String label;
  // Optional section the entry belongs to (e.g. its sidebar group),
  // shown dimmed so duplicate-looking labels are disambiguated.
  final String? group;
  final IconData icon;
  final VoidCallback onSelect;
}

/// Spotlight-style quick switcher. With 25+ pages, hunting the sidebar
/// is the slowest part of getting anywhere; this makes every page one
/// shortcut + a few keystrokes away. Opened via Ctrl/Cmd-K from the
/// shell. Pure navigation — it never mutates anything.
Future<void> showCommandPalette(
  BuildContext context,
  List<CommandItem> items, {
  String hint = 'Jump to…',
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => _CommandPaletteDialog(items: items, hint: hint),
  );
}

class _CommandPaletteDialog extends StatefulWidget {
  const _CommandPaletteDialog({required this.items, required this.hint});
  final List<CommandItem> items;
  final String hint;

  @override
  State<_CommandPaletteDialog> createState() => _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends State<_CommandPaletteDialog> {
  final _scroll = ScrollController();
  String _query = '';
  int _selected = 0;

  List<CommandItem> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.items;
    // Subsequence ("fzf-style") match: typing "uscr" finds "Users
    // screen". Falls back to plain contains, which the subsequence
    // test already subsumes, so one pass is enough.
    bool matches(String text) {
      final s = text.toLowerCase();
      var i = 0;
      for (var c = 0; c < s.length && i < q.length; c++) {
        if (s[c] == q[i]) i++;
      }
      return i == q.length;
    }

    return widget.items
        .where((it) => matches('${it.label} ${it.group ?? ''}'))
        .toList();
  }

  void _move(int delta) {
    final n = _filtered.length;
    if (n == 0) return;
    setState(() => _selected = (_selected + delta) % n);
    if (_selected < 0) _selected += n;
    // Keep the highlighted row in view.
    _scroll.animateTo(
      (_selected * 48.0).clamp(0.0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
    );
  }

  void _accept() {
    final list = _filtered;
    if (list.isEmpty) return;
    final item = list[_selected.clamp(0, list.length - 1)];
    Navigator.of(context).pop();
    item.onSelect();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final list = _filtered;
    if (_selected >= list.length) _selected = list.isEmpty ? 0 : list.length - 1;

    return Align(
      alignment: const Alignment(0, -0.55),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(1),
          const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(-1),
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.of(context).maybePop(),
        },
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 460),
            child: Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outline),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                    child: TextField(
                      autofocus: true,
                      onChanged: (v) => setState(() {
                        _query = v;
                        _selected = 0;
                      }),
                      onSubmitted: (_) => _accept(),
                      decoration: InputDecoration(
                        hintText: widget.hint,
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: list.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(28),
                            child: Text(
                              'No matches',
                              style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            itemCount: list.length,
                            itemBuilder: (_, i) {
                              final it = list[i];
                              final sel = i == _selected;
                              return InkWell(
                                onTap: () {
                                  Navigator.of(context).pop();
                                  it.onSelect();
                                },
                                onHover: (h) {
                                  if (h) setState(() => _selected = i);
                                },
                                child: Container(
                                  height: 48,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  color: sel
                                      ? cs.primary.withValues(alpha: 0.10)
                                      : Colors.transparent,
                                  child: Row(
                                    children: [
                                      Icon(it.icon,
                                          size: 18,
                                          color: sel
                                              ? cs.primary
                                              : cs.onSurface
                                                  .withValues(alpha: 0.7)),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          it.label,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: sel
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      if (it.group != null) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          it.group!,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: cs.onSurface
                                                .withValues(alpha: 0.45),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    child: Row(
                      children: [
                        _Hint(text: '↑↓ navigate'),
                        const SizedBox(width: 14),
                        _Hint(text: '⏎ open'),
                        const SizedBox(width: 14),
                        _Hint(text: 'esc close'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
      ),
    );
  }
}
