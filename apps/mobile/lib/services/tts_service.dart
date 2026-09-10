import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Real-time Audio Coach TTS Service.
///
/// Communicates through flutter_tts so athletes hear spoken form guidance,
/// countdown cues, and biomechanical audio instructions aloud through the device speaker.
class TtsService {
  static final FlutterTts _flutterTts = FlutterTts();
  static bool _isInitialized = false;

  static Future<void> _init() async {
    if (_isInitialized) return;
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.48); // Natural athletic audio coach cadence
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      
      if (!kIsWeb) {
        await _flutterTts.awaitSynthCompletion(true);
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('[TtsService] Error initializing TTS: $e');
    }
  }

  /// Speaks the provided audio coach script. Returns true if speech commenced successfully.
  static Future<bool> speak(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return false;

    try {
      await _init();
      await _flutterTts.stop();
      final result = await _flutterTts.speak(cleanText);
      return result == 1;
    } catch (e) {
      debugPrint('[TtsService] Error speaking text: $e');
      return false;
    }
  }

  /// Stops ongoing voice synthesis.
  static Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (e) {
      debugPrint('[TtsService] Error stopping speech: $e');
    }
  }
}

