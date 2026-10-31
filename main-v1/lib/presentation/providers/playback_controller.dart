import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/braille_cell.dart';
import '../../domain/entities/haptic_sequence.dart';
import 'haptic_providers.dart';

class PlaybackState {
  const PlaybackState({
    this.sequence,
    this.document,
    this.playing = false,
    this.elapsedMs = 0,
    this.frame = PlaybackFrame.idle,
    this.activeSourceIndex,
    this.hapticsUnavailable = false,
  });

  final HapticSequence? sequence;
  final BrailleDocument? document;
  final bool playing;
  final int elapsedMs;
  final PlaybackFrame frame;

  /// Index into [document]'s text of the character being felt.
  final int? activeSourceIndex;

  /// True when the device couldn't vibrate; the animation still runs.
  final bool hapticsUnavailable;

  double get progress {
    final total = sequence?.totalDurationMs ?? 0;
    return total == 0 ? 0 : (elapsedMs / total).clamp(0, 1);
  }
}

/// Plays sequences on the motor and publishes a synchronised animation frame.
///
/// Shared by the reader, talk and training screens; only one thing vibrates
/// at a time, so starting a new playback stops the previous one.
class PlaybackController extends Notifier<PlaybackState> {
  Timer? _ticker;
  DateTime? _startedAt;
  Completer<void>? _done;

  @override
  PlaybackState build() {
    ref.onDispose(() => _ticker?.cancel());
    return const PlaybackState();
  }

  /// Translates and plays [text]. Completes when playback ends or is stopped.
  Future<HapticSequence> playText(String text) async {
    final document = await ref.read(textProcessorProvider).process(text);
    final sequence = ref.read(hapticEngineProvider).build(document, ref.read(hapticProfileProvider));
    await playSequence(sequence, document: document);
    return sequence;
  }

  Future<HapticSequence> playCell(BrailleCell cell) async {
    final sequence = ref.read(hapticEngineProvider).buildCell(cell, ref.read(hapticProfileProvider));
    await playSequence(sequence);
    return sequence;
  }

  Future<void> playSequence(HapticSequence sequence, {BrailleDocument? document}) async {
    await stop();
    if (sequence.isEmpty) return;

    var unavailable = false;
    try {
      await ref.read(hapticPlayerProvider).play(sequence);
    } catch (_) {
      unavailable = true; // e.g. desktop/web preview – keep the animation
    }

    final done = _done = Completer<void>();
    _startedAt = clock.now();
    state = PlaybackState(
      sequence: sequence,
      document: document,
      playing: true,
      hapticsUnavailable: unavailable,
    );
    _ticker = Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
    return done.future;
  }

  Future<void> stop() async {
    if (!state.playing) return;
    _finish();
    try {
      await ref.read(hapticPlayerProvider).stop();
    } catch (_) {}
  }

  void _tick() {
    final sequence = state.sequence;
    final start = _startedAt;
    if (sequence == null || start == null) return;
    final ms = clock.now().difference(start).inMilliseconds;
    if (ms >= sequence.totalDurationMs) {
      _finish();
      return;
    }
    final frame = sequence.frameAt(ms);
    final index = sequence.tokenAt(ms)?.sourceIndex;
    final changed = frame.activeSlot != state.frame.activeSlot ||
        frame.anchorActive != state.frame.anchorActive ||
        frame.cell != state.frame.cell ||
        index != state.activeSourceIndex ||
        ms - state.elapsedMs >= 100;
    if (!changed) return;
    state = PlaybackState(
      sequence: sequence,
      document: state.document,
      playing: true,
      elapsedMs: ms,
      frame: frame,
      activeSourceIndex: index,
      hapticsUnavailable: state.hapticsUnavailable,
    );
  }

  void _finish() {
    _ticker?.cancel();
    _ticker = null;
    state = PlaybackState(
      sequence: state.sequence,
      document: state.document,
      elapsedMs: state.sequence?.totalDurationMs ?? 0,
      hapticsUnavailable: state.hapticsUnavailable,
    );
    final done = _done;
    _done = null;
    if (done != null && !done.isCompleted) done.complete();
  }
}

final playbackProvider =
    NotifierProvider<PlaybackController, PlaybackState>(PlaybackController.new);
