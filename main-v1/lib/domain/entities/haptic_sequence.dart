import 'braille_cell.dart';

enum HapticSegmentKind { dot, anchor, silence }

/// One contiguous stretch of the waveform: either the motor on, or silence.
class HapticSegment {
  const HapticSegment({
    required this.kind,
    required this.durationMs,
    this.intensity = 0,
    this.sharpness = 0,
    this.cellIndex,
    this.slot,
  });

  const HapticSegment.silence(this.durationMs)
      : kind = HapticSegmentKind.silence,
        intensity = 0,
        sharpness = 0,
        cellIndex = null,
        slot = null;

  final HapticSegmentKind kind;
  final int durationMs;
  final double intensity;
  final double sharpness;

  /// Index into [HapticSequence.cells] for pulses; null for silence.
  final int? cellIndex;

  /// 0-based dot slot (0..5) for dot pulses; null for anchors and silence.
  final int? slot;

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

/// What the motor is doing at a given moment – drives the animated cell view.
class PlaybackFrame {
  const PlaybackFrame({this.cell, this.activeSlot, this.anchorActive = false});

  static const idle = PlaybackFrame();

  final BrailleCell? cell;
  final int? activeSlot;
  final bool anchorActive;
}

/// Platform-agnostic, fully timed haptic waveform.
///
/// Pure data: the platform codec turns it into an Android `VibrationEffect`
/// waveform or a CoreHaptics pattern. Adjacent silences are already merged.
class HapticSequence {
  HapticSequence({
    required List<HapticSegment> segments,
    required List<TokenTiming> tokenTimings,
    List<BrailleCell> cells = const [],
  })  : segments = List.unmodifiable(segments),
        tokenTimings = List.unmodifiable(tokenTimings),
        cells = List.unmodifiable(cells),
        _starts = _computeStarts(segments),
        totalDurationMs = segments.fold(0, (sum, s) => sum + s.durationMs);

  final List<HapticSegment> segments;
  final List<TokenTiming> tokenTimings;

  /// Every cell in playback order (indicators included).
  final List<BrailleCell> cells;
  final int totalDurationMs;
  final List<int> _starts;

  static List<int> _computeStarts(List<HapticSegment> segments) {
    var t = 0;
    return [
      for (final s in segments) (t += s.durationMs) - s.durationMs,
    ];
  }

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

  /// The cell and dot being felt at [elapsedMs]. During silences the most
  /// recent cell stays visible so the animation doesn't flicker.
  PlaybackFrame frameAt(int elapsedMs) {
    int? cellIndex;
    for (var i = 0; i < segments.length; i++) {
      if (_starts[i] > elapsedMs) break;
      final s = segments[i];
      if (s.cellIndex != null) cellIndex = s.cellIndex;
      final active = elapsedMs < _starts[i] + s.durationMs;
      if (active && !s.isSilent) {
        return PlaybackFrame(
          cell: cells.isEmpty ? null : cells[s.cellIndex!],
          activeSlot: s.slot,
          anchorActive: s.kind == HapticSegmentKind.anchor,
        );
      }
    }
    return PlaybackFrame(
      cell: cellIndex == null || cells.isEmpty ? null : cells[cellIndex],
    );
  }
}
