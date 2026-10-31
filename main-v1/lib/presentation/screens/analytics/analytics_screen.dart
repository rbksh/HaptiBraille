import 'dart:math';

import 'package:clock/clock.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../domain/analytics/analytics_calculator.dart';
import '../../../domain/entities/training.dart';
import '../../providers/app_providers.dart';
import '../training/training_hub_screen.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  bool _showTable = false;

  Future<void> _export() async {
    final json = const AnalyticsCalculator().exportJson(ref.read(attemptsProvider), clock.now());
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Progress data copied as JSON.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(analyticsProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your progress'),
        actions: [
          if (!s.isEmpty)
            IconButton(
              tooltip: 'Copy data as JSON',
              icon: const Icon(Icons.ios_share),
              onPressed: _export,
            ),
        ],
      ),
      body: SafeArea(
        child: s.isEmpty
            ? _EmptyState(onTrain: () => Navigator.of(context)
                .pushReplacement(fadeSlideRoute(const TrainingHubScreen())))
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  FadeSlideIn(child: _Tiles(s: s)),
                  const SectionTitle('Accuracy by day'),
                  _ChartCard(
                    summary: _trendSummary('Accuracy', s.days.map((d) => d.accuracy * 100), '%'),
                    child: _TrendChart(
                      days: _lastDays(s.days),
                      value: (d) => d.accuracy * 100,
                      maxY: 100,
                      format: (v) => '${v.round()}%',
                    ),
                  ),
                  const SectionTitle('Reading speed'),
                  if (s.days.any((d) => d.wpm != null))
                    _ChartCard(
                      summary: _trendSummary(
                          'Reading speed', s.days.map((d) => d.wpm).nonNulls, ' words per minute'),
                      caption: 'Words per minute read correctly (5 letters = 1 word).',
                      child: _TrendChart(
                        days: _lastDays(s.days).where((d) => d.wpm != null).toList(),
                        value: (d) => d.wpm!,
                        maxY: max(5, (s.days.map((d) => d.wpm ?? 0).reduce(max) * 1.25).ceilToDouble()),
                        format: (v) => '${v.toStringAsFixed(1)} wpm',
                      ),
                    )
                  else
                    Text('Practise Level 2 or 3 to measure your reading speed.',
                        style: text.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                  if (s.letters.isNotEmpty) ...[
                    const SectionTitle('Letter accuracy'),
                    _ChartCard(
                      summary: s.focusLetters.isEmpty
                          ? 'Letter accuracy chart. No weak letters right now.'
                          : 'Letter accuracy chart. Letters to focus on: '
                              '${s.focusLetters.map((l) => l.item).join(', ')}.',
                      child: _LetterChart(letters: s.letters),
                    ),
                    if (s.focusLetters.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('Focus on these letters', style: text.titleMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final l in s.focusLetters.take(6))
                            Chip(
                              backgroundColor: AppColors.surfaceHigh,
                              side: const BorderSide(color: AppColors.outline),
                              label: Text('${l.item.toUpperCase()}  ${(l.accuracy * 100).round()}%',
                                  style: text.labelLarge),
                            ),
                        ],
                      ),
                    ],
                  ],
                  const SectionTitle('By level'),
                  for (final level in TrainingLevel.values)
                    _LevelRow(level: level, accuracy: s.levelAccuracy[level]),
                  SectionTitle(
                    'Daily log',
                    trailing: TextButton(
                      onPressed: () => setState(() => _showTable = !_showTable),
                      child: Text(_showTable ? 'Hide table' : 'Show table'),
                    ),
                  ),
                  if (_showTable) _DailyTable(days: s.days.reversed.toList()),
                ],
              ),
      ),
    );
  }

  static List<DailyStat> _lastDays(List<DailyStat> days) =>
      days.length <= 14 ? days : days.sublist(days.length - 14);

  static String _trendSummary(String name, Iterable<double> values, String unit) {
    final list = values.toList();
    if (list.isEmpty) return '$name chart, no data yet.';
    final first = list.first.toStringAsFixed(0);
    final last = list.last.toStringAsFixed(0);
    return '$name chart over ${list.length} days. Started at $first$unit, latest $last$unit.';
  }
}

class _Tiles extends StatelessWidget {
  const _Tiles({required this.s});

  final AnalyticsSnapshot s;

  @override
  Widget build(BuildContext context) {
    final minutes = (s.totalPracticeMs / 60000).round();
    final tiles = [
      StatTile(
        label: 'Day streak',
        value: '${s.currentStreak}',
        icon: Icons.local_fire_department_outlined,
        caption: 'Best ${s.bestStreak}',
      ),
      StatTile(
        label: 'Accuracy',
        value: '${(s.accuracy * 100).round()}%',
        icon: Icons.track_changes,
        caption: '${s.totalCorrect} of ${s.totalAttempts}',
      ),
      StatTile(
        label: 'Reading speed',
        value: s.recentWpm == null ? '–' : s.recentWpm!.toStringAsFixed(1),
        icon: Icons.speed,
        caption: 'words per minute',
      ),
      StatTile(
        label: 'Practice time',
        value: minutes < 1 ? '<1 min' : '$minutes min',
        icon: Icons.timer_outlined,
        caption: '${s.days.length} days',
      ),
    ];
    return LayoutBuilder(builder: (context, c) {
      final columns = c.maxWidth > 560 ? 4 : 2;
      const gap = 12.0;
      final w = (c.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final t in tiles) SizedBox(width: w, child: t)],
      );
    });
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.summary, required this.child, this.caption});

  final String summary;
  final String? caption;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
        label: summary,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 20, 16, 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.outline, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 200, child: ExcludeSemantics(child: child)),
              if (caption != null)
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 8),
                  child: Text(caption!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textMuted)),
                ),
            ],
          ),
        ),
      );
}

const _axisStyle = TextStyle(
  fontFamily: 'AtkinsonHyperlegible',
  fontSize: 13,
  color: AppColors.textMuted,
);

FlGridData _grid(double interval) => FlGridData(
      drawVerticalLine: false,
      horizontalInterval: interval,
      getDrawingHorizontalLine: (_) =>
          FlLine(color: AppColors.outline.withValues(alpha: 0.5), strokeWidth: 1),
    );

/// Single-series line with a crosshair tooltip (no legend: the title names it).
class _TrendChart extends StatelessWidget {
  const _TrendChart({
    required this.days,
    required this.value,
    required this.maxY,
    required this.format,
  });

  final List<DailyStat> days;
  final double Function(DailyStat) value;
  final double maxY;
  final String Function(double) format;

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (final (i, d) in days.indexed) FlSpot(i.toDouble(), value(d)),
    ];
    final labelEvery = max(1, (days.length / 5).ceil());

    return LineChart(
      duration: motion(context, const Duration(milliseconds: 400)),
      LineChartData(
        minX: 0,
        maxX: max(1, days.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        gridData: _grid(maxY / 4),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: maxY / 4,
              getTitlesWidget: (v, _) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(v.round().toString(), style: _axisStyle, textAlign: TextAlign.right),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (v, _) {
                final i = v.round();
                if (i < 0 || i >= days.length || i % labelEvery != 0) return const SizedBox.shrink();
                final d = days[i].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('${d.day}/${d.month}', style: _axisStyle),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          getTouchedSpotIndicator: (_, indexes) => [
            for (final _ in indexes)
              const TouchedSpotIndicatorData(
                FlLine(color: AppColors.textMuted, strokeWidth: 1, dashArray: [4, 4]),
                FlDotData(show: true),
              ),
          ],
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.surfaceHigh,
            tooltipBorder: const BorderSide(color: AppColors.outline),
            fitInsideHorizontally: true,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  '${days[s.x.round()].date.day}/${days[s.x.round()].date.month}\n',
                  const TextStyle(
                      fontFamily: 'AtkinsonHyperlegible', color: AppColors.textSecondary, fontSize: 13),
                  children: [
                    TextSpan(
                      text: format(s.y),
                      style: const TextStyle(
                          color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ],
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            color: AppColors.chart,
            barWidth: 2,
            isCurved: true,
            preventCurveOverShooting: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                radius: 4,
                color: AppColors.chart,
                strokeWidth: 2,
                strokeColor: AppColors.surface,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.chart.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _LetterChart extends StatelessWidget {
  const _LetterChart({required this.letters});

  final List<ItemStat> letters;

  @override
  Widget build(BuildContext context) {
    return BarChart(
      duration: motion(context, const Duration(milliseconds: 400)),
      BarChartData(
        minY: 0,
        maxY: 100,
        alignment: BarChartAlignment.spaceAround,
        gridData: _grid(25),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: 25,
              getTitlesWidget: (v, _) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text('${v.round()}', style: _axisStyle, textAlign: TextAlign.right),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              getTitlesWidget: (v, _) {
                final i = v.round();
                if (i < 0 || i >= letters.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(letters[i].item.toUpperCase(), style: _axisStyle),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.surfaceHigh,
            tooltipBorder: const BorderSide(color: AppColors.outline),
            fitInsideHorizontally: true,
            getTooltipItem: (group, _, rod, _) {
              final l = letters[group.x];
              return BarTooltipItem(
                '${l.item.toUpperCase()}\n',
                const TextStyle(
                    fontFamily: 'AtkinsonHyperlegible',
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 16),
                children: [
                  TextSpan(
                    text: '${rod.toY.round()}% · ${l.correct}/${l.total}',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontWeight: FontWeight.w400, fontSize: 14),
                  ),
                ],
              );
            },
          ),
        ),
        barGroups: [
          for (final (i, l) in letters.indexed)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: max(l.accuracy * 100, 1.5), // keep 0% visible as a stub
                  width: letters.length > 16 ? 8 : 14,
                  color: AppColors.chart,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({required this.level, required this.accuracy});

  final TrainingLevel level;
  final double? accuracy;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Level ${level.number} · ${level.title}', style: text.bodyLarge)),
              Text(accuracy == null ? 'Not started' : '${(accuracy! * 100).round()}%',
                  style: text.titleMedium),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: accuracy ?? 0,
              minHeight: 8,
              color: AppColors.chart,
              backgroundColor: AppColors.surfaceHigh,
              semanticsLabel: 'Level ${level.number} accuracy',
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyTable extends StatelessWidget {
  const _DailyTable({required this.days});

  final List<DailyStat> days;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    final head = Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingTextStyle: head,
        dataTextStyle: style,
        columnSpacing: 24,
        columns: const [
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Answers'), numeric: true),
          DataColumn(label: Text('Accuracy'), numeric: true),
          DataColumn(label: Text('WPM'), numeric: true),
        ],
        rows: [
          for (final d in days)
            DataRow(cells: [
              DataCell(Text('${d.date.day}/${d.date.month}/${d.date.year}')),
              DataCell(Text('${d.attempts}')),
              DataCell(Text('${(d.accuracy * 100).round()}%')),
              DataCell(Text(d.wpm == null ? '–' : d.wpm!.toStringAsFixed(1))),
            ]),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onTrain});

  final VoidCallback onTrain;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insights_outlined, size: 72, color: AppColors.progress),
            const SizedBox(height: 16),
            Text('No progress yet', style: text.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Finish a training session and your accuracy, reading speed and streak will appear here.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onTrain,
              icon: const Icon(Icons.school_outlined),
              label: const Text('Start training'),
            ),
          ],
        ),
      ),
    );
  }
}
