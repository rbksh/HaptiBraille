import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/speech/speech_to_text_input.dart';
import '../../domain/analytics/analytics_calculator.dart';
import '../../domain/entities/training.dart';
import '../../domain/repositories/repositories.dart';
import '../../domain/services/i_speech_input.dart';
import '../../domain/training/curriculum.dart';

/// Overridden in `main()` with Hive-backed implementations (and in tests with
/// in-memory ones).
final settingsRepositoryProvider = Provider<ISettingsRepository>(
  (ref) => throw UnimplementedError('settingsRepositoryProvider must be overridden'),
);

final analyticsRepositoryProvider = Provider<IAnalyticsRepository>(
  (ref) => throw UnimplementedError('analyticsRepositoryProvider must be overridden'),
);

final speechInputProvider = Provider<ISpeechInput>((ref) => SpeechToTextInput());

final curriculumProvider = Provider<Curriculum>((ref) => const Curriculum());

final randomProvider = Provider<Random>((ref) => Random());

class OnboardingNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(settingsRepositoryProvider).hasOnboarded;

  Future<void> complete() async {
    state = true;
    await ref.read(settingsRepositoryProvider).setOnboarded();
  }
}

final onboardedProvider = NotifierProvider<OnboardingNotifier, bool>(OnboardingNotifier.new);

class AttemptsNotifier extends Notifier<List<TrainingAttempt>> {
  @override
  List<TrainingAttempt> build() => ref.watch(analyticsRepositoryProvider).loadAttempts();

  Future<void> add(TrainingAttempt attempt) async {
    state = [...state, attempt];
    await ref.read(analyticsRepositoryProvider).addAttempt(attempt);
  }

  Future<void> clear() async {
    state = const [];
    await ref.read(analyticsRepositoryProvider).clear();
  }
}

/// Every training answer ever given, oldest first.
final attemptsProvider =
    NotifierProvider<AttemptsNotifier, List<TrainingAttempt>>(AttemptsNotifier.new);

final analyticsProvider = Provider<AnalyticsSnapshot>(
  (ref) => const AnalyticsCalculator().compute(ref.watch(attemptsProvider), clock.now()),
);
