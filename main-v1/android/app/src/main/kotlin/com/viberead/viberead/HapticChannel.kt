package com.viberead.viberead

import android.content.Context
import android.os.Build
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Native side of the "viberead/haptics" channel.
 *
 * Plays pre-timed waveforms produced by the Dart HapticTranslationEngine.
 * All timing math lives in Dart; this class only hands the arrays to the OS
 * in a single call, so the motor schedule is never affected by Dart/UI jank.
 *
 * Methods:
 *   getCapabilities -> {hasVibrator, hasAmplitudeControl, sdkInt}
 *   playWaveform {timings: List<int> ms, amplitudes: List<int> 0..255 | -1}
 *   cancel
 */
class HapticChannel(context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "viberead/haptics"
    }

    private val vibrator: Vibrator? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)
                ?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getCapabilities" -> result.success(
                mapOf(
                    "hasVibrator" to (vibrator?.hasVibrator() == true),
                    "hasAmplitudeControl" to hasAmplitudeControl(),
                    "sdkInt" to Build.VERSION.SDK_INT,
                )
            )

            "playWaveform" -> {
                val timings = call.argument<List<Number>>("timings")
                val amplitudes = call.argument<List<Number>>("amplitudes")
                if (timings == null || amplitudes == null ||
                    timings.isEmpty() || timings.size != amplitudes.size
                ) {
                    result.error("BAD_ARGS", "timings and amplitudes must be equal-length, non-empty lists", null)
                    return
                }
                val v = vibrator
                if (v == null || !v.hasVibrator()) {
                    result.error("NO_VIBRATOR", "This device has no vibration motor", null)
                    return
                }
                play(
                    v,
                    LongArray(timings.size) { timings[it].toLong() },
                    IntArray(amplitudes.size) { amplitudes[it].toInt() },
                )
                result.success(null)
            }

            "cancel" -> {
                vibrator?.cancel()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun hasAmplitudeControl(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && vibrator?.hasAmplitudeControl() == true

    private fun play(v: Vibrator, timings: LongArray, amplitudes: IntArray) {
        v.cancel()

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            @Suppress("DEPRECATION")
            v.vibrate(toLegacyPattern(timings, amplitudes), -1)
            return
        }

        val amps = if (v.hasAmplitudeControl()) {
            IntArray(amplitudes.size) { amplitudes[it].coerceIn(0, 255) }
        } else {
            IntArray(amplitudes.size) {
                if (amplitudes[it] == 0) 0 else VibrationEffect.DEFAULT_AMPLITUDE
            }
        }
        val effect = VibrationEffect.createWaveform(timings, amps, -1)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // Accessibility usage: not muted by the "touch feedback" setting.
            v.vibrate(effect, VibrationAttributes.createForUsage(VibrationAttributes.USAGE_ACCESSIBILITY))
        } else {
            v.vibrate(effect)
        }
    }

    /** Pre-API-26 patterns alternate off, on, off, on … starting with "off". */
    private fun toLegacyPattern(timings: LongArray, amplitudes: IntArray): LongArray {
        val pattern = mutableListOf(0L)
        var currentOn = false
        for (i in timings.indices) {
            val segmentOn = amplitudes[i] != 0
            if (segmentOn == currentOn) {
                pattern[pattern.lastIndex] += timings[i]
            } else {
                pattern.add(timings[i])
                currentOn = segmentOn
            }
        }
        return pattern.toLongArray()
    }
}
