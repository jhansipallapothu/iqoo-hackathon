package com.example.camapp

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
import android.net.Uri
import android.view.KeyEvent
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

// ponytail: while this app is foregrounded the volume rocker is the app's
// primary control (blind users find it by feel). Vol-Up = act, Vol-Down = repeat.
class MainActivity : FlutterActivity() {

    private var events: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "aiforall/hardware_keys")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink?) { events = sink }
                override fun onCancel(args: Any?) { events = null }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "aiforall/phone")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Direct dial: a blind user cannot reliably find and tap the
                    // dialer's call button, so ACTION_CALL rather than ACTION_DIAL.
                    // Dart side runs a cancellable countdown before calling this.
                    "call" -> {
                        val number = call.argument<String>("number")
                        if (number.isNullOrBlank()) {
                            result.error("no_number", "No number supplied", null)
                        } else {
                            result.success(placeCall(number))
                        }
                    }
                    // Falls back to the dialer, which needs no permission.
                    "dial" -> {
                        val number = call.argument<String>("number")
                        if (number.isNullOrBlank()) {
                            result.error("no_number", "No number supplied", null)
                        } else {
                            startActivity(
                                Intent(Intent.ACTION_DIAL, Uri.parse("tel:$number"))
                                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            )
                            result.success(true)
                        }
                    }
                    "hasCallPermission" -> result.success(hasCallPermission())
                    "requestCallPermission" -> {
                        ActivityCompat.requestPermissions(
                            this, arrayOf(Manifest.permission.CALL_PHONE), 4711
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun hasCallPermission() = ContextCompat.checkSelfPermission(
        this, Manifest.permission.CALL_PHONE
    ) == PackageManager.PERMISSION_GRANTED

    /**
     * Returns true only if an ACTION_CALL activity was actually started. If the
     * countdown finished while the app was backgrounded, Android silently blocks
     * the background activity start — catch that and return false so the Dart
     * side speaks its "open the dialler" fallback instead of a false success.
     */
    private fun placeCall(number: String): Boolean {
        val uri = Uri.parse("tel:$number")
        val flags = Intent.FLAG_ACTIVITY_NEW_TASK
        if (hasCallPermission()) {
            try {
                startActivity(Intent(Intent.ACTION_CALL, uri).addFlags(flags))
                return true
            } catch (e: Exception) {
                // fall through to the dialler
            }
        }
        return try {
            startActivity(Intent(Intent.ACTION_DIAL, uri).addFlags(flags))
            false
        } catch (e: Exception) {
            false
        }
    }

    private val audio by lazy { getSystemService(Context.AUDIO_SERVICE) as AudioManager }

    // No system volume UI (flag 0), but the media stream still moves — otherwise a
    // blind user whose media volume is muted has no way to hear the TTS output.
    private fun nudgeVolume(up: Boolean) = audio.adjustStreamVolume(
        AudioManager.STREAM_MUSIC,
        if (up) AudioManager.ADJUST_RAISE else AudioManager.ADJUST_LOWER,
        0
    )

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        when (keyCode) {
            KeyEvent.KEYCODE_VOLUME_UP, KeyEvent.KEYCODE_VOLUME_DOWN -> {
                val up = keyCode == KeyEvent.KEYCODE_VOLUME_UP
                nudgeVolume(up)
                // Fire the app action once per physical press, not on auto-repeat.
                if (event?.repeatCount == 0) {
                    events?.success(if (up) "volume_up" else "volume_down")
                }
                return true
            }
        }
        return super.onKeyDown(keyCode, event)
    }

    // Also swallow the matching key-up so the system volume UI never shows.
    override fun onKeyUp(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_VOLUME_UP || keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) return true
        return super.onKeyUp(keyCode, event)
    }
}
