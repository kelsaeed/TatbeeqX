import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_data_builder.dart';
import '../../../core/theme/theme_settings.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/local_file_upload_field.dart';
import '../../../shared/widgets/page_header.dart';
import '../../auth/application/auth_controller.dart';

class ThemeBuilderPage extends ConsumerStatefulWidget {
  const ThemeBuilderPage({super.key, required this.themeId});
  final int themeId;

  @override
  ConsumerState<ThemeBuilderPage> createState() => _ThemeBuilderPageState();
}

class _ThemeBuilderPageState extends ConsumerState<ThemeBuilderPage> {
  bool _loading = true;
  bool _saving = false;
  String _name = '';
  bool _isActive = false;
  ThemeSettings _settings = const ThemeSettings();

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(apiClientProvider).getJson('/themes/${widget.themeId}');
      final data = (res['data'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
      setState(() {
        _name = res['name']?.toString() ?? 'Theme';
        _isActive = res['isActive'] == true;
        _settings = ThemeSettings.fromJson(data);
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

  void _patch(Map<String, dynamic> change) {
    setState(() => _settings = _settings.copyWith(change));
  }

  Future<void> _save({bool activate = false}) async {
    setState(() => _saving = true);
    final t = AppLocalizations.of(context);
    try {
      await ref.read(apiClientProvider).putJson('/themes/${widget.themeId}', body: {
        'name': _name,
        'data': _settings.toJson(),
      });
      if (activate) {
        await ref.read(apiClientProvider).postJson('/themes/${widget.themeId}/activate');
      }
      if (_isActive || activate) {
        await ref.read(themeControllerProvider.notifier).loadActive();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(activate ? t.themeActivated : t.themeSavedMsg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.saveFailed(e.toString()))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final t = AppLocalizations.of(context);
    if (!auth.user!.isSuperAdmin) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(child: Text(t.themeBuilderRestricted)),
      );
    }

    if (_loading) return const LoadingView();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: t.themeBuilderTitle,
            subtitle: t.themeBuilderEditing(_name),
            actions: [
              OutlinedButton.icon(
                onPressed: () => context.go('/themes'),
                icon: const Icon(Icons.arrow_back),
                label: Text(t.back),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _saving ? null : () => _save(activate: false),
                icon: const Icon(Icons.save_outlined),
                label: Text(t.save),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _saving ? null : () => _save(activate: true),
                icon: const Icon(Icons.bolt),
                label: Text(t.saveAndActivate),
              ),
            ],
          ),
          LayoutBuilder(builder: (ctx, c) {
            final stacked = c.maxWidth < 1100;
            final editor = _Editor(
              name: _name,
              onName: (v) => setState(() => _name = v),
              settings: _settings,
              patch: _patch,
            );
            final preview = _PreviewCard(settings: _settings);
            if (stacked) {
              return Column(children: [editor, const SizedBox(height: 16), preview]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: editor),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: preview),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _Editor extends StatelessWidget {
  const _Editor({required this.name, required this.onName, required this.settings, required this.patch});
  final String name;
  final void Function(String) onName;
  final ThemeSettings settings;
  final void Function(Map<String, dynamic>) patch;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              initialValue: name,
              decoration: const InputDecoration(labelText: 'Theme name'),
              onChanged: onName,
            ),
            const SizedBox(height: 18),
            _Section(
              title: 'Identity',
              children: [
                _TextRow(label: 'App name', value: settings.appName, onChanged: (v) => patch({'appName': v})),
                LocalFileUploadField(
                  label: 'Logo',
                  value: settings.logoUrl,
                  onUploaded: (v) => patch({'logoUrl': v.isEmpty ? null : v}),
                ),
                LocalFileUploadField(
                  label: 'Favicon / app icon',
                  value: settings.faviconUrl,
                  onUploaded: (v) => patch({'faviconUrl': v.isEmpty ? null : v}),
                ),
                LocalFileUploadField(
                  label: 'Background image',
                  value: settings.backgroundImageUrl,
                  onUploaded: (v) => patch({'backgroundImageUrl': v.isEmpty ? null : v}),
                ),
              ],
            ),
            _Section(
              title: 'Mode & layout',
              children: [
                _DropdownRow<String>(
                  label: 'Mode',
                  value: settings.mode,
                  items: const ['light', 'dark'],
                  onChanged: (v) => patch({'mode': v}),
                ),
                _DropdownRow<String>(
                  label: 'Login style',
                  value: settings.loginStyle,
                  items: const ['split', 'centered', 'minimal'],
                  onChanged: (v) => patch({'loginStyle': v}),
                ),
                _DropdownRow<String>(
                  label: 'Dashboard layout',
                  value: settings.dashboardLayout,
                  items: const ['cards', 'compact', 'spacious'],
                  onChanged: (v) => patch({'dashboardLayout': v}),
                ),
              ],
            ),
            _Section(
              title: 'Colors',
              children: [
                _ColorRow(label: 'Primary', value: settings.primary, onChanged: (v) => patch({'primary': v})),
                _ColorRow(label: 'Secondary', value: settings.secondary, onChanged: (v) => patch({'secondary': v})),
                _ColorRow(label: 'Accent', value: settings.accent, onChanged: (v) => patch({'accent': v})),
                _ColorRow(label: 'Background', value: settings.background, onChanged: (v) => patch({'background': v})),
                _ColorRow(label: 'Surface', value: settings.surface, onChanged: (v) => patch({'surface': v})),
                _ColorRow(label: 'Sidebar', value: settings.sidebar, onChanged: (v) => patch({'sidebar': v})),
                _ColorRow(label: 'Sidebar text', value: settings.sidebarText, onChanged: (v) => patch({'sidebarText': v})),
                _ColorRow(label: 'Top bar', value: settings.topbar, onChanged: (v) => patch({'topbar': v})),
                _ColorRow(label: 'Top bar text', value: settings.topbarText, onChanged: (v) => patch({'topbarText': v})),
              ],
            ),
            _Section(
              title: 'Typography',
              children: [
                _TextRow(label: 'Font family', value: settings.fontFamily, onChanged: (v) => patch({'fontFamily': v})),
                _SliderRow(
                  label: 'Base font size',
                  value: settings.fontSizeBase.toDouble(),
                  min: 11,
                  max: 18,
                  onChanged: (v) => patch({'fontSizeBase': v.round()}),
                ),
              ],
            ),
            _Section(
              title: 'Shape',
              children: [
                _SliderRow(label: 'Button radius', value: settings.buttonRadius.toDouble(), min: 0, max: 24, onChanged: (v) => patch({'buttonRadius': v.round()})),
                _SliderRow(label: 'Card radius', value: settings.cardRadius.toDouble(), min: 0, max: 28, onChanged: (v) => patch({'cardRadius': v.round()})),
                _SliderRow(label: 'Table radius', value: settings.tableRadius.toDouble(), min: 0, max: 24, onChanged: (v) => patch({'tableRadius': v.round()})),
              ],
            ),
            _Section(
              title: 'Effects',
              children: [
                SwitchListTile(
                  title: const Text('Shadows'),
                  contentPadding: EdgeInsets.zero,
                  value: settings.shadows,
                  onChanged: (v) => patch({'shadows': v}),
                ),
                SwitchListTile(
                  title: const Text('Gradients'),
                  contentPadding: EdgeInsets.zero,
                  value: settings.gradients,
                  onChanged: (v) => patch({'gradients': v}),
                ),
                _ColorRow(label: 'Gradient from', value: settings.gradientFrom, onChanged: (v) => patch({'gradientFrom': v})),
                _ColorRow(label: 'Gradient to', value: settings.gradientTo, onChanged: (v) => patch({'gradientTo': v})),
                _DropdownRow<String>(
                  label: 'Gradient direction',
                  value: settings.gradientDirection,
                  items: const ['topLeftToBottomRight', 'leftToRight', 'topToBottom', 'bottomLeftToTopRight'],
                  onChanged: (v) => patch({'gradientDirection': v}),
                ),
              ],
            ),
            _Section(
              title: 'Transparency & overlay',
              children: [
                _SliderRow(label: 'Surface opacity', value: settings.surfaceOpacity.toDouble(), min: 0.3, max: 1.0, divisions: 14, onChanged: (v) => patch({'surfaceOpacity': v})),
                _SliderRow(label: 'Card opacity', value: settings.cardOpacity.toDouble(), min: 0.3, max: 1.0, divisions: 14, onChanged: (v) => patch({'cardOpacity': v})),
                _SliderRow(label: 'Sidebar opacity', value: settings.sidebarOpacity.toDouble(), min: 0.3, max: 1.0, divisions: 14, onChanged: (v) => patch({'sidebarOpacity': v})),
                _SliderRow(label: 'Top bar opacity', value: settings.topbarOpacity.toDouble(), min: 0.3, max: 1.0, divisions: 14, onChanged: (v) => patch({'topbarOpacity': v})),
                _SliderRow(label: 'Background opacity', value: settings.backgroundOpacity.toDouble(), min: 0.0, max: 1.0, divisions: 20, onChanged: (v) => patch({'backgroundOpacity': v})),
                _SliderRow(label: 'Background blur (px)', value: settings.backgroundBlur.toDouble(), min: 0, max: 30, divisions: 30, onChanged: (v) => patch({'backgroundBlur': v.round()})),
                _ColorRow(label: 'Background overlay color', value: settings.backgroundOverlayColor, onChanged: (v) => patch({'backgroundOverlayColor': v})),
                _SliderRow(label: 'Background overlay opacity', value: settings.backgroundOverlayOpacity.toDouble(), min: 0.0, max: 0.9, divisions: 18, onChanged: (v) => patch({'backgroundOverlayOpacity': v})),
              ],
            ),
            _Section(
              title: 'Glass effect',
              children: [
                SwitchListTile(
                  title: const Text('Enable frosted glass on cards/sidebar'),
                  contentPadding: EdgeInsets.zero,
                  value: settings.enableGlass,
                  onChanged: (v) => patch({'enableGlass': v}),
                ),
                _SliderRow(label: 'Glass blur (px)', value: settings.glassBlur.toDouble(), min: 0, max: 40, divisions: 40, onChanged: (v) => patch({'glassBlur': v.round()})),
                _ColorRow(label: 'Glass tint', value: settings.glassTint, onChanged: (v) => patch({'glassTint': v})),
                _SliderRow(label: 'Glass tint opacity', value: settings.glassTintOpacity.toDouble(), min: 0.0, max: 1.0, divisions: 20, onChanged: (v) => patch({'glassTintOpacity': v})),
              ],
            ),
            _Section(
              title: 'Login screen',
              children: [
                _ColorRow(label: 'Login overlay color', value: settings.loginOverlayColor, onChanged: (v) => patch({'loginOverlayColor': v})),
                _SliderRow(label: 'Login overlay opacity', value: settings.loginOverlayOpacity.toDouble(), min: 0.0, max: 0.9, divisions: 18, onChanged: (v) => patch({'loginOverlayOpacity': v})),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _TextRow extends StatelessWidget {
  const _TextRow({required this.label, required this.value, required this.onChanged});
  final String label;
  final String value;
  final void Function(String) onChanged;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        onChanged: onChanged,
      ),
    );
  }
}

class _DropdownRow<T> extends StatelessWidget {
  const _DropdownRow({required this.label, required this.value, required this.items, required this.onChanged});
  final String label;
  final T value;
  final List<T> items;
  final void Function(T) onChanged;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: items.map((e) => DropdownMenuItem<T>(value: e, child: Text(e.toString()))).toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
  });
  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final void Function(double) onChanged;
  @override
  Widget build(BuildContext context) {
    final fractional = (max - min) <= 1.0;
    final int effectiveDivisions = divisions ?? (max - min).round().clamp(1, 1000);
    final String displayValue = fractional ? value.toStringAsFixed(2) : value.round().toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 180, child: Text(label)),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: effectiveDivisions,
              label: displayValue,
              onChanged: onChanged,
            ),
          ),
          SizedBox(width: 48, child: Text(displayValue, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _ColorRow extends StatefulWidget {
  const _ColorRow({required this.label, required this.value, required this.onChanged});
  final String label;
  final String value;
  final void Function(String) onChanged;

  @override
  State<_ColorRow> createState() => _ColorRowState();
}

class _ColorRowState extends State<_ColorRow> {
  late TextEditingController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }
  @override
  void didUpdateWidget(covariant _ColorRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _ctrl.text != widget.value) {
      _ctrl.text = widget.value;
    }
  }
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(widget.label)),
          Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: hexToColor(widget.value),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: _ctrl,
              decoration: const InputDecoration(hintText: '#RRGGBB'),
              onChanged: (v) {
                if (RegExp(r'^#?[0-9A-Fa-f]{6}$').hasMatch(v.trim())) {
                  widget.onChanged(v.trim().startsWith('#') ? v.trim() : '#${v.trim()}');
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.settings});
  final ThemeSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeBuilder.build(settings);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Live preview', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 480,
                color: theme.scaffoldBackgroundColor,
                child: Theme(
                  data: theme,
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        color: hexToColor(settings.sidebar),
                        child: Column(
                          children: [
                            const SizedBox(height: 16),
                            Icon(Icons.account_balance_wallet, color: hexToColor(settings.sidebarText)),
                            const SizedBox(height: 24),
                            for (var i = 0; i < 4; i++) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Icon(
                                  [Icons.dashboard, Icons.business, Icons.people, Icons.settings][i],
                                  color: hexToColor(settings.sidebarText).withValues(alpha: 0.7),
                                  size: 18,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Container(
                              height: 44,
                              color: hexToColor(settings.topbar),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              alignment: Alignment.centerLeft,
                              child: Text(
                                settings.appName,
                                style: TextStyle(color: hexToColor(settings.topbarText), fontWeight: FontWeight.w700),
                              ),
                            ),
                            Divider(height: 1, color: theme.colorScheme.outline),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Sample card', style: theme.textTheme.titleMedium),
                                            const SizedBox(height: 6),
                                            Text('Quick description text', style: theme.textTheme.bodySmall),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        ElevatedButton(onPressed: () {}, child: const Text('Primary')),
                                        const SizedBox(width: 8),
                                        OutlinedButton(onPressed: () {}, child: const Text('Secondary')),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      decoration: const InputDecoration(labelText: 'Sample input'),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      children: const [
                                        Chip(label: Text('Tag A')),
                                        Chip(label: Text('Tag B')),
                                        Chip(label: Text('Tag C')),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
