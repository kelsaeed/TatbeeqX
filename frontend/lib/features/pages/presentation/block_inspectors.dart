import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';

/// Phase 4.4 — typed inspector dialogs per block type.
/// Returns the new config map, or null on cancel.
typedef Inspector = Future<Map<String, dynamic>?> Function(
  BuildContext context,
  Map<String, dynamic> config,
);

Inspector? inspectorFor(String type) {
  switch (type) {
    case 'text': return _textInspector;
    case 'heading': return _headingInspector;
    case 'image': return _imageInspector;
    case 'button': return _buttonInspector;
    case 'card': return _cardInspector;
    case 'spacer': return _spacerInspector;
    case 'iframe': return _iframeInspector;
    case 'html': return _htmlInspector;
    case 'report': return _reportInspector;
    case 'custom_entity_list': return _entityListInspector;
    case 'divider': return _noConfigInspector;
    default: return null;
  }
}

Future<Map<String, dynamic>?> _wrap(
  BuildContext context,
  String title,
  List<Widget> Function(StateSetter) buildBody,
  Map<String, dynamic> Function() collect,
) {
  final t = AppLocalizations.of(context);
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSt) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: buildBody(setSt),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, collect()), child: Text(t.save)),
        ],
      ),
    ),
  );
}

Future<Map<String, dynamic>?> _textInspector(BuildContext context, Map<String, dynamic> config) {
  final t = AppLocalizations.of(context);
  final text = TextEditingController(text: config['text']?.toString() ?? '');
  return _wrap(
    context,
    t.inspectorTitleText,
    (_) => [
      TextField(
        controller: text,
        minLines: 3,
        maxLines: 8,
        decoration: InputDecoration(labelText: t.blockTypeText, border: const OutlineInputBorder()),
      ),
    ],
    () => {'text': text.text},
  );
}

Future<Map<String, dynamic>?> _headingInspector(BuildContext context, Map<String, dynamic> config) {
  final t = AppLocalizations.of(context);
  final text = TextEditingController(text: config['text']?.toString() ?? '');
  int level = (config['level'] as num?)?.toInt() ?? 2;
  return _wrap(
    context,
    t.inspectorTitleHeading,
    (setSt) => [
      TextField(
        controller: text,
        decoration: InputDecoration(labelText: t.blockTypeText),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<int>(
        initialValue: level,
        decoration: InputDecoration(labelText: t.inspectorLevelLabel),
        items: [
          DropdownMenuItem(value: 1, child: Text(t.inspectorH1)),
          DropdownMenuItem(value: 2, child: Text(t.inspectorH2)),
          DropdownMenuItem(value: 3, child: Text(t.inspectorH3)),
          DropdownMenuItem(value: 4, child: Text(t.inspectorH4)),
        ],
        onChanged: (v) => setSt(() => level = v ?? 2),
      ),
    ],
    () => {'text': text.text, 'level': level},
  );
}

Future<Map<String, dynamic>?> _imageInspector(BuildContext context, Map<String, dynamic> config) {
  final t = AppLocalizations.of(context);
  final url = TextEditingController(text: config['url']?.toString() ?? '');
  String fit = config['fit']?.toString() ?? 'cover';
  return _wrap(
    context,
    t.inspectorTitleImage,
    (setSt) => [
      TextField(
        controller: url,
        decoration: InputDecoration(
          labelText: t.urlHint,
          hintText: t.inspectorImageUrlHint,
        ),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: fit,
        decoration: InputDecoration(labelText: t.inspectorFitLabel),
        items: [
          DropdownMenuItem(value: 'cover', child: Text(t.inspectorFitCover)),
          DropdownMenuItem(value: 'contain', child: Text(t.inspectorFitContain)),
          DropdownMenuItem(value: 'fill', child: Text(t.inspectorFitFill)),
        ],
        onChanged: (v) => setSt(() => fit = v ?? 'cover'),
      ),
    ],
    () => {'url': url.text.trim(), 'fit': fit},
  );
}

Future<Map<String, dynamic>?> _buttonInspector(BuildContext context, Map<String, dynamic> config) {
  final t = AppLocalizations.of(context);
  final label = TextEditingController(text: config['label']?.toString() ?? 'Button');
  final route = TextEditingController(text: config['route']?.toString() ?? '/');
  String variant = config['variant']?.toString() ?? 'filled';
  // Phase 4.17 v2 — optional workflow trigger. When set, tap fires
  // POST /api/workflows/by-code/<code>/run instead of navigating.
  final workflowCode = TextEditingController(text: config['workflowCode']?.toString() ?? '');
  final workflowPayload = TextEditingController(
    text: config['workflowPayload'] is Map
        ? const JsonEncoder.withIndent('  ').convert(config['workflowPayload'])
        : (config['workflowPayload']?.toString() ?? ''),
  );
  return _wrap(
    context,
    t.inspectorTitleButton,
    (setSt) => [
      TextField(controller: label, decoration: InputDecoration(labelText: t.labelField)),
      const SizedBox(height: 12),
      TextField(controller: route, decoration: InputDecoration(labelText: t.inspectorRouteLabel)),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: variant,
        decoration: InputDecoration(labelText: t.inspectorStyleLabel),
        items: [
          DropdownMenuItem(value: 'filled', child: Text(t.inspectorVariantFilled)),
          DropdownMenuItem(value: 'outlined', child: Text(t.inspectorVariantOutlined)),
          DropdownMenuItem(value: 'text', child: Text(t.inspectorVariantText)),
        ],
        onChanged: (v) => setSt(() => variant = v ?? 'filled'),
      ),
      const Divider(height: 24),
      const Text(
        'Workflow trigger (optional)',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
      ),
      const Text(
        'When a workflow code is set, tapping the button fires the workflow instead of navigating.',
        style: TextStyle(fontSize: 11, color: Colors.grey),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: workflowCode,
        decoration: const InputDecoration(labelText: 'Workflow code (lower_snake)'),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: workflowPayload,
        maxLines: 3,
        minLines: 1,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        decoration: const InputDecoration(
          labelText: 'Payload (JSON, optional)',
          border: OutlineInputBorder(),
        ),
      ),
    ],
    () {
      final out = <String, dynamic>{
        'label': label.text,
        'route': route.text.trim(),
        'variant': variant,
      };
      final wc = workflowCode.text.trim();
      if (wc.isNotEmpty) out['workflowCode'] = wc;
      final wp = workflowPayload.text.trim();
      if (wp.isNotEmpty) {
        try {
          out['workflowPayload'] = jsonDecode(wp);
        } catch (_) {
          out['workflowPayload'] = wp;
        }
      }
      return out;
    },
  );
}

Future<Map<String, dynamic>?> _cardInspector(BuildContext context, Map<String, dynamic> config) {
  final t = AppLocalizations.of(context);
  final title = TextEditingController(text: config['title']?.toString() ?? '');
  final body = TextEditingController(text: config['body']?.toString() ?? '');
  return _wrap(
    context,
    t.inspectorTitleCard,
    (_) => [
      TextField(controller: title, decoration: InputDecoration(labelText: t.titleField)),
      const SizedBox(height: 12),
      TextField(
        controller: body,
        minLines: 2,
        maxLines: 6,
        decoration: InputDecoration(labelText: t.inspectorBodyLabel, border: const OutlineInputBorder()),
      ),
    ],
    () => {'title': title.text, 'body': body.text},
  );
}

Future<Map<String, dynamic>?> _spacerInspector(BuildContext context, Map<String, dynamic> config) {
  final t = AppLocalizations.of(context);
  final h = TextEditingController(text: ((config['height'] as num?) ?? 16).toString());
  return _wrap(
    context,
    t.inspectorTitleSpacer,
    (_) => [
      TextField(
        controller: h,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: t.inspectorHeightPxLabel),
      ),
    ],
    () => {'height': int.tryParse(h.text.trim()) ?? 16},
  );
}

Future<Map<String, dynamic>?> _iframeInspector(BuildContext context, Map<String, dynamic> config) {
  final t = AppLocalizations.of(context);
  final url = TextEditingController(text: config['url']?.toString() ?? '');
  final h = TextEditingController(text: ((config['height'] as num?) ?? 400).toString());
  return _wrap(
    context,
    t.inspectorTitleIframe,
    (_) => [
      TextField(controller: url, decoration: InputDecoration(labelText: t.urlHint)),
      const SizedBox(height: 12),
      TextField(
        controller: h,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: t.inspectorHeightPxLabel),
      ),
    ],
    () => {'url': url.text.trim(), 'height': int.tryParse(h.text.trim()) ?? 400},
  );
}

Future<Map<String, dynamic>?> _htmlInspector(BuildContext context, Map<String, dynamic> config) {
  final t = AppLocalizations.of(context);
  final html = TextEditingController(text: config['html']?.toString() ?? '');
  return _wrap(
    context,
    t.inspectorTitleHtml,
    (_) => [
      Text(
        t.inspectorHtmlNotice,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: html,
        minLines: 6,
        maxLines: 14,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        decoration: const InputDecoration(border: OutlineInputBorder()),
      ),
    ],
    () => {'html': html.text},
  );
}

Future<Map<String, dynamic>?> _reportInspector(BuildContext context, Map<String, dynamic> config) {
  final t = AppLocalizations.of(context);
  final code = TextEditingController(text: config['reportCode']?.toString() ?? '');
  String mode = config['mode']?.toString() ?? 'table';
  return _wrap(
    context,
    t.inspectorTitleReport,
    (setSt) => [
      TextField(controller: code, decoration: InputDecoration(labelText: t.inspectorReportCodeLabel)),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: mode,
        decoration: InputDecoration(labelText: t.inspectorRenderAsLabel),
        items: [
          DropdownMenuItem(value: 'table', child: Text(t.inspectorRenderAsTable)),
          DropdownMenuItem(value: 'chart', child: Text(t.inspectorRenderAsChart)),
        ],
        onChanged: (v) => setSt(() => mode = v ?? 'table'),
      ),
    ],
    () => {'reportCode': code.text.trim(), 'mode': mode},
  );
}

Future<Map<String, dynamic>?> _entityListInspector(BuildContext context, Map<String, dynamic> config) {
  final t = AppLocalizations.of(context);
  final code = TextEditingController(text: config['entityCode']?.toString() ?? '');
  final pageSize = TextEditingController(text: ((config['pageSize'] as num?) ?? 25).toString());
  return _wrap(
    context,
    t.inspectorTitleEntityList,
    (_) => [
      TextField(controller: code, decoration: InputDecoration(labelText: t.inspectorEntityCodeLabel)),
      const SizedBox(height: 12),
      TextField(
        controller: pageSize,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: t.inspectorPageSizeLabel),
      ),
    ],
    () => {
      'entityCode': code.text.trim(),
      'pageSize': int.tryParse(pageSize.text.trim()) ?? 25,
    },
  );
}

Future<Map<String, dynamic>?> _noConfigInspector(BuildContext context, Map<String, dynamic> config) async {
  final t = AppLocalizations.of(context);
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(t.inspectorTitleDivider),
      content: Text(t.inspectorNoOptions),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t.ok))],
    ),
  );
  return config;
}

/// Fallback for block types without a typed inspector — opens a JSON editor.
Future<Map<String, dynamic>?> jsonInspector(
  BuildContext context,
  String typeLabel,
  Map<String, dynamic> config,
) async {
  final t = AppLocalizations.of(context);
  final controller = TextEditingController(
    text: const JsonEncoder.withIndent('  ').convert(config),
  );
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(t.inspectorEditTitle(typeLabel)),
      content: SizedBox(
        width: 520,
        child: TextField(
          controller: controller,
          maxLines: 14,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t.save)),
      ],
    ),
  );
  if (ok != true) return null;
  try {
    final parsed = jsonDecode(controller.text);
    if (parsed is Map) return parsed.cast<String, dynamic>();
    return {};
  } catch (err) {
    if (!context.mounted) return null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t.inspectorInvalidJson(err.toString()))),
    );
    return null;
  }
}
