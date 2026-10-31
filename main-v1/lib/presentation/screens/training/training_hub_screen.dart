import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/braille_cell_view.dart';
import '../../../core/widgets/common.dart';
import '../../../domain/engine/braille_translator.dart';
import '../../../domain/entities/training.dart';
import '../../../domain/training/curriculum.dart';
import '../../providers/app_providers.dart';
import '../../providers/playback_controller.dart';
import 'training_session_screen.dart';

class TrainingHubScreen extends ConsumerStatefulWidget {
  const TrainingHubScreen({super.key});

  @override
  ConsumerState<TrainingHubScreen> createState() => _TrainingHubScreenState();
}

class _TrainingHubScreenState extends ConsumerState<TrainingHubScreen> {
  late final PlaybackController _playback;
  String? _exploring;

  @override
  void initState() {
    super.initState();
    _playback = ref.read(playbackProvider.notifier);
  }

  @override
  void dispose() {
    _playback.stop();
    super.dispose();
  }

  void _explore(String letter) {
    setState(() => _exploring = letter);
    _playback.playText(letter);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final attempts = ref.watch(attemptsProvider);
    final curriculum = ref.watch(curriculumProvider);
    final frame = ref.watch(playbackProvider.select((s) => s.frame));
    final current = curriculum.currentLevel(attempts);

    return Scaffold(
      appBar: AppBar(title: const Text('Train')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            FadeSlideIn(
              child: Text('Learn to read with touch', style: text.headlineMedium),
            ),
            const SizedBox(height: 8),
            FadeSlideIn(
              delay: const Duration(milliseconds: 60),
              child: Text(
                'Only about 1 in 10 blind and deafblind people can read vibrations today. '
                'Each level builds on the last — reach ${(Curriculum.unlockAccuracy * 100).round()}% '
                'accuracy to unlock the next one.',
                style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 20),
            for (final (i, level) in TrainingLevel.values.indexed)
              FadeSlideIn(
                delay: Duration(milliseconds: 120 + 80 * i),
                child: _LevelCard(
                  level: level,
                  unlocked: curriculum.isUnlocked(level, attempts),
                  mastered: curriculum.isMastered(level, attempts),
                  recommended: level == current,
                  accuracy: curriculum.recentAccuracy(level, attempts),
                  attempts: attempts.where((a) => a.level == level).length,
                  onStart: () => Navigator.of(context)
                      .push(fadeSlideRoute(TrainingSessionScreen(level: level))),
                ),
              ),
            const SectionTitle('Explore the alphabet'),
            Text(
              'Tap a letter to feel it and see its dots. No score — just practice.',
              style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Center(
              child: BrailleCellView(
                cell: frame.cell ??
                    (_exploring == null ? null : BrailleTranslator.letters[_exploring]),
                activeSlot: frame.activeSlot,
                anchorActive: frame.anchorActive,
                dotSize: 24,
                showNumbers: true,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final letter in Curriculum.alphabet.split(''))
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: Semantics(
                      button: true,
                      label: 'Feel letter $letter',
                      excludeSemantics: true,
                      child: Material(
                        color: letter == _exploring ? AppColors.accent : AppColors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: AppColors.outline, width: 1.5),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _explore(letter),
                          child: Center(
                            child: Text(
                              letter.toUpperCase(),
                              style: text.titleLarge?.copyWith(
                                color: letter == _exploring ? AppColors.onAccent : AppColors.text,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.level,
    required this.unlocked,
    required this.mastered,
    required this.recommended,
    required this.accuracy,
    required this.attempts,
    required this.onStart,
  });

  final TrainingLevel level;
  final bool unlocked;
  final bool mastered;
  final bool recommended;
  final double? accuracy;
  final int attempts;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final borderColor = recommended && unlocked ? AppColors.accent : AppColors.outline;
    final status = !unlocked
        ? 'Locked — reach ${(Curriculum.unlockAccuracy * 100).round()}% on Level ${level.number - 1}'
        : mastered
            ? 'Mastered'
            : accuracy == null
                ? 'Not started'
                : 'Recent accuracy ${(accuracy! * 100).round()}% · $attempts answers';

    return Opacity(
      opacity: unlocked ? 1 : 0.6,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderColor, width: recommended && unlocked ? 2 : 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: unlocked ? AppColors.train.withValues(alpha: 0.18) : AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: unlocked
                      ? Text('${level.number}',
                          style: text.titleLarge?.copyWith(color: AppColors.train))
                      : const Icon(Icons.lock_outline, color: AppColors.textMuted),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Level ${level.number} · ${level.title}', style: text.titleMedium),
                      Text(level.description,
                          style: text.bodySmall?.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                if (mastered) const Icon(Icons.verified, color: AppColors.success, semanticLabel: 'Mastered'),
              ],
            ),
            const SizedBox(height: 14),
            if (unlocked && accuracy != null) ...[
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: accuracy,
                      minHeight: 8,
                      color: mastered ? AppColors.success : AppColors.train,
                      backgroundColor: AppColors.surfaceHigh,
                      semanticsLabel: 'Recent accuracy',
                    ),
                  ),
                  // 80% target marker
                  Positioned.fill(
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: Curriculum.unlockAccuracy,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Container(width: 2, color: AppColors.text),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(status,
                      style: text.bodySmall?.copyWith(color: AppColors.textSecondary)),
                ),
                if (unlocked)
                  FilledButton(
                    onPressed: onStart,
                    style: FilledButton.styleFrom(minimumSize: const Size(110, 52)),
                    child: Text(attempts == 0 ? 'Start' : 'Practice'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
