import '../../domain/entities/haptic_profile_model.dart';
import '../../domain/entities/training.dart';
import '../../domain/repositories/repositories.dart';

/// Non-persistent repositories for tests and previews.
class InMemorySettingsRepository implements ISettingsRepository {
  InMemorySettingsRepository({
    HapticProfileModel profile = HapticProfileModel.standard,
    bool onboarded = false,
  })  : _profile = profile,
        _onboarded = onboarded;

  HapticProfileModel _profile;
  bool _onboarded;

  @override
  HapticProfileModel loadProfile() => _profile;

  @override
  Future<void> saveProfile(HapticProfileModel profile) async => _profile = profile;

  @override
  bool get hasOnboarded => _onboarded;

  @override
  Future<void> setOnboarded() async => _onboarded = true;
}

class InMemoryAnalyticsRepository implements IAnalyticsRepository {
  InMemoryAnalyticsRepository([List<TrainingAttempt>? seed])
      : _attempts = [...?seed];

  final List<TrainingAttempt> _attempts;

  @override
  List<TrainingAttempt> loadAttempts() => List.unmodifiable(_attempts);

  @override
  Future<void> addAttempt(TrainingAttempt attempt) async => _attempts.add(attempt);

  @override
  Future<void> clear() async => _attempts.clear();
}
