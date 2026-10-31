/// A single 6-dot Braille cell stored as a bitmask (bit 0 = dot 1 … bit 5 = dot 6).
///
/// Standard cell layout, and the order dots are played back in time:
///
///     1 ● ● 4
///     2 ● ● 5
///     3 ● ● 6
///
/// The bit layout matches the Unicode Braille block (U+2800), so [unicode]
/// is a free, exact visual rendering for sighted testers and debug UIs.
class BrailleCell {
  const BrailleCell(this.mask) : assert(mask >= 0 && mask <= 0x3F);

  /// Builds a cell from dot numbers, e.g. `BrailleCell.fromDots([1, 2, 5])`.
  factory BrailleCell.fromDots(Iterable<int> dots) {
    var mask = 0;
    for (final dot in dots) {
      if (dot < 1 || dot > dotCount) {
        throw ArgumentError.value(dot, 'dots', 'Braille dots must be 1-6');
      }
      mask |= 1 << (dot - 1);
    }
    return BrailleCell(mask);
  }

  /// Builds a cell from a compact dot string, e.g. `'256'` for a period.
  factory BrailleCell.parse(String dots) =>
      BrailleCell.fromDots(dots.split('').map(int.parse));

  static const int dotCount = 6;
  static const BrailleCell empty = BrailleCell(0);

  final int mask;

  /// [dot] is 1-based (1..6), matching Braille convention.
  bool isRaised(int dot) => isRaisedAt(dot - 1);

  /// [slot] is 0-based (0..5), matching temporal playback order.
  bool isRaisedAt(int slot) => mask & (1 << slot) != 0;

  /// The "6-dot array": dots 1..6 as booleans, in playback order.
  List<bool> get dots =>
      List<bool>.generate(dotCount, isRaisedAt, growable: false);

  /// Raised dot numbers, e.g. `[1, 2, 5]` for "h".
  List<int> get raisedDots => [
        for (var slot = 0; slot < dotCount; slot++)
          if (isRaisedAt(slot)) slot + 1,
      ];

  String get unicode => String.fromCharCode(0x2800 + mask);

  @override
  bool operator ==(Object other) => other is BrailleCell && other.mask == mask;

  @override
  int get hashCode => mask.hashCode;

  @override
  String toString() => 'BrailleCell($unicode dots:${raisedDots.join()})';
}

enum BrailleTokenKind { character, wordBreak }

/// One source character translated to one or more cells.
///
/// Indicators (capital, numeric, grade 1) are folded into the cells of the
/// character they modify, so "A" is a single token of two cells. That keeps
/// [sourceIndex] usable for highlighting, resuming and training feedback.
class BrailleToken {
  const BrailleToken({
    required this.kind,
    required this.cells,
    required this.sourceIndex,
    required this.source,
  });

  const BrailleToken.wordBreak(this.sourceIndex)
      : kind = BrailleTokenKind.wordBreak,
        cells = const [],
        source = ' ';

  final BrailleTokenKind kind;
  final List<BrailleCell> cells;

  /// Index into [BrailleDocument.text] (not necessarily the user's raw input,
  /// since an AI processor may have summarised or rewritten it).
  final int sourceIndex;
  final String source;

  bool get isWordBreak => kind == BrailleTokenKind.wordBreak;

  @override
  String toString() => isWordBreak
      ? 'BrailleToken(<space>)'
      : 'BrailleToken("$source" ${cells.map((c) => c.unicode).join()})';
}

/// Output of an [ITextProcessor]: the final text that will be felt, and its
/// Braille tokens.
class BrailleDocument {
  const BrailleDocument({
    required this.text,
    required this.tokens,
    this.unsupportedIndices = const [],
  });

  final String text;
  final List<BrailleToken> tokens;

  /// Positions in [text] that had no Braille mapping and were skipped.
  final List<int> unsupportedIndices;

  int get wordCount =>
      tokens.isEmpty ? 0 : tokens.where((t) => t.isWordBreak).length + 1;
}
