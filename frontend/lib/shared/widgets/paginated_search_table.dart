import 'dart:async';
import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';

class TableColumn<T> {
  TableColumn({required this.label, required this.cell, this.flex = 1, this.numeric = false});
  final String label;
  final Widget Function(T row) cell;
  final int flex;
  final bool numeric;
}

class PaginatedSearchTable<T> extends StatefulWidget {
  const PaginatedSearchTable({
    super.key,
    required this.columns,
    required this.fetch,
    this.searchHint,
    this.actions,
    this.onRowTap,
    this.searchable = true,
    this.pageSize = 25,
    this.emptyAction,
  });

  final List<TableColumn<T>> columns;
  final Future<({List<T> items, int total})> Function({required int page, required int pageSize, required String search}) fetch;
  // Optional override; falls back to the localized "Search…" hint when null.
  final String? searchHint;
  final List<Widget>? actions;
  final void Function(T row)? onRowTap;
  final bool searchable;
  final int pageSize;
  // Optional call-to-action shown in the empty state when there's no
  // active search (e.g. the page's "New X" button), so a fresh/empty
  // list points the user at the next step instead of a dead end.
  final Widget? emptyAction;

  @override
  State<PaginatedSearchTable<T>> createState() => PaginatedSearchTableState<T>();
}

class PaginatedSearchTableState<T> extends State<PaginatedSearchTable<T>> {
  int _page = 1;
  int _total = 0;
  bool _loading = false;
  String _search = '';
  List<T> _items = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> reload() => _load();

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await widget.fetch(page: _page, pageSize: widget.pageSize, search: _search);
      if (!mounted) return;
      setState(() {
        _items = r.items;
        _total = r.total;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).loadFailed(e.toString()))));
    }
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _search = v;
        _page = 1;
      });
      _load();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);
    final pages = (_total / widget.pageSize).ceil().clamp(1, 9999);

    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                if (widget.searchable)
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: widget.searchHint ?? t.searchHint,
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                if (widget.searchable && widget.actions != null) const SizedBox(width: 12),
                if (widget.actions != null) ...widget.actions!,
              ],
            ),
          ),
          Divider(height: 1, color: cs.outline),
          Container(
            color: cs.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                for (final col in widget.columns)
                  Expanded(
                    flex: col.flex,
                    child: Text(
                      col.label,
                      textAlign: col.numeric ? TextAlign.right : TextAlign.left,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: cs.outline),
          if (_loading)
            const Padding(padding: EdgeInsets.all(28), child: CircularProgressIndicator())
          else if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(48),
              child: Column(
                children: [
                  Icon(
                    _search.isEmpty ? Icons.inbox_outlined : Icons.search_off,
                    size: 44,
                    color: cs.onSurface.withValues(alpha: 0.35),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    t.noData,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                  ),
                  if (_search.isEmpty && widget.emptyAction != null) ...[
                    const SizedBox(height: 16),
                    widget.emptyAction!,
                  ],
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: cs.outline),
              itemBuilder: (_, i) {
                final row = _items[i];
                final tile = Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      for (final col in widget.columns)
                        Expanded(
                          flex: col.flex,
                          child: Align(
                            alignment: col.numeric ? Alignment.centerRight : Alignment.centerLeft,
                            child: col.cell(row),
                          ),
                        ),
                    ],
                  ),
                );
                if (widget.onRowTap == null) return tile;
                return InkWell(onTap: () => widget.onRowTap!(row), child: tile);
              },
            ),
          Divider(height: 1, color: cs.outline),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Text(t.totalLabel(_total), style: Theme.of(context).textTheme.bodySmall),
                const Spacer(),
                IconButton(
                  onPressed: _page > 1
                      ? () {
                          setState(() => _page -= 1);
                          _load();
                        }
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(t.pageOfTotal(_page, pages)),
                IconButton(
                  onPressed: _page < pages
                      ? () {
                          setState(() => _page += 1);
                          _load();
                        }
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
