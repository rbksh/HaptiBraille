import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/platform/haptic_method_channel.dart';
import '../../domain/engine/braille_translator.dart';
import '../../domain/engine/haptic_translation_engine.dart';
import '../../domain/entities/haptic_profile_model.dart';
import '../../domain/services/i_haptic_player.dart';
import '../../domain/services/i_text_processor.dart';
import 'app_providers.dart';

/// Swap point for the AI agent: override with an AgentTextProcessor later.
final textProcessorProvider =
    Provider<ITextProcessor>((ref) => const BrailleTranslator());

final hapticEngineProvider =
    Provider<HapticTranslationEngine>((ref) => const HapticTranslationEngine());

final hapticPlayerProvider =
    Provider<IHapticPlayer>((ref) => MethodChannelHapticPlayer());

final hapticCapabilitiesProvider = FutureProvider<HapticCapabilities>(
  (ref) => ref.watch(hapticPlayerProvider).capabilities(),
);

class HapticProfileNotifier extends Notifier<HapticProfileModel> {
  @override
  HapticProfileModel build() => ref.watch(settingsRepositoryProvider).loadProfile();

  void set(HapticProfileModel profile) {
    state = profile;
    ref.read(settingsRepositoryProvider).saveProfile(profile);
  }
}

/// The user's haptic timings, persisted on every change.
final hapticProfileProvider =
    NotifierProvider<HapticProfileNotifier, HapticProfileModel>(HapticProfileNotifier.new);
