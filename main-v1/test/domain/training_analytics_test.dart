import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:haptibraille/data/datasources/platform/haptic_platform_codec.dart';
import 'package:haptibraille/domain/analytics/analytics_calculator.dart';
import 'package:haptibraille/domain/engine/braille_translator.dart';
import 'package:haptibraille/domain/engine/haptic_translation_engine.dart';
import 'package:haptibraille/domain/entities/haptic_profile_model.dart';
import 'package:haptibraille/domain/entities/training.dart';
import 'package:haptibraille/domain/training/curriculum.dart';

TrainingAttempt attempt(
  TrainingLevel level,
  String target, {
  bool correct = true,
  DateTime? at,
  int playbackMs = 1000,
}) =>
    TrainingAttempt(
      timestamp: at ?? DateTime(2026, 10, 31, 12),
      level: level,
      target: target,
      response: correct ? target : '?',
      correct: correct,
      responseMs: 500,
      playbackMs: playbackMs,
      replays: 0,
      profileId: 'standard',
      dotDurationMs: 40,
      intraCharPauseMs: 100,
      interCharPauseMs: 300,
    );

void main() {
  const curriculum = Curriculum();

  group('Curriculum', () {
    test('level 2 unlocks at 80% over at least 10 level-1 answers', () {
      final nine = List.generate(9, (_) => attempt(TrainingLevel.dots, '1'));
      expect(curriculum.isUnlocked(TrainingLevel.letters, nine), isFalse);

      final ten = [...nine, attempt(TrainingLevel.dots, '1')];
      expect(curriculum.isUnlocked(TrainingLevel.letters, ten), isTrue);
      expect(curriculum.currentLevel(ten), TrainingLevel.letters);

      final weak = [
        ...List.generate(7, (_) => attempt(TrainingLevel.dots, '1')),
        ...List.generate(3, (_) => attempt(TrainingLevel.dots, '1', correct: false)),
      ];
      expect(curriculum.isUnlocked(TrainingLevel.letters, weak), isFalse);
    });

    test('dot trials produce a single-dot cell matching the answer', () {
      final trial = curriculum.nextTrial(TrainingLevel.dots, const [], Random(1));
      expect(trial.cell!.raisedDots, [int.parse(trial.answer)]);
    });

    test('never repeats the previous answer back-to-back', () {
      final r = Random(3);
      for (var i = 0; i < 50; i++) {
        expect(curriculum.nextTrial(TrainingLevel.letters, const [], r, avoid: 'a').answer,
            isNot('a'));
      }
    });

    test('spoken and typed answers are normalised', () {
      expect(AnswerParser.normalise(TrainingLevel.dots, 'Three'), '3');
      expect(AnswerParser.normalise(TrainingLevel.dots, 'dot 5'), '5');
      expect(AnswerParser.normalise(TrainingLevel.letters, 'Bee'), 'b');
      expect(AnswerParser.normalise(TrainingLevel.letters, 'the letter Q'), 'q');
      expect(AnswerParser.normalise(TrainingLevel.letters, 'double you'), 'w');
      expect(AnswerParser.normalise(TrainingLevel.words, ' Cat. '), 'cat');
    });
  });

  group('AnalyticsCalculator', () {
    const calc = AnalyticsCalculator();
    final now = DateTime(2026, 10, 31, 18);

    test('streak counts consecutive days up to today or yesterday', () {
      final s = calc.compute([
        attempt(TrainingLevel.dots, '1', at: DateTime(2026, 10, 25)),
        attempt(TrainingLevel.dots, '1', at: DateTime(2026, 10, 29)),
        attempt(TrainingLevel.dots, '1', at: DateTime(2026, 10, 30)),
      ], now);
      expect(s.currentStreak, 2);
      expect(s.bestStreak, 2);

      final broken = calc.compute(
          [attempt(TrainingLevel.dots, '1', at: DateTime(2026, 10, 28))], now);
      expect(broken.currentStreak, 0);
      expect(broken.bestStreak, 1);
    });

    test('WPM = correct chars / 5 per minute of vibration, ignoring dot drills', () {
      final s = calc.compute([
        attempt(TrainingLevel.words, 'cat', playbackMs: 6000),
        attempt(TrainingLevel.words, 'dog', playbackMs: 6000, correct: false),
        attempt(TrainingLevel.dots, '1', playbackMs: 60000),
      ], now);
      // 3 correct chars = 0.6 words in 12 s (0.2 min) → 3 wpm.
      expect(s.recentWpm, closeTo(3.0, 1e-9));
    });

    test('focus letters are weak letters with enough tries', () {
      final s = calc.compute([
        for (var i = 0; i < 4; i++) attempt(TrainingLevel.letters, 'q', correct: i == 0),
        for (var i = 0; i < 4; i++) attempt(TrainingLevel.letters, 'a'),
      ], now);
      expect(s.focusLetters.map((l) => l.item), ['q']);
    });

    test('export JSON is versioned and round-trips attempts', () {
      final attempts = [attempt(TrainingLevel.letters, 'b')];
      final json = jsonDecode(calc.exportJson(attempts, now)) as Map<String, dynamic>;
      expect(json['schemaVersion'], 1);
      final restored = TrainingAttempt.fromJson(
          Map<String, dynamic>.from((json['attempts'] as List).single as Map));
      expect(restored.target, 'b');
      expect(restored.level, TrainingLevel.letters);
    });
  });

  group('HapticSequence frames & codec', () {
    const engine = HapticTranslationEngine();
    const translator = BrailleTranslator();
    const noAnchor = HapticProfileModel(cellAnchorEnabled: false);

    test('frameAt reports the vibrating dot of the current cell', () {
      // "b" = dots 1,2: dot1 at 0–40, silence 40–140, dot2 at 140–180.
      final seq = engine.build(translator.translate('b'), noAnchor);
      expect(seq.frameAt(10).activeSlot, 0);
      expect(seq.frameAt(100).activeSlot, isNull);
      expect(seq.frameAt(100).cell, BrailleTranslator.letters['b']);
      expect(seq.frameAt(150).activeSlot, 1);
    });

    test('anchor pulses are flagged in frames', () {
      final seq = engine.build(translator.translate('a'), HapticProfileModel.standard);
      expect(seq.frameAt(5).anchorActive, isTrue);
    });

    test('Android codec: parallel arrays, silence = 0 amplitude', () {
      final seq = engine.build(translator.translate('a'), noAnchor);
      final w = HapticPlatformCodec.toAndroidWaveform(seq);
      expect(w['timings'], [40, 750]);
      expect(w['amplitudes'], [255, 0]);
      expect(HapticPlatformCodec.toAndroidWaveform(seq, hasAmplitudeControl: false)['amplitudes'],
          [-1, 0]);
    });
  });
}
