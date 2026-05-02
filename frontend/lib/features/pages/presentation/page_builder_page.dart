import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/page_header.dart';
import 'block_inspectors.dart';

const _blockTypeOrder = <String>[
  'text', 'heading', 'image', 'button', 'card', 'container',
  'divider', 'spacer', 'list', 'table', 'chart',
  'iframe', 'html', 'custom_entity_list', 'report',
];

String _blockTypeLabel(AppLocalizations t, String type) {
  switch (type) {
    case 'text': return t.blockTypeText;
    case 'heading': return t.blockTypeHeading;
    case 'image': return t.blockTypeImage;
    case 'button': return t.blockTypeButton;
    case 'card': return t.blockTypeCard;
    case 'container': return t.blockTypeContainer;
    case 'divider': return t.blockTypeDivider;
    case 'spacer': return t.blockTypeSpacer;
    case 'list': return t.blockTypeList;
    case 'table': return t.blockTypeTable;
    case 'chart': return t.blockTypeChart;
    case 'iframe': return t.blockTypeIframe;
    case 'html': return t.blockTypeHtml;
    case 'custom_entity_list': return t.blockTypeCustomEntityList;
    case 'report': return t.blockTypeReport;
    default: return type;
  }
}

class PageBuilderPage extends ConsumerStatefulWidget {
  const PageBuilderPage({super.key, required this.pageId});
  final int pageId;

  @override
  ConsumerState<PageBuilderPage> createState() => _PageBuilderPageState();
}

class _PageBuilderPageState extends ConsumerState<PageBuilderPage> {
  Map<String, dynamic>? _page;
  List<Map<String, dynamic>> _blocks = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(apiClientProvider);
    setState(() { _loading = true; _error = null; });
    try {
      final res = await api.getJson('/pages/${widget.pageId}');
      if (!mounted) return;
      setState(() {
        _page = (res['page'] as Map).cast<String, dynamic>();
        _blocks = (res['blocks'] as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() { _error = err.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Error: $_error'));
    final p = _page!;

    final topLevel = _blocks.where((b) => b['parentId'] == null).toList();
    final containers = _blocks.where((b) => b['type'] == 'container' || b['type'] == 'card').toList();

    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageHeader(
                  title: 'Builder — ${p['title']}',
                  subtitle: 'Route: ${p['route']}  •  Drag the handle to reorder.',
                  actions: [
                    IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
                  ],
                ),
                if (_blocks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Empty page. Add blocks from the right panel.'),
                  ),
                ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  onReorder: _onReorderTopLevel,
                  children: [
                    for (var i = 0; i < topLevel.length; i++)
                      _buildBlockTree(topLevel[i], containers, depth: 0, index: i, key: ValueKey('block-${topLevel[i]['id']}')),
                  ],
                ),
              ],
            ),
          ),
        ),
        Container(
          width: 280,
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: ListView(
            children: [
              Text(AppLocalizations.of(context).addBlockHeader, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              ..._blockTypeOrder.map(
                (type) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(_blockTypeLabel(AppLocalizations.of(context), type)),
                    onPressed: () => _addBlock(type),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBlockTree(
    Map<String, dynamic> b,
    List<Map<String, dynamic>> containers, {
    required int depth,
    required int index,
    required Key key,
  }) {
    final children = _blocks.where((c) => c['parentId'] == b['id']).toList();
    final isContainer = b['type'] == 'container' || b['type'] == 'card';

    return Padding(
      key: key,
      padding: EdgeInsets.only(left: depth * 16.0, top: 4, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _renderBlockCard(b, containers, dragIndex: index, depth: depth),
          if (isContainer && children.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
              child: Column(
                children: [
                  for (final c in children)
                    _renderBlockCard(c, containers, dragIndex: -1, depth: depth + 1),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _onReorderTopLevel(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final topLevel = _blocks.where((b) => b['parentId'] == null).toList();
    final moved = topLevel.removeAt(oldIndex);
    topLevel.insert(newIndex, moved);
    final order = [
      for (var i = 0; i < topLevel.length; i++) {'id': topLevel[i]['id'], 'parentId': null},
    ];
    final api = ref.read(apiClientProvider);
    await api.postJson('/pages/${widget.pageId}/reorder', body: {'order': order});
    await _load();
  }

  Widget _renderBlockCard(
    Map<String, dynamic> b,
    List<Map<String, dynamic>> containers, {
    required int dragIndex,
    required int depth,
  }) {
    final type = b['type']?.toString() ?? '';
    final label = _blockTypeLabel(AppLocalizations.of(context), type);
    final cfg = (b['config'] as Map?) ?? {};
    final parentId = b['parentId'];

    return Card(
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dragIndex >= 0)
              ReorderableDragStartListener(
                index: dragIndex,
                child: const Icon(Icons.drag_handle, size: 18),
              )
            else
              const SizedBox(width: 18),
            const SizedBox(width: 8),
            Icon(_iconFor(type)),
          ],
        ),
        title: Text(label),
        subtitle: Text(cfg.isEmpty ? '(no config)' : const JsonEncoder().convert(cfg)),
        trailing: Wrap(
          spacing: 4,
          children: [
            PopupMenuButton<int?>(
              icon: const Icon(Icons.account_tree_outlined, size: 18),
              tooltip: 'Move to container',
              onSelected: (v) => _moveToParent(b['id'] as int, v),
              itemBuilder: (_) => [
                PopupMenuItem<int?>(
                  value: null,
                  enabled: parentId != null,
                  child: const Text('— Top level —'),
                ),
                ...containers
                    .where((c) => c['id'] != b['id'])
                    .map((c) => PopupMenuItem<int?>(
                          value: c['id'] as int,
                          child: Text('${_blockTypeLabel(AppLocalizations.of(context), c['type']?.toString() ?? '')} #${c['id']}'),
                        )),
              ],
            ),
            IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () => _editBlock(b)),
            IconButton(icon: const Icon(Icons.delete_outline, size: 18), onPressed: () => _deleteBlock(b['id'] as int)),
          ],
        ),
      ),
    );
  }

  Future<void> _moveToParent(int blockId, int? newParentId) async {
    if (newParentId == blockId) return;
    final api = ref.read(apiClientProvider);
    await api.putJson('/pages/${widget.pageId}/blocks/$blockId', body: {'parentId': newParentId});
    await _load();
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'text': return Icons.short_text;
      case 'heading': return Icons.title;
      case 'image': return Icons.image_outlined;
      case 'button': return Icons.smart_button;
      case 'card': return Icons.crop_square;
      case 'container': return Icons.dashboard_customize;
      case 'divider': return Icons.horizontal_rule;
      case 'spacer': return Icons.unfold_more;
      case 'list': return Icons.list_alt;
      case 'table': return Icons.table_chart_outlined;
      case 'chart': return Icons.show_chart;
      case 'iframe': return Icons.web_asset;
      case 'html': return Icons.code;
      case 'custom_entity_list': return Icons.list_alt_outlined;
      case 'report': return Icons.analytics_outlined;
      default: return Icons.widgets_outlined;
    }
  }

  Future<void> _addBlock(String type) async {
    final api = ref.read(apiClientProvider);
    await api.postJson('/pages/${widget.pageId}/blocks', body: {
      'type': type,
      'sortOrder': _blocks.length,
      'config': _defaultConfig(type),
    });
    await _load();
  }

  Map<String, dynamic> _defaultConfig(String type) {
    switch (type) {
      case 'text': return {'text': 'Click edit to change me.'};
      case 'heading': return {'text': 'Heading', 'level': 2};
      case 'image': return {'url': '', 'fit': 'cover'};
      case 'button': return {'label': 'Button', 'route': '/dashboard', 'variant': 'filled'};
      case 'card': return {'title': 'Card', 'body': ''};
      case 'spacer': return {'height': 16};
      case 'iframe': return {'url': 'https://example.com', 'height': 400};
      case 'html': return {'html': '<p>Hello</p>'};
      case 'report': return {'reportCode': ''};
      case 'custom_entity_list': return {'entityCode': ''};
      default: return {};
    }
  }

  Future<void> _editBlock(Map<String, dynamic> b) async {
    final type = b['type']?.toString() ?? '';
    final label = _blockTypeLabel(AppLocalizations.of(context), type);
    final config = ((b['config'] as Map?) ?? const {}).cast<String, dynamic>();

    final typed = inspectorFor(type);
    Map<String, dynamic>? next;
    if (typed != null) {
      next = await typed(context, config);
    } else {
      next = await jsonInspector(context, label, config);
    }
    if (next == null) return;
    if (!mounted) return;

    final api = ref.read(apiClientProvider);
    try {
      await api.putJson('/pages/${widget.pageId}/blocks/${b['id']}', body: {'config': next});
      await _load();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.toString())));
    }
  }

  Future<void> _deleteBlock(int id) async {
    final api = ref.read(apiClientProvider);
    await api.deleteJson('/pages/${widget.pageId}/blocks/$id');
    await _load();
  }
}
