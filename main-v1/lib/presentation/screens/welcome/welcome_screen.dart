import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/braille_cell_view.dart';
import '../../../domain/engine/braille_translator.dart';
import '../../providers/app_providers.dart';
import '../home/home_screen.dart';
import '../training/training_hub_screen.dart';

/// First-launch landing screen.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  Future<void> _finish(BuildContext context, WidgetRef ref, {required bool train}) async {
    await ref.read(onboardedProvider.notifier).complete();
    if (!context.mounted) return;
    final nav = Navigator.of(context);
    nav.pushReplacement(fadeSlideRoute(const HomeScreen()));
    if (train) nav.push(fadeSlideRoute(const TrainingHubScreen()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          children: [
            const FadeSlideIn(child: Center(child: _SpellingCell(word: 'hapti'))),
            const SizedBox(height: 36),
            FadeSlideIn(
              delay: const Duration(milliseconds: 120),
              child: Semantics(
                header: true,
                child: Text('HaptiBraille', style: text.displayLarge, textAlign: TextAlign.center),
              ),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              delay: const Duration(milliseconds: 200),
              child: Text(
                'Read any text through gentle vibrations — privately, right in your hand.',
                style: text.bodyLarge?.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 28),
            FadeSlideIn(
              delay: const Duration(milliseconds: 280),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.6), width: 1.5),
                ),
                child: Row(
                  children: [
                    Text('1 in 10',
                        style: text.headlineMedium?.copyWith(color: AppColors.accent)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'blind and deafblind people can read vibrations today. '
                        'HaptiBraille teaches you, a few minutes a day.',
                        style: text.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            for (final (i, f) in _features.indexed)
              FadeSlideIn(
                delay: Duration(milliseconds: 360 + 80 * i),
                child: _Feature(icon: f.$1, title: f.$2, body: f.$3),
              ),
            const SizedBox(height: 28),
            FadeSlideIn(
              delay: const Duration(milliseconds: 620),
              child: FilledButton.icon(
                onPressed: () => _finish(context, ref, train: true),
                icon: const Icon(Icons.school_outlined),
                label: const Text('Start learning'),
              ),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              delay: const Duration(milliseconds: 680),
              child: OutlinedButton(
                onPressed: () => _finish(context, ref, train: false),
                child: const Text('I already read Braille'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _features = [
    (Icons.vibration, 'Feel every letter', 'Each Braille letter becomes a short rhythm of taps.'),
    (Icons.record_voice_over_outlined, 'Let anyone talk to you', 'People speak, and you feel their words.'),
    (Icons.insights_outlined, 'Watch yourself improve', 'Accuracy, speed and streaks, all in one place.'),
  ];
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.accent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium),
                Text(body, style: text.bodyMedium?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A cell that spells [word] letter by letter, lighting each raised dot in
/// playback order – a silent demo of how temporal Braille works.
class _SpellingCell extends StatefulWidget {
  const _SpellingCell({required this.word});

  final String word;

  @override
  State<_SpellingCell> createState() => _SpellingCellState();
}

class _SpellingCellState extends State<_SpellingCell> {
  static const _stepsPerLetter = 9;
  Timer? _timer;
  int _tick = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer?.cancel();
    if (!reduceMotion(context)) {
      _timer = Timer.periodic(const Duration(milliseconds: 160), (_) => setState(() => _tick++));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final letterIndex = (_tick ~/ _stepsPerLetter) % widget.word.length;
    final letter = widget.word[letterIndex];
    final cell = BrailleTranslator.letters[letter]!;
    final step = _tick % _stepsPerLetter;
    final raised = cell.raisedDots;
    final activeSlot = step < raised.length ? raised[step] - 1 : null;

    return ExcludeSemantics(
      child: Column(
        children: [
          BrailleCellView(cell: cell, activeSlot: activeSlot, dotSize: 26),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: motion(context, const Duration(milliseconds: 200)),
            child: Text(
              letter.toUpperCase(),
              key: ValueKey(letterIndex),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }
}
