package com.tsorostudios.emberdelve

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the `emberdelve/haptics` channel (v0.3.4).
 *
 * Flutter's HapticFeedback maps to View.performHapticFeedback(), which the
 * system "touch feedback" setting silently disables on many devices (and apps
 * can't override that since Android 13). Driving the Vibrator service
 * directly — gated only by the normal VIBRATE permission — makes the in-game
 * Haptics toggle actually work everywhere.
 *
 * Method `vibrate {ms: int, amplitude: 1..255}` → true if a vibrator exists
 * and the one-shot was issued, false otherwise (caller falls back).
 */
class MainActivity : FlutterActivity() {
    private val vibrator: Vibrator? by lazy {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)
                ?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "emberdelve/haptics"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "vibrate" -> result.success(
                    vibrate(
                        (call.argument<Int>("ms") ?: 30).coerceIn(1, 500).toLong(),
                        (call.argument<Int>("amplitude") ?: 128).coerceIn(1, 255)
                    )
                )
                else -> result.notImplemented()
            }
        }
    }

    private fun vibrate(ms: Long, amplitude: Int): Boolean {
        val v = vibrator ?: return false
        if (!v.hasVibrator()) return false
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // Amplitude is ignored automatically on devices without
                // amplitude control.
                v.vibrate(VibrationEffect.createOneShot(ms, amplitude))
            } else {
                @Suppress("DEPRECATION")
                v.vibrate(ms)
            }
            true
        } catch (_: Exception) {
            false
        }
    }
}
