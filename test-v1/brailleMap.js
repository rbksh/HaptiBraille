// Complete Standard Grade 1 Unified English Braille (UEB) Map
// 6-Dot Cell:
// [1] [4]
// [2] [5]
// [3] [6]

export const BRAILLE_MAP = {
  // Letters a-z
  'a': { dots: [1], unicode: '⠁' },
  'b': { dots: [1, 2], unicode: '⠃' },
  'c': { dots: [1, 4], unicode: '⠉' },
  'd': { dots: [1, 4, 5], unicode: '⠙' },
  'e': { dots: [1, 5], unicode: '⠑' },
  'f': { dots: [1, 2, 4], unicode: '⠋' },
  'g': { dots: [1, 2, 4, 5], unicode: '⠛' },
  'h': { dots: [1, 2, 5], unicode: '⠓' },
  'i': { dots: [2, 4], unicode: '⠊' },
  'j': { dots: [2, 4, 5], unicode: '⠚' },
  'k': { dots: [1, 3], unicode: '⠅' },
  'l': { dots: [1, 2, 3], unicode: '⠇' },
  'm': { dots: [1, 3, 4], unicode: '⠍' },
  'n': { dots: [1, 3, 4, 5], unicode: '⠝' },
  'o': { dots: [1, 3, 5], unicode: '⠕' },
  'p': { dots: [1, 2, 3, 4], unicode: '⠏' },
  'q': { dots: [1, 2, 3, 4, 5], unicode: '⠟' },
  'r': { dots: [1, 2, 3, 5], unicode: '⠗' },
  's': { dots: [2, 3, 4], unicode: '⠎' },
  't': { dots: [2, 3, 4, 5], unicode: '⠞' },
  'u': { dots: [1, 3, 6], unicode: '⠥' },
  'v': { dots: [1, 2, 3, 6], unicode: '⠧' },
  'w': { dots: [2, 4, 5, 6], unicode: '⠺' },
  'x': { dots: [1, 3, 4, 6], unicode: '⠭' },
  'y': { dots: [1, 3, 4, 5, 6], unicode: '⠽' },
  'z': { dots: [1, 3, 5, 6], unicode: '⠵' },

  // Numbers (Preceded by number sign in UEB, mapped directly for quick reference)
  '1': { dots: [1], unicode: '⠁' },
  '2': { dots: [1, 2], unicode: '⠃' },
  '3': { dots: [1, 4], unicode: '⠉' },
  '4': { dots: [1, 4, 5], unicode: '⠙' },
  '5': { dots: [1, 5], unicode: '⠑' },
  '6': { dots: [1, 2, 4], unicode: '⠋' },
  '7': { dots: [1, 2, 4, 5], unicode: '⠛' },
  '8': { dots: [1, 2, 5], unicode: '⠓' },
  '9': { dots: [2, 4], unicode: '⠊' },
  '0': { dots: [2, 4, 5], unicode: '⠚' },

  // Punctuation & Special
  ' ': { dots: [], unicode: '⠀' },
  '.': { dots: [2, 5, 6], unicode: '⠲' },
  ',': { dots: [2], unicode: '⠂' },
  '?': { dots: [2, 3, 6], unicode: '⠦' },
  '!': { dots: [2, 3, 5], unicode: '⠖' },
  ';': { dots: [2, 3], unicode: '⠆' },
  ':': { dots: [2, 5], unicode: '⠒' },
  '-': { dots: [3, 6], unicode: '⠤' },
  '\'': { dots: [3], unicode: '⠄' },
  '#': { dots: [3, 4, 5, 6], unicode: '⠼' }, // Number prefix
  '^': { dots: [6], unicode: '⠠' },          // Capital letter prefix
};

export const NUMBER_PREFIX = { dots: [3, 4, 5, 6], unicode: '⠼' };
export const CAPITAL_PREFIX = { dots: [6], unicode: '⠠' };

/**
 * Parses normal text into an array of Braille cell objects with prefix support
 */
export function textToBrailleCells(text) {
  const cells = [];
  let inNumberMode = false;

  for (let i = 0; i < text.length; i++) {
    const ch = text[i];

    if (ch === ' ') {
      inNumberMode = false;
      cells.push({ char: ' ', dots: [], unicode: '⠀', isSpace: true });
      continue;
    }

    // Number handling (in Braille, numbers are preceded by a number sign)
    if (ch >= '0' && ch <= '9') {
      if (!inNumberMode) {
        cells.push({ char: '#', dots: NUMBER_PREFIX.dots, unicode: NUMBER_PREFIX.unicode, isPrefix: true });
        inNumberMode = true;
      }
      const data = BRAILLE_MAP[ch] || { dots: [], unicode: '⠀' };
      cells.push({ char: ch, dots: data.dots, unicode: data.unicode });
      continue;
    }

    inNumberMode = false;

    // Capital letter prefix
    if (ch >= 'A' && ch <= 'Z') {
      cells.push({ char: 'CAP', dots: CAPITAL_PREFIX.dots, unicode: CAPITAL_PREFIX.unicode, isPrefix: true });
      const lower = ch.toLowerCase();
      const data = BRAILLE_MAP[lower] || { dots: [], unicode: '?' };
      cells.push({ char: ch, dots: data.dots, unicode: data.unicode });
      continue;
    }

    // Standard character or punctuation
    const lower = ch.toLowerCase();
    if (BRAILLE_MAP[lower]) {
      cells.push({ char: ch, dots: BRAILLE_MAP[lower].dots, unicode: BRAILLE_MAP[lower].unicode });
    } else {
      // Unknown fallback
      cells.push({ char: ch, dots: [], unicode: '⠿' });
    }
  }

  return cells;
}
