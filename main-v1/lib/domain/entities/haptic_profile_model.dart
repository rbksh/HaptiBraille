/// The five user-tunable timings of temporal Braille.
///
/// Settings sliders iterate this enum, so labels and bounds live in one place.
/// Bounds are hardware/perception limits, not preferences: below ~10 ms most
/// LRA motors never reach perceptible amplitude.
enum HapticTimingParam {
  dotDuration('Dot pulse length', 10, 200),
  emptySlotDuration('Empty dot pause', 10, 500),
  intraCharPause('Pause between dots', 20, 1000),
  interCharPause('Pause between letters', 50, 3000),
  spacePause('Pause between words', 100, 5000);

  const HapticTimingParam(this.label, this.minMs, this.maxMs);

  /// Human-readable label; also used as the TalkBack/VoiceOver slider label.
  final String label;
  final int minMs;
  final int maxMs;

  String get jsonKey => '${name}Ms';

  Duration clamp(Duration value) =>
      Duration(milliseconds: value.inMilliseconds.clamp(minMs, maxMs));
}

enum ProfileIssueSeverity { warning, error }

class ProfileIssue {
  const ProfileIssue(this.severity, this.message, {this.param});

  final ProfileIssueSeverity severity;
  final String message;
  final HapticTimingParam? param;

  @override
  String toString() => '${severity.name}: $message';
}

/// Immutable description of how Braille cells are turned into vibration.
///
/// Playback of one cell (see `HapticTranslationEngine`):
///
///     [anchor] intra  slot1 intra slot2 intra … slot6   interChar  next cell
///
/// where each slot is either a pulse of [dotDuration] (raised dot) or a
/// silence of [emptySlotDuration] (flat dot). Between words, [spacePause]
/// replaces [interCharPause].
///
/// The optional *cell anchor* is a short, soft tick at the start of every
/// cell. Without it, a cell whose first dots are flat (e.g. "i" = dots 2,4)
/// begins with silence, so the reader has no reference point to count slots
/// from – a major source of sensory blur. It is on by default for that reason.
class HapticProfileModel {
  const HapticProfileModel({
    this.id = 'standard',
    this.name = 'Standard',
    this.dotDuration = const Duration(milliseconds: 40),
    this.emptySlotDuration = const Duration(milliseconds: 50),
    this.intraCharPause = const Duration(milliseconds: 100),
    this.interCharPause = const Duration(milliseconds: 300),
    this.spacePause = const Duration(milliseconds: 600),
    this.intensity = 1.0,
    this.sharpness = 0.8,
    this.cellAnchorEnabled = true,
    this.anchorDuration = const Duration(milliseconds: 12),
    this.anchorIntensity = 0.35,
    this.anchorSharpness = 1.0,
  });

  static const int schemaVersion = 1;

  static const HapticProfileModel beginner = HapticProfileModel(
    id: 'beginner',
    name: 'Beginner',
    dotDuration: Duration(milliseconds: 50),
    emptySlotDuration: Duration(milliseconds: 80),
    intraCharPause: Duration(milliseconds: 150),
    interCharPause: Duration(milliseconds: 500),
    spacePause: Duration(milliseconds: 1000),
  );

  static const HapticProfileModel standard = HapticProfileModel();

  static const HapticProfileModel fast = HapticProfileModel(
    id: 'fast',
    name: 'Fast',
    dotDuration: Duration(milliseconds: 30),
    emptySlotDuration: Duration(milliseconds: 40),
    intraCharPause: Duration(milliseconds: 70),
    interCharPause: Duration(milliseconds: 200),
    spacePause: Duration(milliseconds: 450),
  );

  static const List<HapticProfileModel> presets = [beginner, standard, fast];

  final String id;
  final String name;

  /// Length of one raised-dot pulse.
  final Duration dotDuration;

  /// Silence that stands in for a flat dot. Never vibrates.
  final Duration emptySlotDuration;

  /// Gap between consecutive dot slots inside one cell.
  final Duration intraCharPause;

  /// Gap between cells.
  final Duration interCharPause;

  /// Gap between words (replaces [interCharPause], not added to it).
  final Duration spacePause;

  /// Dot strength, 0..1. Android: amplitude 1..255. iOS: hapticIntensity.
  final double intensity;

  /// iOS hapticSharpness, 0..1 (ignored on Android).
  final double sharpness;

  final bool cellAnchorEnabled;
  final Duration anchorDuration;
  final double anchorIntensity;
  final double anchorSharpness;

  Duration valueOf(HapticTimingParam param) => switch (param) {
        HapticTimingParam.dotDuration => dotDuration,
        HapticTimingParam.emptySlotDuration => emptySlotDuration,
        HapticTimingParam.intraCharPause => intraCharPause,
        HapticTimingParam.interCharPause => interCharPause,
        HapticTimingParam.spacePause => spacePause,
      };

  /// Slider-friendly setter; the value is clamped to the param's bounds.
  HapticProfileModel withTiming(HapticTimingParam param, Duration value) {
    final v = param.clamp(value);
    return switch (param) {
      HapticTimingParam.dotDuration => copyWith(dotDuration: v),
      HapticTimingParam.emptySlotDuration => copyWith(emptySlotDuration: v),
      HapticTimingParam.intraCharPause => copyWith(intraCharPause: v),
      HapticTimingParam.interCharPause => copyWith(interCharPause: v),
      HapticTimingParam.spacePause => copyWith(spacePause: v),
    };
  }

  /// Tempo change, e.g. for an AI agent reacting to user struggle.
  ///
  /// `factor > 1` slows down. Only silences are scaled: the dot pulse length
  /// is a motor/perception property, not tempo, so it is left alone.
  HapticProfileModel scaled(double factor) {
    assert(factor > 0);
    Duration s(HapticTimingParam p) => p.clamp(valueOf(p) * factor);
    return copyWith(
      emptySlotDuration: s(HapticTimingParam.emptySlotDuration),
      intraCharPause: s(HapticTimingParam.intraCharPause),
      interCharPause: s(HapticTimingParam.interCharPause),
      spacePause: s(HapticTimingParam.spacePause),
    );
  }

  /// Checks bounds and the ordering rules that prevent sensory blur.
  List<ProfileIssue> validate() {
    final issues = <ProfileIssue>[];

    for (final p in HapticTimingParam.values) {
      final ms = valueOf(p).inMilliseconds;
      if (ms < p.minMs || ms > p.maxMs) {
        issues.add(ProfileIssue(
          ProfileIssueSeverity.error,
          '${p.label} must be between ${p.minMs} and ${p.maxMs} ms',
          param: p,
        ));
      }
    }

    final intra = intraCharPause.inMilliseconds;
    final inter = interCharPause.inMilliseconds;
    final space = spacePause.inMilliseconds;

    if (inter <= intra) {
      issues.add(const ProfileIssue(
        ProfileIssueSeverity.error,
        'Pause between letters must be longer than pause between dots, '
        'otherwise letters run together.',
        param: HapticTimingParam.interCharPause,
      ));
    } else if (inter < intra * 2) {
      issues.add(const ProfileIssue(
        ProfileIssueSeverity.warning,
        'Pause between letters is less than twice the pause between dots; '
        'letter boundaries may be hard to feel.',
        param: HapticTimingParam.interCharPause,
      ));
    }

    if (space <= inter) {
      issues.add(const ProfileIssue(
        ProfileIssueSeverity.error,
        'Pause between words must be longer than pause between letters.',
        param: HapticTimingParam.spacePause,
      ));
    }

    if (dotDuration.inMilliseconds < 20) {
      issues.add(const ProfileIssue(
        ProfileIssueSeverity.warning,
        'Pulses under 20 ms may be too weak on phones with older '
        '(ERM) vibration motors.',
        param: HapticTimingParam.dotDuration,
      ));
    }

    if (cellAnchorEnabled && anchorIntensity >= intensity * 0.8) {
      issues.add(const ProfileIssue(
        ProfileIssueSeverity.warning,
        'Cell anchor is nearly as strong as a dot and may be mistaken for one.',
      ));
    }

    return issues;
  }

  bool get isValid =>
      validate().every((i) => i.severity != ProfileIssueSeverity.error);

  HapticProfileModel copyWith({
    String? id,
    String? name,
    Duration? dotDuration,
    Duration? emptySlotDuration,
    Duration? intraCharPause,
    Duration? interCharPause,
    Duration? spacePause,
    double? intensity,
    double? sharpness,
    bool? cellAnchorEnabled,
    Duration? anchorDuration,
    double? anchorIntensity,
    double? anchorSharpness,
  }) =>
      HapticProfileModel(
        id: id ?? this.id,
        name: name ?? this.name,
        dotDuration: dotDuration ?? this.dotDuration,
        emptySlotDuration: emptySlotDuration ?? this.emptySlotDuration,
        intraCharPause: intraCharPause ?? this.intraCharPause,
        interCharPause: interCharPause ?? this.interCharPause,
        spacePause: spacePause ?? this.spacePause,
        intensity: intensity ?? this.intensity,
        sharpness: sharpness ?? this.sharpness,
        cellAnchorEnabled: cellAnchorEnabled ?? this.cellAnchorEnabled,
        anchorDuration: anchorDuration ?? this.anchorDuration,
        anchorIntensity: anchorIntensity ?? this.anchorIntensity,
        anchorSharpness: anchorSharpness ?? this.anchorSharpness,
      );

  /// Flat, versioned JSON with explicit units – stored as-is in Hive and
  /// readable by an external AI agent without any app-specific decoding.
  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'id': id,
        'name': name,
        for (final p in HapticTimingParam.values)
          p.jsonKey: valueOf(p).inMilliseconds,
        'intensity': intensity,
        'sharpness': sharpness,
        'cellAnchorEnabled': cellAnchorEnabled,
        'anchorDurationMs': anchorDuration.inMilliseconds,
        'anchorIntensity': anchorIntensity,
        'anchorSharpness': anchorSharpness,
      };

  /// Tolerant decoder: missing or malformed fields fall back to defaults.
  /// (Hive returns `Map<dynamic, dynamic>`; pass `Map<String, dynamic>.from(raw)`.)
  factory HapticProfileModel.fromJson(Map<String, dynamic> json) {
    const d = HapticProfileModel();
    Duration ms(String key, Duration fallback) => switch (json[key]) {
          final num v => Duration(milliseconds: v.round()),
          _ => fallback,
        };
    double unit(String key, double fallback) => switch (json[key]) {
          final num v => v.toDouble().clamp(0.0, 1.0),
          _ => fallback,
        };

    return HapticProfileModel(
      id: json['id'] as String? ?? d.id,
      name: json['name'] as String? ?? d.name,
      dotDuration: ms('dotDurationMs', d.dotDuration),
      emptySlotDuration: ms('emptySlotDurationMs', d.emptySlotDuration),
      intraCharPause: ms('intraCharPauseMs', d.intraCharPause),
      interCharPause: ms('interCharPauseMs', d.interCharPause),
      spacePause: ms('spacePauseMs', d.spacePause),
      intensity: unit('intensity', d.intensity),
      sharpness: unit('sharpness', d.sharpness),
      cellAnchorEnabled: json['cellAnchorEnabled'] as bool? ?? d.cellAnchorEnabled,
      anchorDuration: ms('anchorDurationMs', d.anchorDuration),
      anchorIntensity: unit('anchorIntensity', d.anchorIntensity),
      anchorSharpness: unit('anchorSharpness', d.anchorSharpness),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HapticProfileModel &&
      other.id == id &&
      other.name == name &&
      other.dotDuration == dotDuration &&
      other.emptySlotDuration == emptySlotDuration &&
      other.intraCharPause == intraCharPause &&
      other.interCharPause == interCharPause &&
      other.spacePause == spacePause &&
      other.intensity == intensity &&
      other.sharpness == sharpness &&
      other.cellAnchorEnabled == cellAnchorEnabled &&
      other.anchorDuration == anchorDuration &&
      other.anchorIntensity == anchorIntensity &&
      other.anchorSharpness == anchorSharpness;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        dotDuration,
        emptySlotDuration,
        intraCharPause,
        interCharPause,
        spacePause,
        intensity,
        sharpness,
        cellAnchorEnabled,
        anchorDuration,
        anchorIntensity,
        anchorSharpness,
      );

  @override
  String toString() => 'HapticProfileModel(${toJson()})';
}
