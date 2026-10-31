import 'dart:convert';

import '../entities/training.dart';

class DailyStat {
  const DailyStat({
    required this.date,
    required this.attempts,
    required this.correct,
    required this.practiceMs,
    required this.wpm,
  });

  final DateTime date;
  final int attempts;
  final int correct;
  final int practiceMs;

  /// Words per minute read correctly that day (null if no letter/word work).
  final double? wpm;

  double get accuracy => attempts == 0 ? 0 : correct / attempts;

  Map<String, dynamic> toJson() => {
        'date': _ymd(date),
        'attempts': attempts,
        'correct': correct,
        'accuracy': double.parse(accuracy.toStringAsFixed(3)),
        'practiceMs': practiceMs,
        'wpm': wpm == null ? null : double.parse(wpm!.toStringAsFixed(2)),
      };
}

class ItemStat {
  const ItemStat(this.item, this.correct, this.total);

  final String item;
  final int correct;
  final int total;

  double get accuracy => total == 0 ? 0 : correct / total;
}

class AnalyticsSnapshot {
  const AnalyticsSnapshot({
    required this.totalAttempts,
    required this.totalCorrect,
    required this.currentStreak,
    required this.bestStreak,
    required this.totalPracticeMs,
    required this.recentWpm,
    required this.days,
    required this.letters,
    required this.levelAccuracy,
  });

  static const empty = AnalyticsSnapshot(
    totalAttempts: 0,
    totalCorrect: 0,
    currentStreak: 0,
    bestStreak: 0,
    totalPracticeMs: 0,
    recentWpm: null,
    days: [],
    letters: [],
    levelAccuracy: {},
  );

  final int totalAttempts;
  final int totalCorrect;
  final int currentStreak;
  final int bestStreak;
  final int totalPracticeMs;
  final double? recentWpm;

  /// One entry per calendar day with practice, oldest first.
  final List<DailyStat> days;

  /// Per-letter accuracy for level 2, a–z (only letters attempted).
  final List<ItemStat> letters;
  final Map<TrainingLevel, double> levelAccuracy;

  double get accuracy => totalAttempts == 0 ? 0 : totalCorrect / totalAttempts;

  bool get isEmpty => totalAttempts == 0;

  /// Letters below 70% accuracy with at least 3 tries, weakest first.
  List<ItemStat> get focusLetters => letters
      .where((l) => l.total >= 3 && l.accuracy < 0.7)
      .toList()
    ..sort((a, b) => a.accuracy.compareTo(b.accuracy));
}

/// Pure analytics over the attempt log.
class AnalyticsCalculator {
  const AnalyticsCalculator();

  AnalyticsSnapshot compute(List<TrainingAttempt> attempts, DateTime now) {
    if (attempts.isEmpty) return AnalyticsSnapshot.empty;

    final byDay = <DateTime, List<TrainingAttempt>>{};
    for (final a in attempts) {
      byDay.putIfAbsent(_day(a.timestamp), () => []).add(a);
    }
    final dayKeys = byDay.keys.toList()..sort();

    final days = [
      for (final d in dayKeys)
        DailyStat(
          date: d,
          attempts: byDay[d]!.length,
          correct: byDay[d]!.where((a) => a.correct).length,
          practiceMs: byDay[d]!
              .fold(0, (s, a) => s + a.playbackMs * (1 + a.replays) + a.responseMs),
          wpm: wordsPerMinute(byDay[d]!),
        ),
    ];

    final letterStats = <String, (int, int)>{};
    for (final a in attempts.where((a) => a.level == TrainingLevel.letters)) {
      final (c, t) = letterStats[a.target] ?? (0, 0);
      letterStats[a.target] = (c + (a.correct ? 1 : 0), t + 1);
    }
    final letters = [
      for (final l in letterStats.keys.toList()..sort())
        ItemStat(l, letterStats[l]!.$1, letterStats[l]!.$2),
    ];

    final levelAccuracy = <TrainingLevel, double>{
      for (final level in TrainingLevel.values)
        if (attempts.any((a) => a.level == level))
          level: attempts.where((a) => a.level == level && a.correct).length /
              attempts.where((a) => a.level == level).length,
    };

    final (current, best) = _streaks(dayKeys, _day(now));
    final last50 = attempts.length > 50
        ? attempts.sublist(attempts.length - 50)
        : attempts;

    return AnalyticsSnapshot(
      totalAttempts: attempts.length,
      totalCorrect: attempts.where((a) => a.correct).length,
      currentStreak: current,
      bestStreak: best,
      totalPracticeMs: days.fold(0, (s, d) => s + d.practiceMs),
      recentWpm: wordsPerMinute(last50),
      days: days,
      letters: letters,
      levelAccuracy: levelAccuracy,
    );
  }

  /// Reading speed: correctly recognised characters / 5, per minute of
  /// vibration felt. Reflects the speed setting the learner can decode at.
  double? wordsPerMinute(List<TrainingAttempt> attempts) {
    final reading =
        attempts.where((a) => a.level != TrainingLevel.dots).toList();
    final playbackMs = reading.fold(0, (s, a) => s + a.playbackMs);
    if (playbackMs == 0) return null;
    final correctChars = reading
        .where((a) => a.correct)
        .fold(0, (s, a) => s + a.target.length);
    return (correctChars / 5) / (playbackMs / 60000);
  }

  /// JSON an external AI agent can read to suggest speed adjustments.
  String exportJson(List<TrainingAttempt> attempts, DateTime now) {
    final s = compute(attempts, now);
    return const JsonEncoder.withIndent('  ').convert({
      'schemaVersion': 1,
      'generatedAt': now.toUtc().toIso8601String(),
      'summary': {
        'totalAttempts': s.totalAttempts,
        'accuracy': double.parse(s.accuracy.toStringAsFixed(3)),
        'currentStreakDays': s.currentStreak,
        'bestStreakDays': s.bestStreak,
        'totalPracticeMs': s.totalPracticeMs,
        'recentWpm': s.recentWpm == null
            ? null
            : double.parse(s.recentWpm!.toStringAsFixed(2)),
        'levelAccuracy': {
          for (final e in s.levelAccuracy.entries)
            e.key.name: double.parse(e.value.toStringAsFixed(3)),
        },
        'focusLetters': [for (final l in s.focusLetters) l.item],
      },
      'daily': [for (final d in s.days) d.toJson()],
      'attempts': [for (final a in attempts) a.toJson()],
    });
  }

  (int, int) _streaks(List<DateTime> sortedDays, DateTime today) {
    if (sortedDays.isEmpty) return (0, 0);
    var best = 1;
    var run = 1;
    for (var i = 1; i < sortedDays.length; i++) {
      run = _daysBetween(sortedDays[i - 1], sortedDays[i]) == 1 ? run + 1 : 1;
      if (run > best) best = run;
    }
    // The current streak survives until the end of the day after the last practice.
    final gap = _daysBetween(sortedDays.last, today);
    final current = gap <= 1 ? run : 0;
    return (current, best);
  }

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

  static int _daysBetween(DateTime a, DateTime b) =>
      DateTime.utc(b.year, b.month, b.day)
          .difference(DateTime.utc(a.year, a.month, a.day))
          .inDays;
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
