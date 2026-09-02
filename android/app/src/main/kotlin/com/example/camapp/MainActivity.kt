package com.example.camapp

import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

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
