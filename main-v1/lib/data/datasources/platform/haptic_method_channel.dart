import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../domain/entities/haptic_sequence.dart';
import '../../../domain/services/i_haptic_player.dart';
import 'haptic_platform_codec.dart';

/// [IHapticPlayer] backed by the native "viberead/haptics" channel.
/// Android: `HapticChannel.kt`. iOS: not implemented yet.
class MethodChannelHapticPlayer implements IHapticPlayer {
  MethodChannelHapticPlayer({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('viberead/haptics');

  final MethodChannel _channel;
  HapticCapabilities? _capabilities;

  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<HapticCapabilities> capabilities() async {
    if (_capabilities case final cached?) return cached;
    if (!_isAndroid) return HapticCapabilities.none;

    final raw = await _channel.invokeMapMethod<String, Object?>('getCapabilities');
    return _capabilities = HapticCapabilities(
      hasVibrator: raw?['hasVibrator'] == true,
      hasAmplitudeControl: raw?['hasAmplitudeControl'] == true,
    );
  }

  @override
  Future<void> play(HapticSequence sequence) async {
    if (sequence.isEmpty) return;
    if (!_isAndroid) {
      throw UnsupportedError('Haptic playback is only implemented on Android so far.');
    }
    final caps = await capabilities();
    await _channel.invokeMethod<void>(
      'playWaveform',
      HapticPlatformCodec.toAndroidWaveform(
        sequence,
        hasAmplitudeControl: caps.hasAmplitudeControl,
      ),
    );
  }

  @override
  Future<void> stop() async {
    if (!_isAndroid) return;
    await _channel.invokeMethod<void>('cancel');
  }
}
