import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/page_header.dart';
import '../../auth/application/auth_controller.dart';

class BranchesPage extends ConsumerStatefulWidget {
  const BranchesPage({super.key});

  @override
  ConsumerState<BranchesPage> createState() => _BranchesPageState();
}

class _BranchesPageState extends ConsumerState<BranchesPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _companies = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final api = ref.read(apiClientProvider);
    try {
      final res = await api.getJson('/branches');
      final co = await api.getJson('/companies');
      setState(() {
        _items = (res['items'] as List).cast<Map<String, dynamic>>();
        _companies = (co['items'] as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).loadFailed(e.toString()))),
      );
    }
  }

  Future<void> _open({Map<String, dynamic>? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _BranchForm(existing: existing, companies: _companies),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> r) async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.deleteBranch),
        content: Text(t.deleteConfirm(r['name'].toString())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider).deleteJson('/branches/${r['id']}');
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.deleteFailedMsg(e.toString()))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final t = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: t.branches,
            subtitle: t.branchesSubtitle,
            actions: [
              if (auth.can('branches.create'))
                ElevatedButton.icon(
                  onPressed: () => _open(),
                  icon: const Icon(Icons.add),
                  label: Text(t.newBranch),
                ),
            ],
          ),
          if (_loading)
            const Padding(padding: EdgeInsets.all(40), child: LoadingView())
          else
            Card(
              child: Column(
                children: [
                  for (final b in _items) ...[
                    ListTile(
                      leading: const Icon(Icons.store_outlined),
                      title: Text(b['name'].toString()),
                      subtitle: Text('${b['code']} • ${b['company']?['name'] ?? '—'}'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (auth.can('branches.edit'))
                          IconButton(onPressed: () => _open(existing: b), icon: const Icon(Icons.edit_outlined, size: 18)),
                        if (auth.can('branches.delete'))
                          IconButton(onPressed: () => _delete(b), icon: const Icon(Icons.delete_outline, size: 18)),
                      ]),
                    ),
                    const Divider(height: 1),
                  ],
                  if (_items.isEmpty) Padding(padding: const EdgeInsets.all(28), child: Text(t.noBranches)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BranchForm extends ConsumerStatefulWidget {
  const _BranchForm({this.existing, required this.companies});
  final Map<String, dynamic>? existing;
  final List<Map<String, dynamic>> companies;

  @override
  ConsumerState<_BranchForm> createState() => _BranchFormState();
}

class _BranchFormState extends ConsumerState<_BranchForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  int? _companyId;
  bool _active = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing ?? {};
    _code = TextEditingController(text: (e['code'] ?? '').toString());
    _name = TextEditingController(text: (e['name'] ?? '').toString());
    _address = TextEditingController(text: (e['address'] ?? '').toString());
    _phone = TextEditingController(text: (e['phone'] ?? '').toString());
    _companyId = e['companyId'] as int?;
    _active = (e['isActive'] as bool?) ?? true;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final t = AppLocalizations.of(context);
    if (_companyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.selectCompany)));
      return;
    }
    setState(() => _saving = true);
    final api = ref.read(apiClientProvider);
    final body = {
      'companyId': _companyId,
      'code': _code.text.trim(),
      'name': _name.text.trim(),
      'address': _address.text.trim().isEmpty ? null : _address.text.trim(),
      'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      'isActive': _active,
    };
    try {
      if (widget.existing == null) {
        await api.postJson('/branches', body: body);
      } else {
        await api.putJson('/branches/${widget.existing!['id']}', body: body);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.saveFailed(e.toString()))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.existing == null ? t.newBranch : t.editBranch),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: _companyId,
                decoration: InputDecoration(labelText: t.companyField),
                items: widget.companies
                    .map((c) => DropdownMenuItem<int>(value: c['id'] as int, child: Text(c['name'].toString())))
                    .toList(),
                onChanged: (v) => setState(() => _companyId = v),
                validator: (v) => v == null ? t.required : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _code,
                decoration: InputDecoration(labelText: t.code),
                validator: (v) => (v == null || v.trim().isEmpty) ? t.required : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                decoration: InputDecoration(labelText: t.name),
                validator: (v) => (v == null || v.trim().isEmpty) ? t.required : null,
              ),
              const SizedBox(height: 12),
              TextFormField(controller: _address, decoration: InputDecoration(labelText: t.address)),
              const SizedBox(height: 12),
              TextFormField(controller: _phone, decoration: InputDecoration(labelText: t.phone)),
              const SizedBox(height: 12),
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
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: Text(t.cancel)),
        ElevatedButton(onPressed: _saving ? null : _save, child: Text(_saving ? t.saving : t.save)),
      ],
    );
  }
}
