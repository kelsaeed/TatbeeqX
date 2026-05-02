import 'dart:io';

import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/providers.dart';
import '../../l10n/gen/app_localizations.dart';

class LocalFileUploadField extends ConsumerStatefulWidget {
  const LocalFileUploadField({
    super.key,
    required this.label,
    required this.value,
    required this.onUploaded,
  });

  final String label;
  final String? value;
  final void Function(String url) onUploaded;

  @override
  ConsumerState<LocalFileUploadField> createState() => _LocalFileUploadFieldState();
}

class _LocalFileUploadFieldState extends ConsumerState<LocalFileUploadField> {
  late final TextEditingController _ctrl;
  late final TextEditingController _path;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value ?? '');
    _path = TextEditingController();
  }

  @override
  void didUpdateWidget(covariant LocalFileUploadField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && (widget.value ?? '') != _ctrl.text) {
      _ctrl.text = widget.value ?? '';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _path.dispose();
    super.dispose();
  }

  Future<void> _upload() async {
    final raw = _path.text.trim().replaceAll('"', '');
    if (raw.isEmpty) return;
    final file = File(raw);
    final exists = await file.exists();
    if (!mounted) return;
    final t = AppLocalizations.of(context);
    if (!exists) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.fileNotFound(raw))));
      return;
    }
    setState(() => _uploading = true);
    try {
      final api = ref.read(apiClientProvider);
      final form = dio.FormData.fromMap({
        'file': await dio.MultipartFile.fromFile(file.path, filename: file.uri.pathSegments.last),
      });
      final resp = await api.dio.post('/uploads/image', data: form);
      final url = resp.data is Map ? resp.data['url']?.toString() : null;
      if (url == null) throw Exception('Server did not return a URL');
      final absolute = url.startsWith('http')
          ? url
          : '${AppConfig.apiBaseUrl.replaceFirst(RegExp(r'/api/?$'), '')}$url';
      _ctrl.text = absolute;
      _path.clear();
      widget.onUploaded(absolute);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.uploaded)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.uploadFailed(e.toString()))));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final isMobile = Platform.isAndroid || Platform.isIOS;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _ctrl,
            decoration: InputDecoration(labelText: widget.label, hintText: t.urlHint),
            onChanged: (v) => widget.onUploaded(v),
          ),
          if (!isMobile) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _path,
                    decoration: InputDecoration(
                      hintText: t.uploadHint,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _uploading ? null : _upload,
                  icon: const Icon(Icons.upload, size: 16),
                  label: Text(_uploading ? t.uploading : t.upload),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
