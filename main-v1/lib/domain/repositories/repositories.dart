import '../entities/haptic_profile_model.dart';
import '../entities/training.dart';

abstract interface class ISettingsRepository {
  HapticProfileModel loadProfile();
  Future<void> saveProfile(HapticProfileModel profile);

  bool get hasOnboarded;
  Future<void> setOnboarded();
}

abstract interface class IAnalyticsRepository {
  /// All attempts, oldest first.
  List<TrainingAttempt> loadAttempts();
  Future<void> addAttempt(TrainingAttempt attempt);
  Future<void> clear();
}
