import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viberead/data/datasources/platform/haptic_platform_codec.dart';
import 'package:viberead/domain/engine/braille_translator.dart';
import 'package:viberead/domain/engine/haptic_translation_engine.dart';
import 'package:viberead/domain/entities/haptic_profile_model.dart';
import 'package:viberead/domain/entities/haptic_sequence.dart';
import 'package:viberead/domain/services/i_haptic_player.dart';
import 'package:viberead/presentation/providers/haptic_providers.dart';
import 'package:viberead/presentation/screens/haptic_test/haptic_test_screen.dart';

class _FakePlayer implements IHapticPlayer {
  final played = <HapticSequence>[];
  int stops = 0;

  @override
  Future<HapticCapabilities> capabilities() async => const HapticCapabilities(
      hasVibrator: true, hasAmplitudeControl: true);

  @override
  Future<void> play(HapticSequence sequence) async => played.add(sequence);

  @override
  Future<void> stop() async => stops++;
}

void main() {
  test('Android codec: parallel arrays, silence = 0 amplitude', () {
    const profile = HapticProfileModel(cellAnchorEnabled: false);
    final seq = const HapticTranslationEngine()
        .build(const BrailleTranslator().translate('a'), profile);
    final w = HapticPlatformCodec.toAndroidWaveform(seq);
    expect(w['timings'], [40, 750]);
    expect(w['amplitudes'], [255, 0]);

    final noAmp =
        HapticPlatformCodec.toAndroidWaveform(seq, hasAmplitudeControl: false);
    expect(noAmp['amplitudes'], [-1, 0]);
  });

  testWidgets('Play sends a sequence to the player, Stop cancels it',
      (tester) async {
    final player = _FakePlayer();
    await tester.pumpWidget(ProviderScope(
      overrides: [hapticPlayerProvider.overrideWithValue(player)],
      child: const MaterialApp(home: HapticTestScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Play'));
    await tester.pump();
    expect(player.played, hasLength(1));
    expect(find.text('Stop'), findsOneWidget);

    await tester.tap(find.text('Stop'));
    await tester.pump();
    expect(player.stops, 1);
    expect(find.text('Play'), findsOneWidget);
  });
}
