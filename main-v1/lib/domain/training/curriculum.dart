import 'dart:math';

import '../entities/braille_cell.dart';
import '../entities/training.dart';

/// Builds trials and decides progression. Pure logic, no Flutter.
class Curriculum {
  const Curriculum();

  /// A level unlocks when the previous one reaches this accuracy over its
  /// last [unlockWindow] attempts (with at least [unlockMinAttempts]).
  static const double unlockAccuracy = 0.8;
  static const int unlockMinAttempts = 10;
  static const int unlockWindow = 20;
  static const int sessionLength = 10;

  static const String alphabet = 'abcdefghijklmnopqrstuvwxyz';

  /// Common, unambiguous three-letter words.
  static const List<String> words = [
    'and', 'the', 'cat', 'dog', 'sun', 'hat', 'red', 'big', 'cup', 'bed',
    'run', 'fox', 'map', 'pen', 'box', 'sit', 'top', 'yes', 'zip', 'jam',
    'van', 'web', 'kid', 'leg', 'mud', 'nap', 'owl', 'pig', 'rat', 'six',
    'ten', 'use', 'wet', 'yak', 'zoo', 'ask', 'egg', 'ink', 'oak', 'arm',
    'bus', 'car', 'day', 'eat', 'fun', 'get', 'hot', 'ice', 'joy', 'key',
  ];

  List<TrainingAttempt> recent(TrainingLevel level, List<TrainingAttempt> all) {
    final forLevel = all.where((a) => a.level == level).toList();
    return forLevel.length <= unlockWindow
        ? forLevel
        : forLevel.sublist(forLevel.length - unlockWindow);
  }

  double? recentAccuracy(TrainingLevel level, List<TrainingAttempt> all) {
    final r = recent(level, all);
    if (r.isEmpty) return null;
    return r.where((a) => a.correct).length / r.length;
  }

  bool isMastered(TrainingLevel level, List<TrainingAttempt> all) {
    final r = recent(level, all);
    return r.length >= unlockMinAttempts &&
        r.where((a) => a.correct).length / r.length >= unlockAccuracy;
  }

  bool isUnlocked(TrainingLevel level, List<TrainingAttempt> all) {
    if (level == TrainingLevel.dots) return true;
    final previous = TrainingLevel.values[level.index - 1];
    return isMastered(previous, all) ||
        all.any((a) => a.level == level); // never re-lock once started
  }

  /// The level the learner should work on now.
  TrainingLevel currentLevel(List<TrainingAttempt> all) {
    var level = TrainingLevel.dots;
    while (isMastered(level, all) && level.next != null) {
      level = level.next!;
    }
    return level;
  }

  TrainingTrial nextTrial(
    TrainingLevel level,
    List<TrainingAttempt> history,
    Random random, {
    String? avoid,
  }) {
    switch (level) {
      case TrainingLevel.dots:
        String dot;
        do {
          dot = '${random.nextInt(6) + 1}';
        } while (dot == avoid);
        return TrainingTrial.cell(
          level: level,
          cell: BrailleCell.fromDots([int.parse(dot)]),
          answer: dot,
        );
      case TrainingLevel.letters:
        return TrainingTrial.text(
          level: level,
          text: _weightedPick(alphabet.split(''), level, history, random, avoid),
        );
      case TrainingLevel.words:
        return TrainingTrial.text(
          level: level,
          text: _weightedPick(words, level, history, random, avoid),
        );
    }
  }

  /// Adaptive practice: items the learner gets wrong come up more often.
  String _weightedPick(
    List<String> items,
    TrainingLevel level,
    List<TrainingAttempt> history,
    Random random,
    String? avoid,
  ) {
    final stats = <String, (int, int)>{};
    for (final a in history.where((a) => a.level == level)) {
      final (c, t) = stats[a.target] ?? (0, 0);
      stats[a.target] = (c + (a.correct ? 1 : 0), t + 1);
    }
    final candidates = items.where((i) => i != avoid).toList();
    final weights = [
      for (final item in candidates)
        switch (stats[item]) {
          null => 2.0, // unseen
          (final c, final t) => 1.0 + 3.0 * (1 - c / t),
        },
    ];
    var roll = random.nextDouble() * weights.fold(0.0, (a, b) => a + b);
    for (var i = 0; i < candidates.length; i++) {
      roll -= weights[i];
      if (roll <= 0) return candidates[i];
    }
    return candidates.last;
  }

  bool isCorrect(TrainingTrial trial, String response) =>
      AnswerParser.normalise(trial.level, response) == trial.answer;
}

/// Turns typed or spoken answers into canonical form.
class AnswerParser {
  const AnswerParser._();

  static const Map<String, String> _numberWords = {
    'one': '1', 'won': '1', 'two': '2', 'to': '2', 'too': '2',
    'three': '3', 'four': '4', 'for': '4', 'five': '5', 'six': '6',
  };

  /// How speech recognisers commonly transcribe spoken letter names.
  static const Map<String, String> _letterNames = {
    'ay': 'a', 'eh': 'a', 'hey': 'a', 'be': 'b', 'bee': 'b', 'see': 'c',
    'sea': 'c', 'dee': 'd', 'ee': 'e', 'ef': 'f', 'eff': 'f', 'gee': 'g',
    'jee': 'g', 'aitch': 'h', 'age': 'h', 'eye': 'i', 'aye': 'i', 'jay': 'j',
    'kay': 'k', 'okay': 'k', 'el': 'l', 'ell': 'l', 'em': 'm', 'en': 'n',
    'oh': 'o', 'owe': 'o', 'pee': 'p', 'pea': 'p', 'queue': 'q', 'cue': 'q',
    'are': 'r', 'ar': 'r', 'es': 's', 'ess': 's', 'tee': 't', 'tea': 't',
    'you': 'u', 'yew': 'u', 'vee': 'v', 'double you': 'w', 'doubleyou': 'w',
    'ex': 'x', 'why': 'y', 'zed': 'z', 'zee': 'z',
  };

  static String normalise(TrainingLevel level, String raw) {
    var s = raw.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9 ]'), '');
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    s = s.replaceFirst(RegExp(r'^(the )?(letter|dot|number|word) '), '');

    switch (level) {
      case TrainingLevel.dots:
        return _numberWords[s] ?? s;
      case TrainingLevel.letters:
        if (s.length == 1) return s;
        return _letterNames[s] ?? s;
      case TrainingLevel.words:
        return s.replaceAll(' ', '');
    }
  }
}
