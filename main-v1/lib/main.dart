import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'data/repositories/hive_repositories.dart';
import 'presentation/providers/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final settings = await Hive.openBox<dynamic>(HiveSettingsRepository.boxName);
  final attempts = await Hive.openBox<dynamic>(HiveAnalyticsRepository.boxName);

  runApp(ProviderScope(
    overrides: [
      settingsRepositoryProvider.overrideWithValue(HiveSettingsRepository(settings)),
      analyticsRepositoryProvider.overrideWithValue(HiveAnalyticsRepository(attempts)),
    ],
    child: const HaptiBrailleApp(),
  ));
}
