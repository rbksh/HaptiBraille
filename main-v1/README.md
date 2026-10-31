# VibeRead – main-v1 (Flutter)

Temporal vibrotactile Braille: text is translated to Grade 1 (UEB) Braille and
played as a rhythm on the phone's single haptic motor.

## Status

- Translation engine (`lib/domain/engine/`) – ASCII → Grade 1 UEB, numeric/capital indicators.
- `HapticProfileModel` – tunable timings (dot, empty slot, intra/inter-char, space) with
  anti-"sensory blur" validation and JSON storage format.
- `HapticTranslationEngine` – builds millisecond-exact waveforms.
- Android native haptic channel (`android/.../HapticChannel.kt`) using `VibrationEffect.createWaveform`.
- Haptic test screen with presets and timing sliders.
- iOS (CoreHaptics), training module, analytics, Hive storage, AI agent – not yet built.

## Run

```
flutter pub get
flutter test
flutter run          # with an Android phone connected (USB debugging on)
```

## Layout

```
lib/
  domain/        entities, engine, service interfaces (pure Dart)
  data/          platform channel + codecs
  presentation/  Riverpod providers, screens
android/         native HapticChannel.kt
test/            unit + widget tests
```
