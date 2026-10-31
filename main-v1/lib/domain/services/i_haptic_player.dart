import '../entities/haptic_sequence.dart';

class HapticCapabilities {
  const HapticCapabilities({
    required this.hasVibrator,
    required this.hasAmplitudeControl,
  });

  static const none =
      HapticCapabilities(hasVibrator: false, hasAmplitudeControl: false);

  final bool hasVibrator;

  /// Without it, every pulse plays at one fixed strength, so the cell anchor
  /// can only be told apart from a dot by its shorter length.
  final bool hasAmplitudeControl;
}

/// Plays a fully timed [HapticSequence] on the device motor.
abstract interface class IHapticPlayer {
  Future<HapticCapabilities> capabilities();

  /// Starts playback and returns once the OS has accepted the waveform
  /// (not when it finishes – use [HapticSequence.totalDuration] for that).
  Future<void> play(HapticSequence sequence);

  Future<void> stop();
}
