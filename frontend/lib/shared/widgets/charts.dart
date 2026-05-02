import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';

class BarChartData {
  BarChartData({required this.label, required this.value});
  final String label;
  final double value;
}

class SimpleBarChart extends StatelessWidget {
  const SimpleBarChart({super.key, required this.bars, this.height = 200, this.color});

  final List<BarChartData> bars;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.primary;
    final maxVal = bars.fold<double>(0, (a, b) => b.value > a ? b.value : a);
    final safeMax = maxVal == 0 ? 1.0 : maxVal;

    return SizedBox(
      height: height,
      child: LayoutBuilder(builder: (ctx, constraints) {
        final width = constraints.maxWidth;
        const gap = 6.0;
        final barWidth = bars.isEmpty ? 0.0 : (width - gap * (bars.length - 1)) / bars.length;
        return Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < bars.length; i++) ...[
                    if (i > 0) SizedBox(width: gap),
                    Tooltip(
                      message: '${bars[i].label}: ${bars[i].value.toStringAsFixed(0)}',
                      child: Container(
                        width: barWidth,
                        height: (height - 28) * (bars[i].value / safeMax).clamp(0.0, 1.0),
                        decoration: BoxDecoration(
                          color: c.withValues(alpha: 0.85),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 18,
              child: Row(
                children: [
                  for (var i = 0; i < bars.length; i++) ...[
                    if (i > 0) SizedBox(width: gap),
                    SizedBox(
                      width: barWidth,
                      child: Text(
                        bars[i].label,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}

class HorizontalBarList extends StatelessWidget {
  const HorizontalBarList({super.key, required this.bars, this.color});

  final List<BarChartData> bars;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.primary;
    final maxVal = bars.fold<double>(0, (a, b) => b.value > a ? b.value : a);
    final safeMax = maxVal == 0 ? 1.0 : maxVal;
    if (bars.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(AppLocalizations.of(context).noData),
      );
    }
    return Column(
      children: [
        for (final b in bars)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(width: 110, child: Text(b.label, overflow: TextOverflow.ellipsis)),
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 14,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: (b.value / safeMax).clamp(0.0, 1.0),
                        child: Container(
                          height: 14,
                          decoration: BoxDecoration(
                            color: c,
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(width: 40, child: Text(b.value.toStringAsFixed(0), textAlign: TextAlign.right)),
              ],
            ),
          ),
      ],
    );
  }
}
