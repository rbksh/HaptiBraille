/**
 * Tactile Haptic Vibration Engine & Synthesizer
 * Supports:
 *  - Real device vibration via navigator.vibrate()
 *  - Fallback Web Audio API click/sub-bass synth so you can hear & test on PC/Mac/iOS!
 */

export class HapticEngine {
  constructor() {
    this.audioCtx = null;
    this.hasVibrate = typeof navigator !== 'undefined' && 'vibrate' in navigator;
    this.audioSimulate = true; // Provides audio clicks simultaneously so you can test on PC/desktop
    this.isCancelled = false;
  }

  initAudio() {
    if (!this.audioCtx) {
      const AudioContextClass = window.AudioContext || window.webkitAudioContext;
      if (AudioContextClass) {
        this.audioCtx = new AudioContextClass();
      }
    }
    if (this.audioCtx && this.audioCtx.state === 'suspended') {
      this.audioCtx.resume();
    }
  }

  /**
   * Triggers a tactile pulse for durationMs
   */
  pulse(durationMs, freq = 140) {
    if (this.isCancelled) return;

    // 1. Hardware vibration
    if (this.hasVibrate) {
      try {
        navigator.vibrate(durationMs);
      } catch (e) {
        console.warn('Vibration API blocked or failed:', e);
      }
    }

    // 2. Audio simulation (gives haptic "thump" feeling even on laptop/iPhone)
    if (this.audioSimulate && this.audioCtx) {
      try {
        const osc = this.audioCtx.createOscillator();
        const gain = this.audioCtx.createGain();

        osc.type = 'triangle';
        osc.frequency.setValueAtTime(freq, this.audioCtx.currentTime);

        const durSec = durationMs / 1000;
        gain.gain.setValueAtTime(0.7, this.audioCtx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.001, this.audioCtx.currentTime + durSec);

        osc.connect(gain);
        gain.connect(this.audioCtx.destination);

        osc.start();
        osc.stop(this.audioCtx.currentTime + durSec);
      } catch (err) {
        // Audio error ignore
      }
    }
  }

  cancel() {
    this.isCancelled = true;
    if (this.hasVibrate) {
      try {
        navigator.vibrate(0);
      } catch (e) {}
    }
  }

  reset() {
    this.isCancelled = false;
  }

  sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}
