package com.example.camapp

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
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
                        startActivity(Intent(Intent.ACTION_DIAL, Uri.parse("tel:$number")))
                        result.success(true)
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

    /** Returns true if the call was placed, false if we only opened the dialer. */
    private fun placeCall(number: String): Boolean {
        val uri = Uri.parse("tel:$number")
        return if (hasCallPermission()) {
            startActivity(Intent(Intent.ACTION_CALL, uri))
            true
        } else {
            startActivity(Intent(Intent.ACTION_DIAL, uri))
            false
        }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        when (keyCode) {
            KeyEvent.KEYCODE_VOLUME_UP -> { events?.success("volume_up"); return true }
            KeyEvent.KEYCODE_VOLUME_DOWN -> { events?.success("volume_down"); return true }
        }
        return super.onKeyDown(keyCode, event)
    }

    // Also swallow the matching key-up so the system volume UI never shows.
    override fun onKeyUp(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_VOLUME_UP || keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) return true
        return super.onKeyUp(keyCode, event)
    }
}
