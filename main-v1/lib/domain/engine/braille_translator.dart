import '../entities/braille_cell.dart';
import '../services/i_text_processor.dart';

/// ASCII → Grade 1 (uncontracted) Unified English Braille.
///
/// Handles letters, digits (numeric mode), capitals (letter + word
/// indicators), and common punctuation. Non-ASCII characters are skipped and
/// reported in [BrailleDocument.unsupportedIndices].
///
/// NOTE: the punctuation table should be reviewed by a certified Braille
/// transcriber before release; a few UEB symbols are context-dependent.
class BrailleTranslator implements ITextProcessor {
  const BrailleTranslator();

  // Indicators.
  static final BrailleCell capitalIndicator = BrailleCell.parse('6');
  static final BrailleCell capitalTerminator = BrailleCell.parse('3');
  static final BrailleCell numericIndicator = BrailleCell.parse('3456');
  static final BrailleCell grade1Indicator = BrailleCell.parse('56');

  static final Map<String, BrailleCell> letters = {
    'a': BrailleCell.parse('1'),
    'b': BrailleCell.parse('12'),
    'c': BrailleCell.parse('14'),
    'd': BrailleCell.parse('145'),
    'e': BrailleCell.parse('15'),
    'f': BrailleCell.parse('124'),
    'g': BrailleCell.parse('1245'),
    'h': BrailleCell.parse('125'),
    'i': BrailleCell.parse('24'),
    'j': BrailleCell.parse('245'),
    'k': BrailleCell.parse('13'),
    'l': BrailleCell.parse('123'),
    'm': BrailleCell.parse('134'),
    'n': BrailleCell.parse('1345'),
    'o': BrailleCell.parse('135'),
    'p': BrailleCell.parse('1234'),
    'q': BrailleCell.parse('12345'),
    'r': BrailleCell.parse('1235'),
    's': BrailleCell.parse('234'),
    't': BrailleCell.parse('2345'),
    'u': BrailleCell.parse('136'),
    'v': BrailleCell.parse('1236'),
    'w': BrailleCell.parse('2456'),
    'x': BrailleCell.parse('1346'),
    'y': BrailleCell.parse('13456'),
    'z': BrailleCell.parse('1356'),
  };

  /// Digits reuse letters a–j and are preceded by [numericIndicator].
  static final Map<String, BrailleCell> digits = {
    '1': letters['a']!,
    '2': letters['b']!,
    '3': letters['c']!,
    '4': letters['d']!,
    '5': letters['e']!,
    '6': letters['f']!,
    '7': letters['g']!,
    '8': letters['h']!,
    '9': letters['i']!,
    '0': letters['j']!,
  };

  static List<BrailleCell> _cells(String spaced) =>
      spaced.split(' ').map(BrailleCell.parse).toList(growable: false);

  static final Map<String, List<BrailleCell>> punctuation = {
    ',': _cells('2'),
    ';': _cells('23'),
    ':': _cells('25'),
    '.': _cells('256'),
    '!': _cells('235'),
    '?': _cells('236'),
    "'": _cells('3'),
    '-': _cells('36'),
    '(': _cells('5 126'),
    ')': _cells('5 345'),
    '[': _cells('46 126'),
    ']': _cells('46 345'),
    '{': _cells('456 126'),
    '}': _cells('456 345'),
    '/': _cells('456 34'),
    '\\': _cells('456 16'),
    '@': _cells('4 1'),
    '&': _cells('4 12346'),
    '#': _cells('456 1456'),
    r'$': _cells('4 234'),
    '%': _cells('46 356'),
    '*': _cells('5 35'),
    '+': _cells('5 235'),
    '=': _cells('5 2356'),
    '<': _cells('4 126'),
    '>': _cells('4 345'),
    '_': _cells('46 36'),
  };

  static final List<BrailleCell> _openQuote = _cells('236');
  static final List<BrailleCell> _closeQuote = _cells('356');

  @override
  Future<BrailleDocument> process(String input) async => translate(input);

  BrailleDocument translate(String input) {
    final text = input.replaceAll('\r\n', '\n');
    final tokens = <BrailleToken>[];
    final unsupported = <int>[];

    var numericMode = false;
    var capsWordMode = false;
    var quoteOpen = false;

    for (var i = 0; i < text.length; i++) {
      final ch = text[i];

      if (_isWhitespace(ch)) {
        numericMode = false;
        capsWordMode = false;
        // Collapse runs of whitespace; never start with a break.
        if (tokens.isNotEmpty && !tokens.last.isWordBreak) {
          tokens.add(BrailleToken.wordBreak(i));
        }
        continue;
      }

      final cells = <BrailleCell>[];

      final digit = digits[ch];
      final lower = ch.toLowerCase();
      final letter = letters[lower];

      if (digit != null) {
        if (!numericMode) cells.add(numericIndicator);
        numericMode = true;
        cells.add(digit);
      } else if (letter != null) {
        // A letter a–j right after a digit would read as a digit.
        if (numericMode && digits.containsValue(letter)) {
          cells.add(grade1Indicator);
        }
        numericMode = false;

        final isUpper = ch != lower;
        if (isUpper && !capsWordMode) {
          if (_startsCapsWord(text, i)) {
            cells.addAll([capitalIndicator, capitalIndicator]);
            capsWordMode = true;
          } else {
            cells.add(capitalIndicator);
          }
        } else if (!isUpper && capsWordMode) {
          // e.g. "NASA's": lowercase after a capitalised word.
          cells.addAll([capitalIndicator, capitalTerminator]);
          capsWordMode = false;
        }
        cells.add(letter);
      } else if (ch == '"') {
        cells.addAll(quoteOpen ? _closeQuote : _openQuote);
        quoteOpen = !quoteOpen;
        numericMode = false;
      } else if (punctuation[ch] case final symbol?) {
        // Decimal point / thousands separator keep numeric mode alive.
        final continuesNumber = numericMode &&
            (ch == '.' || ch == ',') &&
            i + 1 < text.length &&
            digits.containsKey(text[i + 1]);
        if (!continuesNumber) numericMode = false;
        cells.addAll(symbol);
      } else {
        unsupported.add(i);
        continue;
      }

      tokens.add(BrailleToken(
        kind: BrailleTokenKind.character,
        cells: List.unmodifiable(cells),
        sourceIndex: i,
        source: ch,
      ));
    }

    if (tokens.isNotEmpty && tokens.last.isWordBreak) tokens.removeLast();

    return BrailleDocument(
      text: text,
      tokens: List.unmodifiable(tokens),
      unsupportedIndices: List.unmodifiable(unsupported),
    );
  }

  static bool _isWhitespace(String ch) =>
      ch == ' ' || ch == '\n' || ch == '\t' || ch == '\r';

  /// True if a run of ≥2 letters starting at [start] is entirely uppercase.
  static bool _startsCapsWord(String text, int start) {
    var length = 0;
    for (var j = start; j < text.length; j++) {
      final c = text[j];
      final lower = c.toLowerCase();
      if (!letters.containsKey(lower)) break;
      if (c == lower) return false;
      length++;
    }
    return length >= 2;
  }
}
