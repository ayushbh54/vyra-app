package com.vyra.app

import android.os.Bundle
import android.speech.tts.TextToSpeech
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity(), TextToSpeech.OnInitListener {
    private val CHANNEL = "com.vyra.app/audio_coach"
    private var tts: TextToSpeech? = null
    private var ttsReady = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        try {
            // Using activity context ensures vendor service bindings connect properly
            tts = TextToSpeech(this, this)
        } catch (e: Exception) {
            e.printStackTrace()
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "speak" -> {
                    val text = call.argument<String>("text")
                    if (text != null && text.isNotBlank()) {
                        val params = Bundle().apply {
                            putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, 1.0f)
                            putInt(TextToSpeech.Engine.KEY_PARAM_STREAM, android.media.AudioManager.STREAM_MUSIC)
                        }
                        if (ttsReady && tts != null) {
                            tts?.speak(text, TextToSpeech.QUEUE_FLUSH, params, "audio_coach_cue_${System.currentTimeMillis()}")
                            result.success(true)
                        } else {
                            // Initialize and speak once ready
                            tts = TextToSpeech(this) { status ->
                                if (status == TextToSpeech.SUCCESS) {
                                    ttsReady = true
                                    applyTtsSettings()
                                    tts?.speak(text, TextToSpeech.QUEUE_FLUSH, params, "audio_coach_cue_${System.currentTimeMillis()}")
                                }
                            }
                            result.success(true)
                        }
                    } else {
                        result.error("INVALID_TEXT", "Spoken text cannot be null or blank", null)
                    }
                }
                "stop" -> {
                    try {
                        tts?.stop()
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                    result.success(true)
                }
                "isReady" -> {
                    result.success(ttsReady)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun applyTtsSettings() {
        val res = tts?.setLanguage(Locale.US)
        if (res == TextToSpeech.LANG_MISSING_DATA || res == TextToSpeech.LANG_NOT_SUPPORTED) {
            tts?.setLanguage(Locale.ENGLISH)
        }
        tts?.setSpeechRate(0.95f)
        tts?.setPitch(1.0f)
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            applyTtsSettings()
            ttsReady = true
        }
    }

    override fun onDestroy() {
        try {
            tts?.stop()
            tts?.shutdown()
        } catch (e: Exception) {
            e.printStackTrace()
        }
        super.onDestroy()
    }
}

