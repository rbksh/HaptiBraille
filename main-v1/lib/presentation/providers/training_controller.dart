import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/engine/feedback_patterns.dart';
import '../../domain/entities/training.dart';
import '../../domain/training/curriculum.dart';
import 'app_providers.dart';
import 'haptic_providers.dart';
import 'playback_controller.dart';

enum TrainingPhase { idle, playing, answering, feedback, finished }

class TrainingSession {
  const TrainingSession({
    this.level = TrainingLevel.dots,
    this.phase = TrainingPhase.idle,
    this.trial,
    this.trialNumber = 0,
    this.correctCount = 0,
    this.replays = 0,
    this.lastResponse,
    this.lastCorrect,
    this.responseTimesMs = const [],
  });

  final TrainingLevel level;
  final TrainingPhase phase;
  final TrainingTrial? trial;

  /// 1-based number of the current trial.
  final int trialNumber;
  final int correctCount;
  final int replays;
  final String? lastResponse;
  final bool? lastCorrect;
  final List<int> responseTimesMs;

  int get total => Curriculum.sessionLength;
  bool get isLastTrial => trialNumber >= total;
  double get accuracy => trialNumber == 0 ? 0 : correctCount / trialNumber;

  TrainingSession copyWith({
    TrainingPhase? phase,
    TrainingTrial? trial,
    int? trialNumber,
    int? correctCount,
    int? replays,
    String? lastResponse,
    bool? lastCorrect,
    bool clearResult = false,
    List<int>? responseTimesMs,
  }) =>
      TrainingSession(
        level: level,
        phase: phase ?? this.phase,
        trial: trial ?? this.trial,
        trialNumber: trialNumber ?? this.trialNumber,
        correctCount: correctCount ?? this.correctCount,
        replays: replays ?? this.replays,
        lastResponse: clearResult ? null : lastResponse ?? this.lastResponse,
        lastCorrect: clearResult ? null : lastCorrect ?? this.lastCorrect,
        responseTimesMs: responseTimesMs ?? this.responseTimesMs,
      );
}

/// Runs one 10-trial session: play → answer → feedback → next.
class TrainingController extends AutoDisposeNotifier<TrainingSession> {
  DateTime? _answerStart;
  int _playbackMs = 0;

  @override
  TrainingSession build() => const TrainingSession();

  Future<void> start(TrainingLevel level) async {
    state = TrainingSession(level: level);
    await _nextTrial();
  }

  Future<void> _nextTrial() async {
    final trial = ref.read(curriculumProvider).nextTrial(
          state.level,
          ref.read(attemptsProvider),
          ref.read(randomProvider),
          avoid: state.trial?.answer,
        );
    state = state.copyWith(
      trial: trial,
      trialNumber: state.trialNumber + 1,
      replays: 0,
      clearResult: true,
    );
    _answerStart = null;
    await _play(trial);
  }

  Future<void> _play(TrainingTrial trial) async {
    state = state.copyWith(phase: TrainingPhase.playing);
    final playback = ref.read(playbackProvider.notifier);
    final sequence = trial.cell != null
        ? await playback.playCell(trial.cell!)
        : await playback.playText(trial.text!);
    _playbackMs = sequence.totalDurationMs;
    if (state.trial != trial || state.phase != TrainingPhase.playing) return;
    _answerStart ??= clock.now();
    state = state.copyWith(phase: TrainingPhase.answering);
  }

  Future<void> replay() async {
    final trial = state.trial;
    if (trial == null || state.phase == TrainingPhase.feedback) return;
    state = state.copyWith(replays: state.replays + 1);
    await _play(trial);
  }

  Future<void> submit(String response) async {
    final trial = state.trial;
    if (trial == null ||
        (state.phase != TrainingPhase.answering && state.phase != TrainingPhase.playing) ||
        response.trim().isEmpty) {
      return;
    }
    final playback = ref.read(playbackProvider.notifier);
    await playback.stop();

    final now = clock.now();
    final correct = ref.read(curriculumProvider).isCorrect(trial, response);
    final responseMs = _answerStart == null ? 0 : now.difference(_answerStart!).inMilliseconds;
    final profile = ref.read(hapticProfileProvider);

    state = state.copyWith(
      phase: TrainingPhase.feedback,
      lastResponse: response.trim(),
      lastCorrect: correct,
      correctCount: state.correctCount + (correct ? 1 : 0),
      responseTimesMs: [...state.responseTimesMs, responseMs],
    );

    await ref.read(attemptsProvider.notifier).add(TrainingAttempt(
          timestamp: now,
          level: trial.level,
          target: trial.answer,
          response: response.trim(),
          correct: correct,
          responseMs: responseMs,
          playbackMs: _playbackMs,
          replays: state.replays,
          profileId: profile.id,
          dotDurationMs: profile.dotDuration.inMilliseconds,
          intraCharPauseMs: profile.intraCharPause.inMilliseconds,
          interCharPauseMs: profile.interCharPause.inMilliseconds,
        ));

    await playback.playSequence(correct ? FeedbackPatterns.correct : FeedbackPatterns.incorrect);
  }

  Future<void> next() async {
    if (state.phase != TrainingPhase.feedback) return;
    if (state.isLastTrial) {
      state = state.copyWith(phase: TrainingPhase.finished);
      return;
    }
    await _nextTrial();
  }

  Future<void> stop() => ref.read(playbackProvider.notifier).stop();
}

final trainingProvider =
    AutoDisposeNotifierProvider<TrainingController, TrainingSession>(TrainingController.new);
