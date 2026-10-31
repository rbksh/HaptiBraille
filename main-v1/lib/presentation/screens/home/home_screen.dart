import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/braille_cell_view.dart';
import '../../../core/widgets/common.dart';
import '../../../domain/engine/braille_translator.dart';
import '../../providers/app_providers.dart';
import '../analytics/analytics_screen.dart';
import '../reader/reader_screen.dart';
import '../settings/settings_screen.dart';
import '../talk/talk_screen.dart';
import '../training/training_hub_screen.dart';
import '../training/training_session_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final stats = ref.watch(analyticsProvider);
    final attempts = ref.watch(attemptsProvider);
    final curriculum = ref.watch(curriculumProvider);
    final level = curriculum.currentLevel(attempts);
    final levelAccuracy = curriculum.recentAccuracy(level, attempts);

    void go(Widget page) => Navigator.of(context).push(fadeSlideRoute(page));

    final cards = [
      ActionCard(
        icon: Icons.chrome_reader_mode_outlined,
        title: 'Read',
        subtitle: 'Feel any text, paste or dictate',
        color: AppColors.read,
        onTap: () => go(const ReaderScreen()),
      ),
      ActionCard(
        icon: Icons.record_voice_over_outlined,
        title: 'Talk to me',
        subtitle: 'Someone speaks, you feel it',
        color: AppColors.talk,
        onTap: () => go(const TalkScreen()),
      ),
      ActionCard(
        icon: Icons.school_outlined,
        title: 'Train',
        subtitle: 'Three levels, step by step',
        color: AppColors.train,
        onTap: () => go(const TrainingHubScreen()),
      ),
      ActionCard(
        icon: Icons.insights_outlined,
        title: 'Progress',
        subtitle: 'Accuracy, speed, streaks',
        color: AppColors.progress,
        onTap: () => go(const AnalyticsScreen()),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            ExcludeSemantics(
              child: BrailleCellView(cell: BrailleTranslator.letters['h'], dotSize: 6),
            ),
            const SizedBox(width: 10),
            const Flexible(child: Text('HaptiBraille', overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            iconSize: 28,
            icon: const Icon(Icons.tune),
            onPressed: () => go(const SettingsScreen()),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            FadeSlideIn(
              child: Semantics(
                header: true,
                child: Text(_greeting(), style: text.displaySmall),
              ),
            ),
            const SizedBox(height: 4),
            FadeSlideIn(
              delay: const Duration(milliseconds: 60),
              child: Text(
                stats.currentStreak > 0
                    ? 'You are on a ${stats.currentStreak}-day streak. Keep it going!'
                    : 'A few minutes of practice a day is all it takes.',
                style: text.bodyLarge?.copyWith(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 24),
            FadeSlideIn(
              delay: const Duration(milliseconds: 120),
              child: _ContinueCard(
                levelNumber: level.number,
                levelTitle: level.title,
                accuracy: levelAccuracy,
                streak: stats.currentStreak,
                onTap: () => go(TrainingSessionScreen(level: level)),
              ),
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, c) {
                final columns = c.maxWidth > 560 ? 4 : 2;
                const gap = 14.0;
                final width = (c.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final (i, card) in cards.indexed)
                      SizedBox(
                        width: width,
                        child: FadeSlideIn(
                          delay: Duration(milliseconds: 180 + 70 * i),
                          child: card,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    required this.levelNumber,
    required this.levelTitle,
    required this.accuracy,
    required this.streak,
    required this.onTap,
  });

  final int levelNumber;
  final String levelTitle;
  final double? accuracy;
  final int streak;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final pct = accuracy == null ? null : (accuracy! * 100).round();
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2410), Color(0xFF15171B)],
        ),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.55), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('CONTINUE TRAINING',
                  style: text.labelMedium?.copyWith(color: AppColors.accent)),
              const Spacer(),
              if (streak > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('🔥 $streak day${streak == 1 ? '' : 's'}', style: text.labelMedium),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Level $levelNumber · $levelTitle', style: text.headlineSmall),
          const SizedBox(height: 6),
          Text(
            pct == null ? 'Not started yet' : 'Recent accuracy $pct% · 80% unlocks the next level',
            style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          if (accuracy != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: accuracy,
                minHeight: 8,
                color: AppColors.accent,
                backgroundColor: AppColors.surfaceHigh,
                semanticsLabel: 'Level accuracy',
              ),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text('Practice Level $levelNumber'),
          ),
        ],
      ),
    );
  }
}
