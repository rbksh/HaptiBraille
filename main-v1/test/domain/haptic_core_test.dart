import 'package:flutter_test/flutter_test.dart';
import 'package:viberead/domain/engine/braille_translator.dart';
import 'package:viberead/domain/engine/haptic_translation_engine.dart';
import 'package:viberead/domain/entities/braille_cell.dart';
import 'package:viberead/domain/entities/haptic_profile_model.dart';
import 'package:viberead/domain/entities/haptic_sequence.dart';

void main() {
  const translator = BrailleTranslator();
  const engine = HapticTranslationEngine();

  List<String> unicode(String text) => translator
      .translate(text)
      .tokens
      .map((t) => t.isWordBreak ? ' ' : t.cells.map((c) => c.unicode).join())
      .toList();

  group('BrailleTranslator', () {
    test('letters map to Grade 1 cells', () {
      expect(unicode('abz'), ['⠁', '⠃', '⠵']);
    });

    test('capital letter and capital word indicators', () {
      expect(unicode('Hi'), ['⠠⠓', '⠊']);
      expect(unicode('NASA'), ['⠠⠠⠝', '⠁', '⠎', '⠁']);
    });

    test('numeric mode and grade 1 indicator for a-j after digits', () {
      expect(unicode('12'), ['⠼⠁', '⠃']);
      expect(unicode('1a'), ['⠼⠁', '⠰⠁']);
      expect(unicode('3.5'), ['⠼⠉', '⠲', '⠑']);
    });

    test('whitespace collapses to single word breaks', () {
      final doc = translator.translate('  hi   there \n');
      expect(doc.tokens.where((t) => t.isWordBreak).length, 1);
      expect(doc.wordCount, 2);
    });

    test('unsupported characters are reported, not dropped silently', () {
      final doc = translator.translate('a€b');
      expect(doc.unsupportedIndices, [1]);
      expect(doc.tokens.length, 2);
    });
  });

  group('HapticTranslationEngine', () {
    const noAnchor = HapticProfileModel(cellAnchorEnabled: false);

    test('single "a": one dot then five empty slots of silence', () {
      final seq = engine.buildCell(BrailleCell.parse('1'), noAnchor);
      expect(seq.segments.length, 2);
      expect(seq.segments[0].kind, HapticSegmentKind.dot);
      expect(seq.segments[0].durationMs, 40);
      // 5 × (intra 100 + empty 50), merged into one silence.
      expect(seq.segments[1].durationMs, 750);
      expect(seq.totalDurationMs, 790);
    });

    test('word break uses spacePause instead of interCharPause', () {
      final word = engine.build(translator.translate('aa'), noAnchor);
      final words = engine.build(translator.translate('a a'), noAnchor);
      expect(words.totalDurationMs - word.totalDurationMs,
          noAnchor.spacePause.inMilliseconds -
              noAnchor.interCharPause.inMilliseconds);
    });

    test('anchor pulse precedes every cell', () {
      final seq = engine.build(translator.translate('ab'), HapticProfileModel.standard);
      final anchors =
          seq.segments.where((s) => s.kind == HapticSegmentKind.anchor);
      expect(anchors.length, 2);
      expect(seq.segments.first.kind, HapticSegmentKind.anchor);
    });

    test('token timings are ordered and cover each character', () {
      final seq = engine.build(translator.translate('hi you'), noAnchor);
      expect(seq.tokenTimings.map((t) => t.sourceIndex), [0, 1, 3, 4, 5]);
      expect(seq.tokenAt(seq.tokenTimings[2].startMs)?.sourceIndex, 3);
    });
  });

  group('HapticProfileModel', () {
    test('presets are valid', () {
      for (final p in HapticProfileModel.presets) {
        expect(p.isValid, isTrue, reason: p.validate().join('\n'));
      }
    });

    test('letter gap not longer than dot gap is an error', () {
      const p = HapticProfileModel(
        intraCharPause: Duration(milliseconds: 200),
        interCharPause: Duration(milliseconds: 150),
      );
      expect(p.isValid, isFalse);
    });

    test('withTiming clamps to hardware bounds', () {
      final p = HapticProfileModel.standard
          .withTiming(HapticTimingParam.dotDuration, Duration.zero);
      expect(p.dotDuration.inMilliseconds, HapticTimingParam.dotDuration.minMs);
    });

    test('scaled slows pauses but keeps pulse length', () {
      final p = HapticProfileModel.standard.scaled(2);
      expect(p.dotDuration, HapticProfileModel.standard.dotDuration);
      expect(p.interCharPause.inMilliseconds, 600);
    });

    test('JSON round-trip', () {
      final p = HapticProfileModel.fast.copyWith(intensity: 0.7);
      expect(HapticProfileModel.fromJson(p.toJson()), p);
    });
  });
}
