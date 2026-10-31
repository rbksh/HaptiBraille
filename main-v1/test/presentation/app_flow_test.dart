import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haptibraille/app.dart';
import 'package:haptibraille/data/repositories/in_memory_repositories.dart';
import 'package:haptibraille/domain/entities/haptic_sequence.dart';
import 'package:haptibraille/domain/entities/training.dart';
import 'package:haptibraille/domain/services/i_haptic_player.dart';
import 'package:haptibraille/domain/services/i_speech_input.dart';
import 'package:haptibraille/presentation/providers/app_providers.dart';
import 'package:haptibraille/presentation/providers/haptic_providers.dart';
import 'package:haptibraille/presentation/providers/training_controller.dart';
import 'package:haptibraille/presentation/screens/analytics/analytics_screen.dart';
import 'package:haptibraille/presentation/screens/home/home_screen.dart';
import 'package:haptibraille/presentation/screens/welcome/welcome_screen.dart';
import 'package:haptibraille/presentation/screens/training/training_session_screen.dart';

class FakePlayer implements IHapticPlayer {
  final played = <HapticSequence>[];

  @override
  Future<HapticCapabilities> capabilities() async =>
      const HapticCapabilities(hasVibrator: true, hasAmplitudeControl: true);

  @override
  Future<void> play(HapticSequence sequence) async => played.add(sequence);

  @override
  Future<void> stop() async {}
}

class FakeSpeech implements ISpeechInput {
  @override
  bool get isListening => false;

  @override
  Future<bool> initialize() async => false;

  @override
  Future<void> listen({
    required void Function(String words, bool isFinal) onResult,
    required void Function() onDone,
    bool dictation = false,
  }) async =>
      onDone();

  @override
  Future<void> stop() async {}
}

Future<(ProviderContainer, FakePlayer, InMemoryAnalyticsRepository)> pumpApp(
  WidgetTester tester, {
  Widget? home,
  bool onboarded = true,
  List<TrainingAttempt> attempts = const [],
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);

  final player = FakePlayer();
  final analytics = InMemoryAnalyticsRepository(attempts);
  final container = ProviderContainer(overrides: [
    settingsRepositoryProvider.overrideWithValue(InMemorySettingsRepository(onboarded: onboarded)),
    analyticsRepositoryProvider.overrideWithValue(analytics),
    hapticPlayerProvider.overrideWithValue(player),
    speechInputProvider.overrideWithValue(FakeSpeech()),
  ]);
  addTearDown(container.dispose);

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: home == null ? const HaptiBrailleApp() : MaterialApp(home: home),
  ));
  await tester.pump(const Duration(seconds: 1));
  return (container, player, analytics);
}

void main() {
  testWidgets('first launch shows the welcome screen, then home', (tester) async {
    await pumpApp(tester, onboarded: false);
    expect(find.text('HaptiBraille'), findsWidgets);
    await tester.scrollUntilVisible(find.text('I already read Braille'), 300);
    expect(find.text('Start learning'), findsOneWidget);

    await tester.tap(find.text('I already read Braille'));
    // Onboarding is saved first, then the route transition runs.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(WelcomeScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Good morning').evaluate().length +
        find.text('Good afternoon').evaluate().length +
        find.text('Good evening').evaluate().length, 1);
    await tester.scrollUntilVisible(find.text('Progress'), 300);
    expect(find.text('Talk to me'), findsOneWidget);
    expect(find.text('Progress'), findsOneWidget);
  });

  testWidgets('a Level 1 trial plays a dot, records the answer and gives feedback',
      (tester) async {
    final (container, player, analytics) =
        await pumpApp(tester, home: const TrainingSessionScreen(level: TrainingLevel.dots));

    // Let the trial's vibration finish.
    await tester.pump(const Duration(seconds: 3));
    final session = container.read(trainingProvider);
    expect(session.phase, TrainingPhase.answering);
    expect(player.played, isNotEmpty);

    final answer = session.trial!.answer;
    await tester.tap(find.bySemanticsLabel(RegExp('^Dot $answer,')));
    await tester.pump(const Duration(seconds: 1));

    expect(container.read(trainingProvider).lastCorrect, isTrue);
    expect(analytics.loadAttempts().single.target, answer);
    expect(find.text('Correct!'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('progress screen renders stats and charts from attempts', (tester) async {
    final now = DateTime.now();
    TrainingAttempt a(String t, bool ok, int daysAgo) => TrainingAttempt(
          timestamp: now.subtract(Duration(days: daysAgo)),
          level: TrainingLevel.letters,
          target: t,
          response: ok ? t : 'x',
          correct: ok,
          responseMs: 800,
          playbackMs: 1500,
          replays: 0,
          profileId: 'standard',
          dotDurationMs: 40,
          intraCharPauseMs: 100,
          interCharPauseMs: 300,
        );
    await pumpApp(tester, home: const AnalyticsScreen(), attempts: [
      a('a', true, 2), a('b', false, 2), a('a', true, 1), a('c', true, 0),
    ]);
    expect(find.text('Day streak'), findsOneWidget);
    expect(find.text('3'), findsWidgets); // 3-day streak
    expect(find.text('Accuracy by day'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Letter accuracy'), 300);
    expect(find.text('Letter accuracy'), findsOneWidget);
  });
}
