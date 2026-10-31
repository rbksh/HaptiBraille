# HaptiBraille

Read text through your phone's vibration motor, as temporal Braille. Built for blind,
deafblind and low-vision users.

## Features

- **Welcome + Home** – high-contrast dark UI, Atkinson Hyperlegible type, motion that respects
  the system "remove animations" setting.
- **Read** – type, paste, dictate or receive a demo notification, then feel it. An animated
  Braille cell lights each dot as it vibrates.
- **Talk to me** – a hearing person speaks; the message is transcribed and vibrated.
- **Train** – Level 1 single dots → Level 2 letters → Level 3 three-letter words. 80% accuracy
  over the last 20 answers unlocks the next level. Weak letters come up more often. Answers can be
  typed or spoken; correct/incorrect is also signalled by vibration.
- **Progress** – streak, accuracy, reading speed (WPM), practice time, accuracy and speed charts,
  per-letter accuracy, daily table, JSON export for an AI agent.
- **Settings** – presets and sliders for every haptic timing, dot strength, start-of-letter tick.

## Install on a phone (no computer needed)

Download [`release/HaptiBraille.apk`](release/HaptiBraille.apk) on an Android phone (Android 7+),
open it and tap **Install** (allow installs from this source if asked). Speech-to-text needs
internet on most phones.

## Run from source

```
flutter pub get
flutter test
flutter run        # Android phone with USB debugging on
```

## Layout

```
lib/
  core/          theme, motion, shared widgets (BrailleCellView, DotPicker…)
  domain/        entities, Braille + haptic engines, curriculum, analytics (pure Dart)
  data/          Hive repositories, Android haptic channel codec, speech-to-text, AI agent stub
  presentation/  Riverpod providers/controllers and screens
android/…/HapticChannel.kt   native VibrationEffect waveform playback
```
