import 'braille_cell.dart';

enum TrainingLevel {
  dots(1, 'Single dots', 'Feel one dot and find where it sits in the cell.'),
  letters(2, 'Letters A–Z', 'Feel a letter, then type or say it.'),
  words(3, 'Three-letter words', 'Feel a short word, then type or say it.');

  const TrainingLevel(this.number, this.title, this.description);

  final int number;
  final String title;
  final String description;

  TrainingLevel? get next =>
      number < TrainingLevel.values.length ? TrainingLevel.values[number] : null;
}

/// One question in a training session.
class TrainingTrial {
  const TrainingTrial.cell({
    required this.level,
    required BrailleCell this.cell,
    required this.answer,
  }) : text = null;

  const TrainingTrial.text({
    required this.level,
    required String this.text,
  })  : cell = null,
        answer = text;

  final TrainingLevel level;

  /// Set for dot-level trials, which play a bare cell.
  final BrailleCell? cell;

  /// Set for letter/word trials, which go through the text processor.
  final String? text;

  /// Canonical correct response: a dot number "1".."6", a letter, or a word.
  final String answer;
}

/// One recorded answer. Stored as flat JSON so an external AI agent can read
/// the learning curve directly (see `AnalyticsCalculator.exportJson`).
class TrainingAttempt {
  const TrainingAttempt({
    required this.timestamp,
    required this.level,
    required this.target,
    required this.response,
    required this.correct,
    required this.responseMs,
    required this.playbackMs,
    required this.replays,
    required this.profileId,
    required this.dotDurationMs,
    required this.intraCharPauseMs,
    required this.interCharPauseMs,
  });

  final DateTime timestamp;
  final TrainingLevel level;
  final String target;
  final String response;
  final bool correct;

  /// Time from the end of the first playback to the answer.
  final int responseMs;

  /// Length of one playback of the target, used for reading-speed (WPM).
  final int playbackMs;
  final int replays;

  // Profile snapshot, so speed changes can be correlated with accuracy.
  final String profileId;
  final int dotDurationMs;
  final int intraCharPauseMs;
  final int interCharPauseMs;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toUtc().toIso8601String(),
        'level': level.name,
        'target': target,
        'response': response,
        'correct': correct,
        'responseMs': responseMs,
        'playbackMs': playbackMs,
        'replays': replays,
        'profileId': profileId,
        'dotDurationMs': dotDurationMs,
        'intraCharPauseMs': intraCharPauseMs,
        'interCharPauseMs': interCharPauseMs,
      };

  factory TrainingAttempt.fromJson(Map<String, dynamic> json) {
    int i(String k) => (json[k] as num?)?.round() ?? 0;
    return TrainingAttempt(
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      level: TrainingLevel.values.asNameMap()[json['level']] ?? TrainingLevel.dots,
      target: json['target'] as String? ?? '',
      response: json['response'] as String? ?? '',
      correct: json['correct'] as bool? ?? false,
      responseMs: i('responseMs'),
      playbackMs: i('playbackMs'),
      replays: i('replays'),
      profileId: json['profileId'] as String? ?? 'unknown',
      dotDurationMs: i('dotDurationMs'),
      intraCharPauseMs: i('intraCharPauseMs'),
      interCharPauseMs: i('interCharPauseMs'),
    );
  }
}
