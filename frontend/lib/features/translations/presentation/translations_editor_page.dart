// Phase 4.11 — per-key translation editor.
//
// Replaces the JSON textarea on the listing page with a row-per-key form.
// The English ARB is the source of truth for key order and metadata; for
// non-en locales the editor shows English reference values side-by-side
// with an editable target field. Save is whole-ARB PUT, same endpoint as
// the listing's textarea editor.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../shared/widgets/page_header.dart';

class TranslationsEditorPage extends ConsumerStatefulWidget {
  const TranslationsEditorPage({super.key, required this.locale});

  final String locale;

  @override
  ConsumerState<TranslationsEditorPage> createState() => _TranslationsEditorPageState();
}

class _Row {
  _Row({
    required this.key,
    required this.enValue,
    required this.enDescription,
    required this.originalTargetValue,
    required this.controller,
    required this.isOrphan,
  });

  final String key;
  final String enValue;
  final String? enDescription;
  // The value in the target ARB before editing started. null = key not
  // present in target (translator hasn't translated it yet).
  final String? originalTargetValue;
  final TextEditingController controller;
  // True if the key exists in the target locale but NOT in en (en is the
  // template — anything else is a stale translation).
  final bool isOrphan;
}

class _TranslationsEditorPageState extends ConsumerState<TranslationsEditorPage> {
  bool _loading = true;
  String? _error;
  bool _saving = false;

  // Original ARB blobs as returned by the API. We hold onto these so we
  // can preserve metadata blocks (`@key`) and orphan keys on save without
  // exposing them in the per-key form.
  Map<String, dynamic> _enRaw = {};
  Map<String, dynamic> _targetRaw = {};

  // The form rows, in en order (orphans appended at the end).
  List<_Row> _rows = [];

  // UI state.
  String _search = '';
  bool _untranslatedOnly = false;
  bool _dropOrphansOnSave = false;

  bool get _isEnLocale => widget.locale == 'en';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      // Fetch en + target in parallel. For en we still hit the same URL
      // (it's just the same locale) — Dart's Future.wait handles the
      // identity case fine.
      final results = await Future.wait([
        api.getJson('/admin/translations/en'),
        api.getJson('/admin/translations/${widget.locale}'),
      ]);
      _enRaw = (results[0]['data'] as Map).cast<String, dynamic>();
      _targetRaw = (results[1]['data'] as Map).cast<String, dynamic>();
      _rebuildRows();
      if (mounted) {
        setState(() => _loading = false);
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _error = err.toString();
          _loading = false;
        });
      }
    }
  }

  void _rebuildRows() {
    // Dispose previous controllers if we're rebuilding.
    for (final r in _rows) {
      r.controller.dispose();
    }
    final rows = <_Row>[];

    // 1. Walk en in its native order. Skip metadata + locale markers from
    //    the top-level form view; the editor exposes only translatable
    //    string values.
    for (final entry in _enRaw.entries) {
      final key = entry.key;
      if (key.startsWith('@')) continue;
      if (entry.value is! String) continue;
      final enValue = entry.value as String;
      final descMap = _enRaw['@$key'];
      final description = (descMap is Map && descMap['description'] is String)
          ? descMap['description'] as String
          : null;
      final originalTargetValue = _targetRaw[key] is String ? _targetRaw[key] as String : null;
      rows.add(_Row(
        key: key,
        enValue: enValue,
        enDescription: description,
        originalTargetValue: originalTargetValue,
        controller: TextEditingController(text: originalTargetValue ?? ''),
        isOrphan: false,
      ));
    }

    // 2. Append orphans — keys in target that en doesn't have. These show
    //    a badge so the operator can decide whether to drop them.
    for (final entry in _targetRaw.entries) {
      final key = entry.key;
      if (key.startsWith('@')) continue;
      if (entry.value is! String) continue;
      if (_enRaw.containsKey(key)) continue;
      final value = entry.value as String;
      rows.add(_Row(
        key: key,
        enValue: '', // no en reference for orphans
        enDescription: null,
        originalTargetValue: value,
        controller: TextEditingController(text: value),
        isOrphan: true,
      ));
    }

    _rows = rows;
  }

  List<_Row> get _filteredRows {
    final s = _search.trim().toLowerCase();
    return _rows.where((r) {
      if (s.isNotEmpty) {
        final matches = r.key.toLowerCase().contains(s) ||
            r.enValue.toLowerCase().contains(s) ||
            r.controller.text.toLowerCase().contains(s);
        if (!matches) return false;
      }
      if (_untranslatedOnly && !_isEnLocale) {
        if (r.isOrphan) return false; // orphans are translated; just stale
        final v = r.controller.text;
        if (v.isNotEmpty && v != r.enValue) return false;
      }
      return true;
    }).toList(growable: false);
  }

  int get _untranslatedCount {
    if (_isEnLocale) return 0;
    int count = 0;
    for (final r in _rows) {
      if (r.isOrphan) continue;
      final v = r.controller.text;
      if (v.isEmpty || v == r.enValue) count++;
    }
    return count;
  }

  int get _dirtyCount {
    int count = 0;
    for (final r in _rows) {
      final orig = r.originalTargetValue ?? '';
      if (r.controller.text != orig) count++;
    }
    return count;
  }

  // Build the ARB body to send back to the API. We preserve any `@key`
  // metadata blocks from the original target (in non-en) or en (in en),
  // and only drop orphans when explicitly requested.
  Map<String, dynamic> _buildSavePayload() {
    final out = <String, dynamic>{};

    if (_isEnLocale) {
      // Editing en directly: rewrite values in en order, preserve every
      // `@key` block unchanged. We don't expose `@key` editing in the
      // form (description is read-only there) — preserving keeps any
      // hand-edited metadata intact.
      for (final entry in _enRaw.entries) {
        final key = entry.key;
        if (key == '@@locale') continue; // API restamps this
        if (key.startsWith('@')) {
          out[key] = entry.value;
          continue;
        }
        final row = _rows.firstWhere(
          (r) => r.key == key,
          orElse: () => _Row(
            key: key,
            enValue: '',
            enDescription: null,
            originalTargetValue: null,
            controller: TextEditingController(text: entry.value as String),
            isOrphan: false,
          ),
        );
        out[key] = row.controller.text;
      }
      return out;
    }

    // Non-en: walk en, take editor values, skip empty (let gen-l10n fall
    // back to en for untouched keys). Then optionally append orphans.
    for (final entry in _enRaw.entries) {
      final key = entry.key;
      if (key.startsWith('@')) continue; // metadata stays in en only
      final row = _rows.firstWhere(
        (r) => r.key == key,
        orElse: () => _Row(
          key: key,
          enValue: entry.value as String,
          enDescription: null,
          originalTargetValue: null,
          controller: TextEditingController(),
          isOrphan: false,
        ),
      );
      final value = row.controller.text;
      if (value.isNotEmpty) out[key] = value;
    }

    // Orphans: keys in target but not in en. Drop them if requested.
    if (!_dropOrphansOnSave) {
      for (final entry in _targetRaw.entries) {
        final key = entry.key;
        if (key == '@@locale') continue;
        if (key.startsWith('@')) {
          // Preserve metadata blocks for non-orphan AND orphan keys (the
          // metadata file might still want them).
          out[key] = entry.value;
          continue;
        }
        if (_enRaw.containsKey(key)) continue; // already handled above
        final row = _rows.firstWhere(
          (r) => r.key == key,
          orElse: () => _Row(
            key: key,
            enValue: '',
            enDescription: null,
            originalTargetValue: entry.value as String,
            controller: TextEditingController(text: entry.value as String),
            isOrphan: true,
          ),
        );
        final value = row.controller.text;
        if (value.isNotEmpty) out[key] = value;
      }
    }

    return out;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final payload = _buildSavePayload();
      await ref.read(apiClientProvider).putJson(
            '/admin/translations/${widget.locale}',
            body: {'data': payload},
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
          'Saved. Run `flutter gen-l10n` and rebuild the app for changes to take effect.',
        ),
        duration: Duration(seconds: 6),
      ));
      // Refresh from disk so original-vs-current diffing resets.
      await _load();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Save failed: $err'),
      ));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _discard() {
    for (final r in _rows) {
      r.controller.text = r.originalTargetValue ?? '';
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('Error: $_error'));
    }

    final filtered = _filteredRows;
    final dirty = _dirtyCount;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Translations — ${widget.locale}',
            subtitle: _isEnLocale
                ? 'Edit the English source ARB. Each row shows the key and its value; descriptions are read-only.'
                : '$_untranslatedCount of ${_rows.where((r) => !r.isOrphan).length} keys not yet translated. Search, filter, edit, then Save.',
            actions: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
                onPressed: () => context.go('/translations'),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Reload',
                onPressed: _load,
              ),
              const SizedBox(width: 8),
              if (dirty > 0)
                OutlinedButton.icon(
                  icon: const Icon(Icons.undo),
                  label: Text('Discard ($dirty)'),
                  onPressed: _saving ? null : _discard,
                ),
              const SizedBox(width: 8),
              FilledButton.icon(
                icon: _saving
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(dirty > 0 ? 'Save ($dirty)' : 'Save'),
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Toolbar(
            search: _search,
            onSearchChanged: (v) => setState(() => _search = v),
            untranslatedOnly: _untranslatedOnly,
            onUntranslatedToggled: _isEnLocale
                ? null
                : (v) => setState(() => _untranslatedOnly = v),
            dropOrphansOnSave: _dropOrphansOnSave,
            onDropOrphansToggled: _isEnLocale
                ? null
                : (v) => setState(() => _dropOrphansOnSave = v),
            visible: filtered.length,
            total: _rows.length,
          ),
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: Text('No keys match the current filter.')),
            )
          else
            ...filtered.map((r) => _RowCard(
                  row: r,
                  isEnLocale: _isEnLocale,
                  onChanged: () => setState(() {}),
                )),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.search,
    required this.onSearchChanged,
    required this.untranslatedOnly,
    required this.onUntranslatedToggled,
    required this.dropOrphansOnSave,
    required this.onDropOrphansToggled,
    required this.visible,
    required this.total,
  });

  final String search;
  final ValueChanged<String> onSearchChanged;
  final bool untranslatedOnly;
  final ValueChanged<bool>? onUntranslatedToggled;
  final bool dropOrphansOnSave;
  final ValueChanged<bool>? onDropOrphansToggled;
  final int visible;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 320,
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search, size: 20),
                  hintText: 'Search by key or value',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: onSearchChanged,
              ),
            ),
            if (onUntranslatedToggled != null)
              FilterChip(
                label: const Text('Untranslated only'),
                selected: untranslatedOnly,
                onSelected: onUntranslatedToggled,
              ),
            if (onDropOrphansToggled != null)
              Tooltip(
                message:
                    'Keys present in this locale but not in English. Off: keep them as-is.',
                child: FilterChip(
                  label: const Text('Drop orphan keys on save'),
                  selected: dropOrphansOnSave,
                  onSelected: onDropOrphansToggled,
                ),
              ),
            Text(
              'Showing $visible of $total',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _RowCard extends StatelessWidget {
  const _RowCard({
    required this.row,
    required this.isEnLocale,
    required this.onChanged,
  });

  final _Row row;
  final bool isEnLocale;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orig = row.originalTargetValue ?? '';
    final isDirty = row.controller.text != orig;
    final isUntranslated = !isEnLocale &&
        !row.isOrphan &&
        (row.controller.text.isEmpty || row.controller.text == row.enValue);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.key,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (row.isOrphan) ...[
                  const _Badge(label: 'orphan', color: Colors.orange),
                  const SizedBox(width: 6),
                ],
                if (isUntranslated) ...[
                  const _Badge(label: 'untranslated', color: Colors.amber),
                  const SizedBox(width: 6),
                ],
                if (isDirty)
                  const _Badge(label: 'modified', color: Colors.blue),
              ],
            ),
            if (row.enDescription != null) ...[
              const SizedBox(height: 4),
              Text(
                row.enDescription!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 8),
            if (!isEnLocale && !row.isOrphan) ...[
              _ReferenceLine(label: 'EN', value: row.enValue),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: row.controller,
              maxLines: null,
              decoration: InputDecoration(
                labelText: isEnLocale
                    ? 'value'
                    : (row.isOrphan ? '${row.key} (orphan)' : 'translation'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => onChanged(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferenceLine extends StatelessWidget {
  const _ReferenceLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
