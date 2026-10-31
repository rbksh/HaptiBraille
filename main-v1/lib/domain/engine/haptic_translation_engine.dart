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
    var wordBreakPending = false;

    for (final token in tokens) {
      if (token.isWordBreak) {
        wordBreakPending = out.cells.isNotEmpty;
        continue;
      }
      if (token.cells.isEmpty) continue;

      int? startMs;
      for (final cell in token.cells) {
        if (out.cells.isNotEmpty) {
          out.silence(wordBreakPending
              ? profile.spacePause.inMilliseconds
              : profile.interCharPause.inMilliseconds);
          wordBreakPending = false;
        }
        startMs ??= out.cursorMs;
        _emitCell(out, cell, profile);
      }

      timings.add(TokenTiming(
        sourceIndex: token.sourceIndex,
        startMs: startMs!,
        endMs: out.cursorMs,
      ));
    }

    return out.build(timings);
  }

  /// A single cell on its own – training levels 1 and 2.
  HapticSequence buildCell(BrailleCell cell, HapticProfileModel profile) {
    final out = _SequenceBuilder();
    _emitCell(out, cell, profile);
    return out.build(
      [TokenTiming(sourceIndex: 0, startMs: 0, endMs: out.cursorMs)],
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
    final cellIndex = out.cells.length;
    out.cells.add(cell);

    if (p.cellAnchorEnabled) {
      out.pulse(HapticSegment(
        kind: HapticSegmentKind.anchor,
        durationMs: p.anchorDuration.inMilliseconds,
        intensity: p.anchorIntensity,
        sharpness: p.anchorSharpness,
        cellIndex: cellIndex,
      ));
      out.silence(intra);
    }

    for (var slot = 0; slot < BrailleCell.dotCount; slot++) {
      if (slot > 0) out.silence(intra);
      if (cell.isRaisedAt(slot)) {
        out.pulse(HapticSegment(
          kind: HapticSegmentKind.dot,
          durationMs: p.dotDuration.inMilliseconds,
          intensity: p.intensity,
          sharpness: p.sharpness,
          cellIndex: cellIndex,
          slot: slot,
        ));
      } else {
        out.silence(p.emptySlotDuration.inMilliseconds);
      }
    }
  }
}

class _SequenceBuilder {
  final List<HapticSegment> segments = [];
  final List<BrailleCell> cells = [];
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

  void pulse(HapticSegment segment) {
    if (segment.durationMs <= 0) return;
    cursorMs += segment.durationMs;
    segments.add(segment);
  }

  HapticSequence build(List<TokenTiming> timings) =>
      HapticSequence(segments: segments, tokenTimings: timings, cells: cells);
}
