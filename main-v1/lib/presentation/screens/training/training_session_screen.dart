import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/braille_cell_view.dart';
import '../../../core/widgets/common.dart';
import '../../../domain/engine/braille_translator.dart';
import '../../../domain/entities/braille_cell.dart';
import '../../../domain/entities/training.dart';
import '../../providers/app_providers.dart';
import '../../providers/playback_controller.dart';
import '../../providers/training_controller.dart';

/// One 10-question session: feel → answer → feedback.
class TrainingSessionScreen extends ConsumerStatefulWidget {
  const TrainingSessionScreen({super.key, required this.level});

  final TrainingLevel level;

  @override
  ConsumerState<TrainingSessionScreen> createState() => _TrainingSessionScreenState();
}

class _TrainingSessionScreenState extends ConsumerState<TrainingSessionScreen> {
  final _answer = TextEditingController();
  final _focus = FocusNode();
  late final TrainingController _training;
  late final PlaybackController _playback;
  bool _listening = false;
  bool _wasMastered = false;

  @override
  void initState() {
    super.initState();
    _training = ref.read(trainingProvider.notifier);
    _playback = ref.read(playbackProvider.notifier);
    _wasMastered = ref.read(curriculumProvider).isMastered(widget.level, ref.read(attemptsProvider));
    WidgetsBinding.instance.addPostFrameCallback((_) => _training.start(widget.level));
  }

  @override
  void dispose() {
    _playback.stop();
    _answer.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit([String? value]) async {
    final response = value ?? _answer.text;
    if (response.trim().isEmpty) return;
    await _training.submit(response);
  }

  Future<void> _next() async {
    _answer.clear();
    await _training.next();
    if (mounted && widget.level != TrainingLevel.dots) _focus.requestFocus();
  }

  Future<void> _speak() async {
    final speech = ref.read(speechInputProvider);
    if (_listening) {
      await speech.stop();
      return;
    }
    if (!await speech.initialize()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition is unavailable.')),
      );
      return;
    }
    setState(() => _listening = true);
    await speech.listen(
      onResult: (words, isFinal) {
        if (!mounted) return;
        _answer.text = words;
        if (isFinal && words.trim().isNotEmpty) _submit(words);
      },
      onDone: () {
        if (mounted) setState(() => _listening = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(trainingProvider);
    final frame = ref.watch(playbackProvider.select((s) => s.frame));
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text('Level ${widget.level.number} · ${widget.level.title}')),
      body: SafeArea(
        child: session.phase == TrainingPhase.finished
            ? _Summary(
                session: session,
                justMastered: !_wasMastered &&
                    ref.watch(curriculumProvider).isMastered(widget.level, ref.watch(attemptsProvider)),
                onAgain: () {
                  _wasMastered = ref.read(curriculumProvider)
                      .isMastered(widget.level, ref.read(attemptsProvider));
                  _training.start(widget.level);
                },
                onDone: () => Navigator.of(context).pop(),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Question ${session.trialNumber} of ${session.total}',
                            style: text.titleMedium),
                      ),
                      const SizedBox(width: 12),
                      Text('${session.correctCount} correct',
                          style: text.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: session.trialNumber / session.total),
                      duration: motion(context, const Duration(milliseconds: 400)),
                      builder: (_, v, _) => LinearProgressIndicator(
                        value: v,
                        minHeight: 8,
                        color: AppColors.train,
                        backgroundColor: AppColors.surfaceHigh,
                        semanticsLabel: 'Session progress',
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Center(
                    child: session.phase == TrainingPhase.feedback
                        ? _Reveal(trial: session.trial!)
                        : _PulseIndicator(
                            active: frame.activeSlot != null || frame.anchorActive,
                            soft: frame.anchorActive,
                          ),
                  ),
                  const SizedBox(height: 20),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _prompt(session),
                      textAlign: TextAlign.center,
                      style: text.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (session.phase != TrainingPhase.feedback)
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: session.phase == TrainingPhase.answering ? _training.replay : null,
                        icon: const Icon(Icons.replay),
                        label: const Text('Feel again'),
                      ),
                    ),
                  const SizedBox(height: 20),
                  if (session.phase == TrainingPhase.feedback)
                    _Feedback(session: session, onNext: _next)
                  else if (widget.level == TrainingLevel.dots)
                    DotPicker(onSelected: (d) => _submit('$d'))
                  else
                    _TextAnswer(
                      controller: _answer,
                      focusNode: _focus,
                      listening: _listening,
                      hint: widget.level == TrainingLevel.letters ? 'Letter' : 'Word',
                      onSubmit: _submit,
                      onSpeak: _speak,
                    ),
                ],
              ),
      ),
    );
  }

  String _prompt(TrainingSession s) => switch (s.phase) {
        TrainingPhase.idle || TrainingPhase.playing => 'Feel the vibration…',
        TrainingPhase.answering => switch (widget.level) {
            TrainingLevel.dots => 'Which dot was it?',
            TrainingLevel.letters => 'Which letter was it?',
            TrainingLevel.words => 'Which word was it?',
          },
        TrainingPhase.feedback => s.lastCorrect == true ? 'Correct!' : 'Not quite',
        TrainingPhase.finished => '',
      };
}

/// Flashes with every pulse, without revealing which dot it was.
class _PulseIndicator extends StatelessWidget {
  const _PulseIndicator({required this.active, required this.soft});

  final bool active;
  final bool soft;

  @override
  Widget build(BuildContext context) {
    final size = active ? (soft ? 120.0 : 150.0) : 110.0;
    return ExcludeSemantics(
      child: SizedBox(
        width: 170,
        height: 170,
        child: Center(
          child: AnimatedContainer(
            duration: motion(context, const Duration(milliseconds: 90)),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? AppColors.train.withValues(alpha: soft ? 0.35 : 0.9)
                  : AppColors.surface,
              border: Border.all(color: AppColors.train, width: 3),
            ),
            child: const Icon(Icons.vibration, size: 48, color: AppColors.text),
          ),
        ),
      ),
    );
  }
}

/// After answering, show the actual cells with their letters.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.trial});

  final TrainingTrial trial;

  @override
  Widget build(BuildContext context) {
    final cells = <(BrailleCell, String)>[
      if (trial.cell != null)
        (trial.cell!, 'dot ${trial.answer}')
      else
        for (final ch in trial.text!.split(''))
          if (BrailleTranslator.letters[ch] case final c?) (c, ch.toUpperCase()),
    ];
    return FadeSlideIn(
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: [
          for (final (cell, label) in cells)
            Column(
              children: [
                BrailleCellView(cell: cell, dotSize: cells.length > 1 ? 18 : 26, showNumbers: true),
                const SizedBox(height: 6),
                Text(label, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
        ],
      ),
    );
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback({required this.session, required this.onNext});

  final TrainingSession session;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final correct = session.lastCorrect == true;
    final answer = session.trial!.answer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NoticeBox(
          correct
              ? 'Well done — it was “$answer”.'
              : 'It was “$answer”. You answered “${session.lastResponse}”.',
          color: correct ? AppColors.success : AppColors.error,
          icon: correct ? Icons.check_circle_outline : Icons.highlight_off,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          autofocus: true,
          onPressed: onNext,
          icon: Icon(session.isLastTrial ? Icons.flag_outlined : Icons.arrow_forward),
          label: Text(session.isLastTrial ? 'See results' : 'Next'),
        ),
      ],
    );
  }
}

class _TextAnswer extends StatelessWidget {
  const _TextAnswer({
    required this.controller,
    required this.focusNode,
    required this.listening,
    required this.hint,
    required this.onSubmit,
    required this.onSpeak,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool listening;
  final String hint;
  final ValueChanged<String> onSubmit;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: false,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
                decoration: InputDecoration(labelText: 'Your answer', hintText: hint),
                onSubmitted: onSubmit,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 68,
              height: 68,
              child: IconButton.filled(
                tooltip: listening ? 'Stop listening' : 'Say your answer',
                style: IconButton.styleFrom(
                  backgroundColor: listening ? AppColors.error : AppColors.talk,
                  foregroundColor: AppColors.onAccent,
                ),
                iconSize: 32,
                icon: Icon(listening ? Icons.stop_rounded : Icons.mic),
                onPressed: onSpeak,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: () => onSubmit(controller.text),
          child: const Text('Check answer'),
        ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.session,
    required this.justMastered,
    required this.onAgain,
    required this.onDone,
  });

  final TrainingSession session;
  final bool justMastered;
  final VoidCallback onAgain;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final pct = (session.accuracy * 100).round();
    final times = session.responseTimesMs;
    final avgSec = times.isEmpty ? 0 : times.reduce((a, b) => a + b) / times.length / 1000;
    final message = pct >= 80
        ? 'Excellent work!'
        : pct >= 50
            ? 'Good progress — keep practising.'
            : 'Every session trains your touch. Try a slower speed in Settings.';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        FadeSlideIn(
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: session.accuracy),
              duration: motion(context, const Duration(milliseconds: 900)),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => SizedBox(
                width: 180,
                height: 180,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: v,
                      strokeWidth: 12,
                      color: pct >= 80 ? AppColors.success : AppColors.train,
                      backgroundColor: AppColors.surfaceHigh,
                    ),
                    Center(
                      child: Text('${(v * 100).round()}%', style: text.displaySmall),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Semantics(
          liveRegion: true,
          child: Text(
            '${session.correctCount} of ${session.total} correct. $message',
            textAlign: TextAlign.center,
            style: text.titleLarge,
          ),
        ),
        if (justMastered && session.level.next != null)
          FadeSlideIn(
            delay: const Duration(milliseconds: 300),
            child: NoticeBox(
              'Level ${session.level.next!.number} · ${session.level.next!.title} is now unlocked!',
              color: AppColors.success,
              icon: Icons.lock_open,
            ),
          ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Accuracy',
                value: '$pct%',
                icon: Icons.track_changes,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                label: 'Avg answer time',
                value: '${avgSec.toStringAsFixed(1)} s',
                icon: Icons.timer_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onAgain,
          icon: const Icon(Icons.replay),
          label: const Text('Practice again'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onDone, child: const Text('Done')),
      ],
    );
  }
}
