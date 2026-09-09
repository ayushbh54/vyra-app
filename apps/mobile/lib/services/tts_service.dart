import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Real-time Audio Coach TTS Service.
///
/// Communicates through native Android/iOS speech engines so athletes
/// hear form guidance, countdown cues, and motivational instructions
/// aloud through the device speaker without requiring external asset bundles.
class TtsService {
  static const MethodChannel _channel = MethodChannel('com.vyra.app/audio_coach');

  static Future<bool> speak(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return false;

    try {
      final res = await _channel.invokeMethod<bool>('speak', {'text': cleanText});
      return res ?? true;
    } on MissingPluginException {
      debugPrint('[TtsService] Native MethodChannel not registered on this platform.');
      return false;
    } catch (e) {
      debugPrint('[TtsService] Error speaking text: $e');
      return false;
    }
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
    } catch (e) {
      debugPrint('[TtsService] Error stopping speech: $e');
    }
  }
}
