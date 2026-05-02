import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/icon_lookup.dart';
import '../../shared/widgets/loading_view.dart';
import '../auth/application/auth_controller.dart';
import 'setup_controller.dart';

class SetupPage extends ConsumerStatefulWidget {
  const SetupPage({super.key});

  @override
  ConsumerState<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends ConsumerState<SetupPage> {
  bool _loading = true;
  String? _applying;
  List<Map<String, dynamic>> _presets = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    try {
      final list = await ref.read(setupControllerProvider.notifier).listPresets();
      setState(() {
        _presets = list;
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

  Future<void> _apply(String code) async {
    setState(() => _applying = code);
    try {
      await ref.read(setupControllerProvider.notifier).apply(code);
      if (!mounted) return;
      context.go('/dashboard');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).applyFailed(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _applying = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final t = AppLocalizations.of(context);
    if (!auth.isLoggedIn) {
      return const Scaffold(body: LoadingView());
    }
    if (auth.user!.isSuperAdmin == false) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Text(
              t.setupLocked,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.welcomePickBusinessType, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    t.setupExplain,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 32),
                  if (_loading)
                    const Padding(padding: EdgeInsets.all(40), child: LoadingView())
                  else
                    LayoutBuilder(builder: (ctx, c) {
                      final cols = c.maxWidth >= 1000 ? 3 : c.maxWidth >= 660 ? 2 : 1;
                      return GridView.count(
                        crossAxisCount: cols,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.4,
                        children: _presets.map((p) => _PresetCard(
                          data: p,
                          loading: _applying == p['code'],
                          disabled: _applying != null,
                          starterTablesCountFn: t.starterTablesCount,
                          useThisLabel: t.useThis,
                          onApply: () => _apply(p['code'].toString()),
                        )).toList(),
                      );
                    }),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              t.alreadyConfiguredHint,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.go('/dashboard'),
                            child: Text(t.skipAndContinue),
                          ),
                        ],
                      ),
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

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.data,
    required this.loading,
    required this.disabled,
    required this.starterTablesCountFn,
    required this.useThisLabel,
    required this.onApply,
  });
  final Map<String, dynamic> data;
  final bool loading;
  final bool disabled;
  final String Function(int) starterTablesCountFn;
  final String useThisLabel;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final entities = (data['entities'] as List? ?? const []);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(iconFromName(data['icon'] as String?), color: cs.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(data['name'].toString(), style: Theme.of(context).textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(data['description']?.toString() ?? '', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: entities.take(6).map((e) {
                final m = e as Map<String, dynamic>;
                return Chip(label: Text(m['label'].toString()));
              }).toList(),
            ),
            const Spacer(),
            Row(
              children: [
                Text(starterTablesCountFn(entities.length), style: Theme.of(context).textTheme.bodySmall),
                const Spacer(),
                ElevatedButton(
                  onPressed: disabled ? null : onApply,
                  child: loading
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(useThisLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
