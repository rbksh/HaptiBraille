import '../../../domain/entities/haptic_sequence.dart';

/// Serialises a [HapticSequence] into the payloads the native method channel
/// hands straight to the OS haptic APIs.
class HapticPlatformCodec {
  const HapticPlatformCodec._();

  /// Android `VibrationEffect.createWaveform(timings, amplitudes, -1)`.
  ///
  /// Without amplitude control (`Vibrator.hasAmplitudeControl() == false`)
  /// every pulse plays at DEFAULT_AMPLITUDE (-1); the cell anchor is then
  /// distinguishable from a dot only by its shorter duration.
  static Map<String, List<int>> toAndroidWaveform(
    HapticSequence sequence, {
    bool hasAmplitudeControl = true,
  }) {
    final timings = <int>[];
    final amplitudes = <int>[];
    for (final s in sequence.segments) {
      timings.add(s.durationMs);
      amplitudes.add(switch (s) {
        HapticSegment(isSilent: true) => 0,
        _ when !hasAmplitudeControl => -1,
        _ => (s.intensity * 255).round().clamp(1, 255),
      });
    }
    return {'timings': timings, 'amplitudes': amplitudes};
  }

  /// iOS CoreHaptics events (times in seconds, relative to pattern start).
  ///
  /// Dots are continuous events so `dotDuration` is honoured exactly; anchors
  /// are transient events – a crisp click with a different texture from a dot.
  static List<Map<String, Object>> toCoreHapticsEvents(HapticSequence sequence) {
    final events = <Map<String, Object>>[];
    var cursorMs = 0;
    for (final s in sequence.segments) {
      if (!s.isSilent) {
        events.add({
          'type': s.kind == HapticSegmentKind.anchor ? 'transient' : 'continuous',
          'time': cursorMs / 1000.0,
          if (s.kind != HapticSegmentKind.anchor) 'duration': s.durationMs / 1000.0,
          'intensity': s.intensity,
          'sharpness': s.sharpness,
        });
      }
      cursorMs += s.durationMs;
    }
    return events;
  }
}
