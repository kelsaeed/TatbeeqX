import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../l10n/gen/app_localizations.dart';

class CompanyFormDialog extends ConsumerStatefulWidget {
  const CompanyFormDialog({super.key, this.existing});
  final Map<String, dynamic>? existing;

  @override
  ConsumerState<CompanyFormDialog> createState() => _CompanyFormDialogState();
}

class _CompanyFormDialogState extends ConsumerState<CompanyFormDialog> {
  final _form = GlobalKey<FormState>();
  final _values = <String, TextEditingController>{};
  bool _active = true;
  bool _saving = false;

  // Field labels are looked up from AppLocalizations at build time so
  // they flip with the active locale.
  static const _fieldKeys = ['code', 'name', 'legalName', 'taxNumber', 'email', 'phone', 'address', 'logoUrl'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing ?? {};
    for (final k in _fieldKeys) {
      _values[k] = TextEditingController(text: (e[k] ?? '').toString());
    }
    _active = (e['isActive'] as bool?) ?? true;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final api = ref.read(apiClientProvider);
    final body = <String, dynamic>{'isActive': _active};
    for (final k in _fieldKeys) {
      final v = _values[k]!.text.trim();
      body[k] = v.isEmpty ? null : v;
    }
    try {
      if (widget.existing == null) {
        await api.postJson('/companies', body: body);
      } else {
        await api.putJson('/companies/${widget.existing!['id']}', body: body);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).saveFailed(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final fieldLabels = <String, String>{
      'code': t.code,
      'name': t.name,
      'legalName': t.legalName,
      'taxNumber': t.taxNumber,
      'email': t.email,
      'phone': t.phone,
      'address': t.address,
      'logoUrl': t.logoUrl,
    };
    return AlertDialog(
      title: Text(widget.existing == null ? t.newCompany : t.editCompany),
      content: SizedBox(
        width: 540,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final k in _fieldKeys) ...[
                  TextFormField(
                    controller: _values[k],
                    decoration: InputDecoration(labelText: fieldLabels[k]),
                    validator: (k == 'code' || k == 'name')
                        ? (v) => (v == null || v.trim().isEmpty) ? t.required : null
                        : null,
                  ),
                  const SizedBox(height: 12),
                ],
                SwitchListTile(
                  title: Text(t.active),
                  contentPadding: EdgeInsets.zero,
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: Text(t.cancel)),
        ElevatedButton(onPressed: _saving ? null : _save, child: Text(_saving ? t.saving : t.save)),
      ],
    );
  }
}
