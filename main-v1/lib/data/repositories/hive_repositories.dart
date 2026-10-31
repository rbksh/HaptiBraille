import 'package:hive/hive.dart';

import '../../domain/entities/haptic_profile_model.dart';
import '../../domain/entities/training.dart';
import '../../domain/repositories/repositories.dart';

/// Values are stored as plain JSON maps – no generated adapters, and the data
/// stays readable by an external AI agent.
class HiveSettingsRepository implements ISettingsRepository {
  HiveSettingsRepository(this._box);

  static const boxName = 'settings';
  final Box<dynamic> _box;

  @override
  HapticProfileModel loadProfile() {
    final raw = _box.get('profile');
    return raw is Map
        ? HapticProfileModel.fromJson(Map<String, dynamic>.from(raw))
        : HapticProfileModel.standard;
  }

  @override
  Future<void> saveProfile(HapticProfileModel profile) =>
      _box.put('profile', profile.toJson());

  @override
  bool get hasOnboarded => _box.get('onboarded') == true;

  @override
  Future<void> setOnboarded() => _box.put('onboarded', true);
}

class HiveAnalyticsRepository implements IAnalyticsRepository {
  HiveAnalyticsRepository(this._box);

  static const boxName = 'attempts';
  final Box<dynamic> _box;

  @override
  List<TrainingAttempt> loadAttempts() => [
        for (final raw in _box.values)
          if (raw is Map) TrainingAttempt.fromJson(Map<String, dynamic>.from(raw)),
      ];

  @override
  Future<void> addAttempt(TrainingAttempt attempt) => _box.add(attempt.toJson());

  @override
  Future<void> clear() => _box.clear();
}
