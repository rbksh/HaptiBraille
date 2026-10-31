import '../entities/haptic_sequence.dart';

/// Non-Braille haptic signals, so deafblind learners get answer feedback
/// without needing the screen or audio. Deliberately unlike any Braille cell.
class FeedbackPatterns {
  const FeedbackPatterns._();

  /// Two quick, light taps – "yes".
  static final HapticSequence correct = HapticSequence(
    segments: const [
      HapticSegment(kind: HapticSegmentKind.dot, durationMs: 35, intensity: 0.7, sharpness: 1),
      HapticSegment.silence(90),
      HapticSegment(kind: HapticSegmentKind.dot, durationMs: 35, intensity: 0.7, sharpness: 1),
    ],
    tokenTimings: const [],
  );

  /// One long, heavy buzz – "no".
  static final HapticSequence incorrect = HapticSequence(
    segments: const [
      HapticSegment(kind: HapticSegmentKind.dot, durationMs: 450, intensity: 1, sharpness: 0.2),
    ],
    tokenTimings: const [],
  );
}
