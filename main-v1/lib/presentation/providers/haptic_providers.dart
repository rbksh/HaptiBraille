import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/platform/haptic_method_channel.dart';
import '../../domain/engine/braille_translator.dart';
import '../../domain/engine/haptic_translation_engine.dart';
import '../../domain/entities/haptic_profile_model.dart';
import '../../domain/services/i_haptic_player.dart';
import '../../domain/services/i_text_processor.dart';

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

// TODO: persist via a Hive-backed profile repository.
final hapticProfileProvider =
    StateProvider<HapticProfileModel>((ref) => HapticProfileModel.standard);
