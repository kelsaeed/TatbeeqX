import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../l10n/gen/app_localizations.dart';

class UserFormDialog extends ConsumerStatefulWidget {
  const UserFormDialog({super.key, this.existing});
  final Map<String, dynamic>? existing;

  @override
  ConsumerState<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends ConsumerState<UserFormDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _username;
  late final TextEditingController _email;
  late final TextEditingController _fullName;
  late final TextEditingController _phone;
  late final TextEditingController _password;

  bool _isActive = true;
  int? _companyId;
  int? _branchId;
  Set<int> _roleIds = {};
  bool _saving = false;

  List<Map<String, dynamic>> _companies = [];
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _roles = [];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _username = TextEditingController(text: e?['username']?.toString() ?? '');
    _email = TextEditingController(text: e?['email']?.toString() ?? '');
    _fullName = TextEditingController(text: e?['fullName']?.toString() ?? '');
    _phone = TextEditingController(text: e?['phone']?.toString() ?? '');
    _password = TextEditingController();
    _isActive = (e?['isActive'] as bool?) ?? true;
    _companyId = e?['companyId'] as int?;
    _branchId = e?['branchId'] as int?;
    _roleIds = ((e?['roles'] as List? ?? const []).map((r) => r['id'] as int)).toSet();
    Future.microtask(_loadLookups);
  }

  Future<void> _loadLookups() async {
    final api = ref.read(apiClientProvider);
    try {
      final c = await api.getJson('/companies');
      final r = await api.getJson('/roles');
      List<Map<String, dynamic>> b = [];
      if (_companyId != null) {
        final br = await api.getJson('/branches', query: {'companyId': _companyId});
        b = (br['items'] as List).cast<Map<String, dynamic>>();
      }
      if (!mounted) return;
      setState(() {
        _companies = (c['items'] as List).cast<Map<String, dynamic>>();
        _roles = (r['items'] as List).cast<Map<String, dynamic>>();
        _branches = b;
      });
    } catch (_) {}
  }

  Future<void> _onCompanyChanged(int? id) async {
    setState(() {
      _companyId = id;
      _branchId = null;
      _branches = [];
    });
    if (id == null) return;
    final br = await ref.read(apiClientProvider).getJson('/branches', query: {'companyId': id});
    if (!mounted) return;
    setState(() => _branches = (br['items'] as List).cast<Map<String, dynamic>>());
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final api = ref.read(apiClientProvider);
    final body = <String, dynamic>{
      'username': _username.text.trim(),
      'email': _email.text.trim(),
      'fullName': _fullName.text.trim(),
      'phone': _phone.text.trim(),
      'isActive': _isActive,
      'companyId': _companyId,
      'branchId': _branchId,
      'roleIds': _roleIds.toList(),
    };
    if (_password.text.isNotEmpty) body['password'] = _password.text;
    try {
      if (widget.existing == null) {
        body['password'] ??= _password.text;
        await api.postJson('/users', body: body);
      } else {
        await api.putJson('/users/${widget.existing!['id']}', body: body);
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
    final isNew = widget.existing == null;
    return AlertDialog(
      title: Text(isNew ? t.newUser : t.editUser),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: _username,
                  // First field gets focus so the form is typeable
                  // immediately without a click.
                  autofocus: true,
                  decoration: InputDecoration(labelText: t.username),
                  validator: (v) => (v == null || v.trim().isEmpty) ? t.required : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  decoration: InputDecoration(labelText: t.email),
                  validator: (v) => (v == null || !v.contains('@')) ? t.invalidEmail : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _fullName,
                  decoration: InputDecoration(labelText: t.fullName),
                  validator: (v) => (v == null || v.trim().isEmpty) ? t.required : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  decoration: InputDecoration(labelText: t.phoneOptional),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  decoration: InputDecoration(labelText: isNew ? t.passwordField : t.newPasswordKeepBlank),
                  obscureText: true,
                  validator: (v) {
                    if (isNew && (v == null || v.length < 8)) return t.min8Chars;
                    if (!isNew && v != null && v.isNotEmpty && v.length < 8) return t.min8Chars;
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  initialValue: _companyId,
                  decoration: InputDecoration(labelText: t.companyField),
                  items: [
                    DropdownMenuItem(value: null, child: Text(t.noneOption)),
                    ..._companies.map((c) => DropdownMenuItem<int?>(value: c['id'] as int, child: Text(c['name'].toString()))),
                  ],
                  onChanged: _onCompanyChanged,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  initialValue: _branchId,
                  decoration: InputDecoration(labelText: t.branchField),
                  items: [
                    DropdownMenuItem(value: null, child: Text(t.noneOption)),
                    ..._branches.map((b) => DropdownMenuItem<int?>(value: b['id'] as int, child: Text(b['name'].toString()))),
                  ],
                  onChanged: (v) => setState(() => _branchId = v),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(t.rolesField, style: Theme.of(context).textTheme.bodyMedium),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _roles.map((r) {
                    final id = r['id'] as int;
                    final selected = _roleIds.contains(id);
                    return FilterChip(
                      label: Text(r['name'].toString()),
                      selected: selected,
                      onSelected: (v) => setState(() {
                        if (v) {
                          _roleIds.add(id);
                        } else {
                          _roleIds.remove(id);
                        }
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: Text(t.active),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                  contentPadding: EdgeInsets.zero,
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
