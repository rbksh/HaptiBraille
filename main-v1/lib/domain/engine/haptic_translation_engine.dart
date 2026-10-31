import '../entities/braille_cell.dart';
import '../entities/haptic_profile_model.dart';
import '../entities/haptic_sequence.dart';

/// Turns Braille tokens into a millisecond-exact haptic waveform.
///
/// Pure and synchronous: no platform calls, no state. That makes it trivially
/// unit-testable and lets an AI agent "dry-run" a profile (e.g. to estimate
/// reading time) without touching the motor.
///
/// Timing of one cell:
///
///     [anchor, intra]  slot1  intra  slot2  intra  …  slot6
///
/// slot = pulse(dotDuration) if raised, silence(emptySlotDuration) if flat.
/// Cells are separated by interCharPause, words by spacePause.
class HapticTranslationEngine {
  const HapticTranslationEngine();

  HapticSequence build(BrailleDocument document, HapticProfileModel profile) =>
      buildFromTokens(document.tokens, profile);

  HapticSequence buildFromTokens(
    List<BrailleToken> tokens,
    HapticProfileModel profile,
  ) {
    final out = _SequenceBuilder();
    final timings = <TokenTiming>[];
    var hasEmittedCell = false;
    var wordBreakPending = false;

    for (final token in tokens) {
      if (token.isWordBreak) {
        wordBreakPending = hasEmittedCell;
        continue;
      }
      if (token.cells.isEmpty) continue;

      int? startMs;
      for (final cell in token.cells) {
        if (hasEmittedCell) {
          out.silence(wordBreakPending
              ? profile.spacePause.inMilliseconds
              : profile.interCharPause.inMilliseconds);
          wordBreakPending = false;
        }
        startMs ??= out.cursorMs;
        _emitCell(out, cell, profile);
        hasEmittedCell = true;
      }

      timings.add(TokenTiming(
        sourceIndex: token.sourceIndex,
        startMs: startMs!,
        endMs: out.cursorMs,
      ));
    }

    return HapticSequence(segments: out.segments, tokenTimings: timings);
  }

  /// A single cell on its own – training levels 1 and 2.
  HapticSequence buildCell(BrailleCell cell, HapticProfileModel profile) {
    final out = _SequenceBuilder();
    _emitCell(out, cell, profile);
    return HapticSequence(
      segments: out.segments,
      tokenTimings: [TokenTiming(sourceIndex: 0, startMs: 0, endMs: out.cursorMs)],
    );
  }

  /// Duration of one cell under [profile] (depends on which dots are raised
  /// when dotDuration != emptySlotDuration).
  Duration cellDuration(BrailleCell cell, HapticProfileModel profile) {
    final out = _SequenceBuilder();
    _emitCell(out, cell, profile);
    return Duration(milliseconds: out.cursorMs);
  }

  void _emitCell(_SequenceBuilder out, BrailleCell cell, HapticProfileModel p) {
    final intra = p.intraCharPause.inMilliseconds;

    if (p.cellAnchorEnabled) {
      out.pulse(
        HapticSegmentKind.anchor,
        p.anchorDuration.inMilliseconds,
        p.anchorIntensity,
        p.anchorSharpness,
      );
      out.silence(intra);
    }

    for (var slot = 0; slot < BrailleCell.dotCount; slot++) {
      if (slot > 0) out.silence(intra);
      if (cell.isRaisedAt(slot)) {
        out.pulse(
          HapticSegmentKind.dot,
          p.dotDuration.inMilliseconds,
          p.intensity,
          p.sharpness,
        );
      } else {
        out.silence(p.emptySlotDuration.inMilliseconds);
      }
    }
  }
}

class _SequenceBuilder {
  final List<HapticSegment> segments = [];
  int cursorMs = 0;

  void silence(int ms) {
    if (ms <= 0) return;
    cursorMs += ms;
    if (segments.isNotEmpty && segments.last.isSilent) {
      segments[segments.length - 1] =
          HapticSegment.silence(segments.last.durationMs + ms);
    } else {
      segments.add(HapticSegment.silence(ms));
    }
  }

  void pulse(HapticSegmentKind kind, int ms, double intensity, double sharpness) {
    if (ms <= 0) return;
    cursorMs += ms;
    segments.add(HapticSegment(
      kind: kind,
      durationMs: ms,
      intensity: intensity,
      sharpness: sharpness,
    ));
  }
}
