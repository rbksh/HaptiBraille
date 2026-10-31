import { BRAILLE_MAP, textToBrailleCells } from './brailleMap.js';
import { HapticEngine } from './haptics.js';

// DOM Elements
const textInput = document.getElementById('text-input');
const playBtn = document.getElementById('play-btn');
const playBtnText = document.getElementById('play-btn-text');
const stopBtn = document.getElementById('stop-btn');
const micBtn = document.getElementById('mic-btn');
const activeCharEl = document.getElementById('active-char');
const activeUnicodeEl = document.getElementById('active-unicode');
const cellsStreamEl = document.getElementById('cells-stream');
const alphabetGridEl = document.getElementById('alphabet-grid');
const hapticStatusEl = document.getElementById('haptic-status');

// Settings Elements
const dotDurationSlider = document.getElementById('dot-duration-slider');
const dotDurationVal = document.getElementById('dot-duration-val');
const gapDurationSlider = document.getElementById('gap-duration-slider');
const gapDurationVal = document.getElementById('gap-duration-val');
const charPauseSlider = document.getElementById('char-pause-slider');
const charPauseVal = document.getElementById('char-pause-val');
const audioToggle = document.getElementById('audio-feedback-toggle');

// Dots NodeList
const dotElements = {
  1: document.querySelector('.dot[data-dot="1"]'),
  2: document.querySelector('.dot[data-dot="2"]'),
  3: document.querySelector('.dot[data-dot="3"]'),
  4: document.querySelector('.dot[data-dot="4"]'),
  5: document.querySelector('.dot[data-dot="5"]'),
  6: document.querySelector('.dot[data-dot="6"]'),
};

const engine = new HapticEngine();
let isPlaying = false;

// Check hardware vibration support
if (!engine.hasVibrate) {
  hapticStatusEl.textContent = 'Audio Thump Mode (No Device Motor)';
  hapticStatusEl.classList.remove('badge-active');
  hapticStatusEl.style.background = 'rgba(255, 170, 0, 0.15)';
  hapticStatusEl.style.color = '#ffaa00';
  hapticStatusEl.style.border = '1px solid rgba(255, 170, 0, 0.3)';
}

// ---------------------------------------------------------------------
// Timing Settings State
// ---------------------------------------------------------------------
let config = {
  dotDuration: parseInt(dotDurationSlider.value, 10),
  gapDuration: parseInt(gapDurationSlider.value, 10),
  charPause: parseInt(charPauseSlider.value, 10),
};

dotDurationSlider.addEventListener('input', (e) => {
  config.dotDuration = parseInt(e.target.value, 10);
  dotDurationVal.textContent = `${config.dotDuration}ms`;
});

gapDurationSlider.addEventListener('input', (e) => {
  config.gapDuration = parseInt(e.target.value, 10);
  gapDurationVal.textContent = `${config.gapDuration}ms`;
});

charPauseSlider.addEventListener('input', (e) => {
  config.charPause = parseInt(e.target.value, 10);
  charPauseVal.textContent = `${config.charPause}ms`;
});

audioToggle.addEventListener('change', (e) => {
  engine.audioSimulate = e.target.checked;
});

// ---------------------------------------------------------------------
// Visual Cell Updates
// ---------------------------------------------------------------------
function clearDotsVisual() {
  for (let i = 1; i <= 6; i++) {
    dotElements[i].classList.remove('active', 'raised');
  }
}

function setRaisedDots(dotsArray) {
  clearDotsVisual();
  dotsArray.forEach(dotNum => {
    if (dotElements[dotNum]) {
      dotElements[dotNum].classList.add('raised');
    }
  });
}

function highlightSingleDot(dotNum) {
  if (dotElements[dotNum]) {
    dotElements[dotNum].classList.add('active');
  }
}

function unhighlightSingleDot(dotNum) {
  if (dotElements[dotNum]) {
    dotElements[dotNum].classList.remove('active');
  }
}

// ---------------------------------------------------------------------
// Render Buffer Stream
// ---------------------------------------------------------------------
let parsedCells = [];

function updateBufferStream(cells) {
  cellsStreamEl.innerHTML = '';
  if (!cells || cells.length === 0) {
    cellsStreamEl.innerHTML = '<span class="stream-empty-hint">Type or speak below to start transmission...</span>';
    return;
  }

  cells.forEach((cell, idx) => {
    const badge = document.createElement('div');
    badge.className = 'stream-cell-badge';
    badge.id = `stream-badge-${idx}`;
    badge.innerHTML = `
      <span class="badge-char">${cell.char === ' ' ? '␣' : cell.char}</span>
      <span class="badge-braille">${cell.unicode}</span>
    `;
    cellsStreamEl.appendChild(badge);
  });
}

function highlightStreamBadge(index) {
  document.querySelectorAll('.stream-cell-badge').forEach(b => b.classList.remove('current'));
  const current = document.getElementById(`stream-badge-${index}`);
  if (current) {
    current.classList.add('current');
    current.scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'center' });
  }
}

// ---------------------------------------------------------------------
// Core Tactile Transmission Pipeline
// ---------------------------------------------------------------------
async function transmitCell(cell, index) {
  if (engine.isCancelled) return;

  activeCharEl.textContent = cell.char === ' ' ? 'SPACE' : cell.char;
  activeUnicodeEl.textContent = cell.unicode;
  highlightStreamBadge(index);
  setRaisedDots(cell.dots);

  if (cell.isSpace) {
    // Inter-word pause
    await engine.sleep(config.charPause * 1.5);
    return;
  }

  // Sequential 6-dot scan (Dots 1 -> 6)
  for (let dotNum = 1; dotNum <= 6; dotNum++) {
    if (engine.isCancelled) break;

    const isDotRaised = cell.dots.includes(dotNum);

    if (isDotRaised) {
      // Raised dot: Pulse motor and highlight on UI
      highlightSingleDot(dotNum);
      engine.pulse(config.dotDuration, 150 + dotNum * 20); // slightly varied pitch for audio simulation
      await engine.sleep(config.dotDuration);
      unhighlightSingleDot(dotNum);
    } else {
      // Empty dot: Brief sensory silence
      await engine.sleep(config.gapDuration);
    }

    // Interval between dots in same cell
    await engine.sleep(config.gapDuration);
  }

  // Inter-cell pause
  await engine.sleep(config.charPause);
}

async function startTransmission() {
  const text = textInput.value.trim();
  if (!text) return;

  engine.initAudio();
  engine.reset();
  isPlaying = true;

  playBtn.disabled = true;
  stopBtn.disabled = false;
  playBtnText.textContent = 'Transmitting...';

  parsedCells = textToBrailleCells(text);
  updateBufferStream(parsedCells);

  for (let i = 0; i < parsedCells.length; i++) {
    if (engine.isCancelled) break;
    await transmitCell(parsedCells[i], i);
  }

  stopTransmission();
}

function stopTransmission() {
  engine.cancel();
  isPlaying = false;
  playBtn.disabled = false;
  stopBtn.disabled = true;
  playBtnText.textContent = 'Transmit Tactile Pulses';
  activeCharEl.textContent = 'READY';
  activeUnicodeEl.textContent = '⠀';
  clearDotsVisual();
  document.querySelectorAll('.stream-cell-badge').forEach(b => b.classList.remove('current'));
}

// ---------------------------------------------------------------------
// Alphabet Practice Matrix
// ---------------------------------------------------------------------
function buildAlphabetGrid() {
  const letters = 'abcdefghijklmnopqrstuvwxyz'.split('');
  letters.forEach(letter => {
    const data = BRAILLE_MAP[letter];
    const key = document.createElement('div');
    key.className = 'alpha-key';
    key.innerHTML = `
      <span class="k-char">${letter.toUpperCase()}</span>
      <span class="k-braille">${data.unicode}</span>
    `;

    key.addEventListener('click', async () => {
      engine.initAudio();
      textInput.value = letter.toUpperCase();
      stopTransmission();
      parsedCells = textToBrailleCells(letter.toUpperCase());
      updateBufferStream(parsedCells);
      await transmitCell(parsedCells[0], 0);
      clearDotsVisual();
    });

    alphabetGridEl.appendChild(key);
  });
}

// ---------------------------------------------------------------------
// Presets
// ---------------------------------------------------------------------
document.querySelectorAll('.preset-chip').forEach(btn => {
  btn.addEventListener('click', () => {
    textInput.value = btn.dataset.text;
    parsedCells = textToBrailleCells(textInput.value);
    updateBufferStream(parsedCells);
    startTransmission();
  });
});

// ---------------------------------------------------------------------
// Speech-to-Text (Web Speech API)
// ---------------------------------------------------------------------
const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
if (SpeechRecognition) {
  const recognition = new SpeechRecognition();
  recognition.continuous = false;
  recognition.interimResults = false;
  recognition.lang = 'en-US';

  let isRecording = false;

  micBtn.addEventListener('click', () => {
    if (!isRecording) {
      try {
        recognition.start();
        micBtn.classList.add('recording');
        isRecording = true;
      } catch (err) {
        console.error('Mic start error:', err);
      }
    } else {
      recognition.stop();
      micBtn.classList.remove('recording');
      isRecording = false;
    }
  });

  recognition.onresult = (event) => {
    const transcript = event.results[0][0].transcript;
    textInput.value = transcript.toUpperCase();
    micBtn.classList.remove('recording');
    isRecording = false;
    startTransmission();
  };

  recognition.onerror = () => {
    micBtn.classList.remove('recording');
    isRecording = false;
  };

  recognition.onend = () => {
    micBtn.classList.remove('recording');
    isRecording = false;
  };
} else {
  micBtn.title = 'Speech-to-Text not supported on this browser';
  micBtn.style.opacity = '0.4';
}

// ---------------------------------------------------------------------
// Event Listeners
// ---------------------------------------------------------------------
playBtn.addEventListener('click', startTransmission);
stopBtn.addEventListener('click', stopTransmission);

textInput.addEventListener('input', () => {
  parsedCells = textToBrailleCells(textInput.value);
  updateBufferStream(parsedCells);
});

textInput.addEventListener('keypress', (e) => {
  if (e.key === 'Enter') {
    startTransmission();
  }
});

// Init
buildAlphabetGrid();
parsedCells = textToBrailleCells(textInput.value);
updateBufferStream(parsedCells);
