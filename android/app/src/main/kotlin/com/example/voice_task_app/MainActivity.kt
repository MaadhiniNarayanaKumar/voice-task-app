package com.example.voice_task_app

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "mia/intents"
    private var pendingText: String? = null
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel?.setMethodCallHandler { call, result ->
            if (call.method == "getPending") {
                result.success(pendingText)
                pendingText = null
            } else {
                result.notImplemented()
            }
        }
        deliverPending()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        captureIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureIntent(intent)
        deliverPending()
    }

    private fun captureIntent(intent: Intent?) {
        if (intent == null) return
        val fromExtra = intent.getStringExtra("task")
            ?: intent.getStringExtra(Intent.EXTRA_TEXT)
        val fromUri = intent.data?.getQueryParameter("text")
        val text = listOfNotNull(fromExtra, fromUri)
            .firstOrNull { it.isNotBlank() }
        if (text != null) {
            pendingText = text
        }
    }

    private fun deliverPending() {
        val text = pendingText ?: return
        if (channel == null) return
        channel?.invokeMethod("addTask", text)
        pendingText = null
    }
}
