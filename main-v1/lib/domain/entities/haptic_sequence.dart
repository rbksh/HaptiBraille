enum HapticSegmentKind { dot, anchor, silence }

/// One contiguous stretch of the waveform: either the motor on, or silence.
class HapticSegment {
  const HapticSegment({
    required this.kind,
    required this.durationMs,
    this.intensity = 0,
    this.sharpness = 0,
  });

  const HapticSegment.silence(this.durationMs)
      : kind = HapticSegmentKind.silence,
        intensity = 0,
        sharpness = 0;

  final HapticSegmentKind kind;
  final int durationMs;
  final double intensity;
  final double sharpness;

  bool get isSilent => kind == HapticSegmentKind.silence;

  @override
  String toString() => isSilent
      ? 'silence(${durationMs}ms)'
      : '${kind.name}(${durationMs}ms @${intensity.toStringAsFixed(2)})';
}

/// When a source character is felt, relative to sequence start.
class TokenTiming {
  const TokenTiming({
    required this.sourceIndex,
    required this.startMs,
    required this.endMs,
  });

  final int sourceIndex;
  final int startMs;
  final int endMs;
}

/// Platform-agnostic, fully timed haptic waveform.
///
/// Pure data: the platform codec turns it into an Android `VibrationEffect`
/// waveform or a CoreHaptics pattern. Adjacent silences are already merged.
class HapticSequence {
  HapticSequence({
    required List<HapticSegment> segments,
    required List<TokenTiming> tokenTimings,
  })  : segments = List.unmodifiable(segments),
        tokenTimings = List.unmodifiable(tokenTimings),
        totalDurationMs = segments.fold(0, (sum, s) => sum + s.durationMs);

  final List<HapticSegment> segments;
  final List<TokenTiming> tokenTimings;
  final int totalDurationMs;

  Duration get totalDuration => Duration(milliseconds: totalDurationMs);

  bool get isEmpty => segments.isEmpty;

  /// The token being felt at [elapsedMs] – for highlighting / resume.
  TokenTiming? tokenAt(int elapsedMs) {
    for (final t in tokenTimings) {
      if (elapsedMs < t.startMs) return null;
      if (elapsedMs < t.endMs) return t;
    }
    return null;
  }
}
