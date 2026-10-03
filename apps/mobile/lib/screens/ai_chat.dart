import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../api/client.dart';
import '../theme.dart';
import '../services/avatar_customization_service.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// VYRA AI COACH — Real-time conversational voice chat.
///
/// Features:
///  • Voice mode: tap 🎙 → speak → auto-sends → AI speaks reply back (GPT-style)
///  • Text mode: type as usual
///  • TTS (flutter_tts) reads every AI reply aloud in voice mode
///  • Animated mic with waveform rings while listening
///  • Animated "Coach is speaking…" indicator while TTS plays
///  • Voice mode toggle in AppBar
///  • Speech auto-detects silence → auto-sends (no manual send tap needed)
///  • Full health context sent with every message
/// ─────────────────────────────────────────────────────────────────────────────

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatMessage {
  final String role; // 'user' or 'model'
  final String text;
  final DateTime timestamp;
  _AiChatMessage(this.role, this.text, [DateTime? timestamp])
      : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'role': role,
        'text': text,
        'timestamp': timestamp.toIso8601String(),
      };

  factory _AiChatMessage.fromJson(Map<String, dynamic> json) => _AiChatMessage(
        json['role'] as String? ?? 'model',
        json['text'] as String? ?? '',
        json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp'] as String)
            : null,
      );
}

class _AiChatScreenState extends State<AiChatScreen>
    with TickerProviderStateMixin {
  static const _storageKey = 'vyra_chat_history_v1';
  static const _convStorageKey = 'vyra_chat_conv_id';

  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_AiChatMessage> _messages = [];
  bool _loading = false;
  String? _error;
  String? _convId;

  // ── Speech-to-Text ──────────────────────────────────────────────────────────
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechInitialized = false;
  String _interimText = ''; // live partial text while speaking

  // ── Text-to-Speech ──────────────────────────────────────────────────────────
  late FlutterTts _tts;
  bool _isSpeaking = false;

  // ── Voice Mode (auto send + auto TTS) ──────────────────────────────────────
  bool _voiceMode = false;

  // ── Mic animation ──────────────────────────────────────────────────────────
  late AnimationController _micPulse;
  late AnimationController _speakPulse;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initTts();
    _initSpeech();
    _loadHistory();

    _micPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _speakPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  // ── TTS init ────────────────────────────────────────────────────────────────
  Future<void> _initTts() async {
    _tts = FlutterTts();
    await _tts.setLanguage('en-IN'); // Indian English accent
    await _tts.setSpeechRate(0.48);  // natural conversational speed
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.05);

    _tts.setStartHandler(() {
      if (mounted) setState(() => _isSpeaking = true);
    });
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
      // In voice mode: after AI finishes speaking, auto-open mic
      if (_voiceMode && mounted) {
        Future.delayed(const Duration(milliseconds: 400), _startListening);
      }
    });
    _tts.setCancelHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  // ── STT init ────────────────────────────────────────────────────────────────
  Future<void> _initSpeech() async {
    _speechInitialized = await _speech.initialize(
      onError: (_) {
        if (mounted) setState(() => _isListening = false);
      },
      onStatus: (status) {
        if ((status == 'done' || status == 'notListening') && mounted) {
          if (_isListening) {
            setState(() => _isListening = false);
            // Auto-send in voice mode when speech ends
            if (_voiceMode && _controller.text.trim().isNotEmpty) {
              _send();
            }
          }
        }
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // HISTORY
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _convId = prefs.getString(_convStorageKey);
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List;
        final list = decoded
            .map((e) => _AiChatMessage.fromJson(e as Map<String, dynamic>))
            .toList();
        if (list.isNotEmpty) {
          if (!mounted) return;
          setState(() {
            _messages.clear();
            _messages.addAll(list);
          });
          _scrollToBottom();
          return;
        }
      }
    } catch (_) {}

    // First-time welcome message
    if (_messages.isEmpty) {
      setState(() {
        _messages.add(_AiChatMessage(
          'model',
          "👋 Hey! I'm VYRA Coach — your personal AI fitness and nutrition expert.\n\n"
          "Tap the 🎙 button and speak, or type your question below!\n\n"
          "You can ask me about exercises, diet, recovery, lab reports, or your smartwatch data. I know your health profile and will give you personalized advice. Let's go! 💪",
        ));
      });
      _saveHistory();
    }
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_convId != null) await prefs.setString(_convStorageKey, _convId!);
      await prefs.setString(
          _storageKey, jsonEncode(_messages.map((m) => m.toJson()).toList()));
    } catch (_) {}
  }

  Future<void> _clearChat() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    await prefs.remove(_convStorageKey);
    setState(() {
      _messages.clear();
      _convId = null;
    });
    _loadHistory();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // VOICE — LISTEN
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _startListening() async {
    if (_isSpeaking) { await _tts.stop(); }
    if (!_speechInitialized) { await _initSpeech(); }
    if (!_speechInitialized) {
      // Speech recognition unavailable (emulator or no mic permission)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.mic_off_rounded, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Microphone not available. Please type your message.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF2A2A3A),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        // Focus the text field so user can type
      }
      return;
    }

    setState(() {
      _isListening = true;
      _interimText = '';
      _controller.clear();
    });

    // ignore: deprecated_member_use
    await _speech.listen(
      // ignore: deprecated_member_use
      listenFor: const Duration(seconds: 30),
      // ignore: deprecated_member_use
      pauseFor: const Duration(seconds: 2), // auto-stop after 2s silence
      // ignore: deprecated_member_use
      partialResults: true,
      onResult: (val) {
        if (!mounted) return;
        setState(() {
          _interimText = val.recognizedWords;
          _controller.text = val.recognizedWords;
        });
        // Final result — auto-send in voice mode
        if (val.finalResult && _voiceMode && val.recognizedWords.trim().isNotEmpty) {
          setState(() => _isListening = false);
          _send();
        }
      },
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    if (mounted) setState(() => _isListening = false);
  }

  Future<void> _toggleMic() async {
    if (_isListening) {
      await _stopListening();
      if (_controller.text.trim().isNotEmpty) _send();
    } else {
      await _startListening();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // VOICE — SPEAK (TTS)
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _speakReply(String text) async {
    if (!_voiceMode) return;
    // Strip markdown symbols for cleaner speech
    final clean = text
        .replaceAll(RegExp(r'\*+'), '')
        .replaceAll(RegExp(r'#+\s?'), '')
        .replaceAll(RegExp(r'`+'), '')
        .replaceAll(RegExp(r'\n{2,}'), '. ')
        .replaceAll('\n', '. ')
        .trim();
    await _tts.speak(clean);
  }

  Future<void> _stopSpeaking() async {
    await _tts.stop();
    if (mounted) setState(() => _isSpeaking = false);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // SEND MESSAGE
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;
    // Capture context-dependent references BEFORE any awaits
    final api = context.read<VyraApi>();
    _controller.clear();
    _interimText = '';

    if (_isListening) {
      await _stopListening();
    }
    if (_isSpeaking) {
      await _stopSpeaking();
    }

    setState(() {
      _messages.add(_AiChatMessage('user', text));
      _loading = true;
      _error = null;
    });
    _saveHistory();
    _scrollToBottom();

    // Out-of-field guardrail
    if (_isOutOfField(text)) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      const reply = "THE QUESTION ASKED IS OUT OF MY FIELD, KINDLY ASK ME QUESTIONS RELATED TO HEALTH , FITNESS , SPORTS AND MEDICAL QUERIES. THANK YOU !";
      setState(() {
        _loading = false;
        _messages.add(_AiChatMessage('model', reply));
      });
      _saveHistory();
      _scrollToBottom();
      await _speakReply(reply);
      return;
    }

    try {
      final userCtx = await _buildUserContext();
      if (!mounted) return;
      final resp = await api.chatMessage(text, conversationId: _convId, userContext: userCtx);
      _convId = resp['conversationId'] as String?;
      final reply = resp['reply'] as String? ?? '...';

      _syncAvatarFromAiResponse(reply);

      if (mounted) {
        setState(() {
          _loading = false;
          _messages.add(_AiChatMessage('model', reply));
        });
        _saveHistory();
        _scrollToBottom();
        // Speak the reply in voice mode
        await _speakReply(reply);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 429) {
        setState(() {
          _loading = false;
          _messages.add(_AiChatMessage('model',
              "⚡ Coach VYRA is momentarily catching her breath! Please wait 15 seconds before asking your next question."));
        });
      } else {
        setState(() { _loading = false; _error = e.message; });
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = "Network connection issue. Please check your internet."; });
    } finally {
      _saveHistory();
      _scrollToBottom();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // OUT-OF-FIELD GUARD
  // ─────────────────────────────────────────────────────────────────────────────

  bool _isOutOfField(String query) {
    final q = query.toLowerCase().trim();
    final allowedSmallTalk = [
      'hi', 'hello', 'hey', 'good morning', 'good evening', 'who are you',
      'help', 'what can you do', 'thank you', 'thanks', 'bye'
    ];
    if (allowedSmallTalk.contains(q)) return false;
    final nonFitnessKeywords = [
      'python', 'javascript', 'coding', 'code', 'bug', 'github', 'java', 'c++', 'html',
      'president', 'election', 'movie', 'film', 'song', 'crypto', 'stock market', 'bitcoin',
      'weather forecast', 'translate', 'essay', 'homework', 'capital of'
    ];
    if (nonFitnessKeywords.any((kw) => q.contains(kw))) return true;
    final healthKeywords = [
      'health', 'fitness', 'sport', 'run', 'workout', 'diet', 'food', 'calorie', 'protein',
      'carb', 'fat', 'exercise', 'gym', 'muscle', 'recovery', 'sleep', 'water', 'hydrate',
      'hydration', 'heart', 'hrv', 'bpm', 'blood', 'report', 'lab', 'doctor', 'pain',
      'stretch', 'yoga', 'squat', 'pushup', 'curl', 'walk', 'step', 'weight', 'fat loss',
      'gain', 'bmi', 'sugar', 'glucose', 'cholesterol', 'vitamin', 'injury', 'cardio',
      'endurance', 'stamina', 'routine', 'plan', 'eat', 'meal', 'nutrition', 'sore',
      'chest', 'back', 'leg', 'arm', 'hamstring', 'glute', 'abs', 'core', 'training',
      'athlet', 'medical', 'fever', 'cough', 'energy', 'supplement', 'creatine',
      'kya', 'kaisa', 'kaise', 'mujhe', 'mera', 'mere', 'khana', 'vyayam', 'daud',
    ];
    if (!healthKeywords.any((kw) => q.contains(kw)) && q.split(' ').length > 2) return true;
    return false;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // USER CONTEXT
  // ─────────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _buildUserContext() async {
    final prefs = await SharedPreferences.getInstance();
    final ctx = <String, dynamic>{};
    ctx['name'] = prefs.getString('user_name') ?? prefs.getString('profile_name');
    ctx['age'] = prefs.getInt('user_age');
    ctx['gender'] = prefs.getString('user_gender');
    ctx['goal'] = prefs.getString('user_goal') ?? prefs.getString('fitnessGoal');
    ctx['fitnessLevel'] = prefs.getString('fitness_level') ?? prefs.getString('fitnessLevel');
    ctx['currentDiet'] = prefs.getString('diet_type') ?? prefs.getString('dietType');
    ctx['physicalConsiderations'] = prefs.getString('physical_considerations')
        ?? prefs.getString('physicalConsiderationDetails');

    final weight = prefs.getDouble('user_weight') ?? prefs.getInt('user_weight')?.toDouble();
    final height = prefs.getDouble('user_height') ?? prefs.getInt('user_height')?.toDouble();
    if (weight != null && height != null && height > 0) {
      final hm = height > 10 ? height / 100 : height;
      ctx['bmi'] = (weight / (hm * hm)).toStringAsFixed(1);
    }

    final bodyTypeRaw = prefs.getString('body_scan_result');
    if (bodyTypeRaw != null) {
      try {
        final d = jsonDecode(bodyTypeRaw) as Map<String, dynamic>;
        ctx['bodyType'] = d['bodyType'];
      } catch (_) {}
    }

    try {
      final labRaw = prefs.getString('latest_lab_markers');
      if (labRaw != null) ctx['labMarkers'] = jsonDecode(labRaw);
      final insRaw = prefs.getString('latest_lab_insights');
      if (insRaw != null) ctx['labInsights'] = jsonDecode(insRaw);
    } catch (_) {}

    final hr = prefs.getInt('live_heart_rate');
    final spo2 = prefs.getInt('live_spo2');
    final bp = prefs.getString('live_blood_pressure');
    final steps = prefs.getInt('live_steps');
    if (hr != null && hr > 0) ctx['watchHeartRate'] = hr;
    if (spo2 != null && spo2 > 0) ctx['watchSpo2'] = spo2;
    if (bp != null && bp != '--') ctx['watchBloodPressure'] = bp;
    if (steps != null) ctx['watchSteps'] = steps;

    try {
      final exRaw = prefs.getString('today_recommended_exercises');
      if (exRaw != null) ctx['recommendedExercises'] = jsonDecode(exRaw);
    } catch (_) {}

    ctx.removeWhere((_, v) => v == null);
    return ctx;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // AVATAR SYNC
  // ─────────────────────────────────────────────────────────────────────────────

  void _syncAvatarFromAiResponse(String reply) {
    final lower = reply.toLowerCase();
    const keywords = {
      'running': 'running', 'run ': 'running', 'jog': 'running', 'sprint': 'running',
      'squat': 'squat', 'squats': 'squat',
      'push-up': 'pushup', 'pushup': 'pushup', 'push up': 'pushup',
      'plank': 'plank', 'yoga': 'yoga',
      'cycling': 'cycling', 'cycle': 'cycling', 'bike': 'cycling',
      'boxing': 'boxing', 'punch': 'boxing',
      'swimming': 'swimming', 'swim': 'swimming',
      'weight': 'weightlifting', 'deadlift': 'weightlifting', 'bench': 'weightlifting',
      'dance': 'dancing', 'zumba': 'dancing',
      'football': 'football', 'soccer': 'football',
      'cricket': 'cricket',
      'skipping': 'skipping', 'jump rope': 'skipping', 'burpee': 'skipping',
    };
    for (final e in keywords.entries) {
      if (lower.contains(e.key)) {
        AvatarCustomizationService.instance.setActiveExercisePose(e.value);
        break;
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────────

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    _controller.dispose();
    _scrollCtrl.dispose();
    _micPulse.dispose();
    _speakPulse.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VColor.bg,
      appBar: AppBar(
        backgroundColor: VColor.surface,
        leading: const BackButton(color: VColor.text),
        title: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: VColor.accentGlow,
              border: Border.all(
                color: _voiceMode ? Colors.purpleAccent : VColor.accentGreen,
                width: 1.5,
              ),
            ),
            child: Icon(
              _voiceMode ? Icons.record_voice_over_rounded : Icons.auto_awesome,
              color: _voiceMode ? Colors.purpleAccent : VColor.accentGreen,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('VYRA Coach',
                  style: TextStyle(color: VColor.text, fontSize: 15, fontWeight: FontWeight.w600)),
              Text(
                _voiceMode ? '🎙 Voice Conversation Mode' : 'AI · Health & Fitness',
                style: TextStyle(
                  color: _voiceMode ? Colors.purpleAccent : VColor.textLow,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ]),
        actions: [
          // ── Voice Mode Toggle ──
          Tooltip(
            message: _voiceMode ? 'Switch to Text Mode' : 'Switch to Voice Mode',
            child: IconButton(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  _voiceMode ? Icons.chat_bubble_outline_rounded : Icons.record_voice_over_rounded,
                  key: ValueKey(_voiceMode),
                  color: _voiceMode ? Colors.purpleAccent : VColor.textMuted,
                  size: 22,
                ),
              ),
              onPressed: () async {
                if (_isSpeaking) await _stopSpeaking();
                if (_isListening) await _stopListening();
                setState(() => _voiceMode = !_voiceMode);
              },
            ),
          ),
          IconButton(
            tooltip: 'Clear Chat',
            icon: const Icon(Icons.delete_sweep_outlined, color: VColor.textMuted, size: 20),
            onPressed: _clearChat,
          ),
        ],
      ),
      body: Column(children: [
        // ── Disclaimer ──────────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          color: VColor.warnSoft,
          child: const Text(
            '⚠️  AI coach is not a medical professional. For clinical emergencies, consult a doctor.',
            style: TextStyle(color: VColor.warn, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ),

        // ── Messages ─────────────────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
            itemCount: _messages.length + (_loading ? 1 : 0) + (_error != null ? 1 : 0),
            itemBuilder: (ctx, i) {
              if (i < _messages.length) return _Bubble(_messages[i]);
              if (_loading && i == _messages.length) return const _TypingBubble();
              return _ErrorBubble(_error!);
            },
          ),
        ),

        // ── Coach is speaking indicator ──────────────────────────────────────
        if (_isSpeaking)
          AnimatedBuilder(
            animation: _speakPulse,
            builder: (_, __) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.purpleAccent.withValues(alpha: 0.10 + 0.06 * _speakPulse.value),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ...List.generate(5, (i) => _SoundBar(
                    delay: i * 0.15,
                    animation: _speakPulse,
                    color: Colors.purpleAccent,
                  )),
                  const SizedBox(width: 12),
                  const Text('Coach is speaking…',
                    style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.w600, fontSize: 12)),
                  const Spacer(),
                  GestureDetector(
                    onTap: _stopSpeaking,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.purpleAccent.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.stop_rounded, color: Colors.purpleAccent, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Listening indicator ──────────────────────────────────────────────
        if (_isListening)
          AnimatedBuilder(
            animation: _micPulse,
            builder: (_, __) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFF00D2FF).withValues(alpha: 0.10 + 0.07 * _micPulse.value),
              child: Row(
                children: [
                  // Animated mic rings
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 36 + 10 * _micPulse.value,
                        height: 36 + 10 * _micPulse.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF00D2FF).withValues(alpha: 0.3 + 0.4 * _micPulse.value),
                            width: 1.5,
                          ),
                        ),
                      ),
                      const Icon(Icons.mic_rounded, color: Color(0xFF00D2FF), size: 20),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _interimText.isEmpty ? 'Listening… speak now' : _interimText,
                      style: TextStyle(
                        color: _interimText.isEmpty
                            ? const Color(0xFF00D2FF)
                            : VColor.text,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () async {
                      await _stopListening();
                      if (_controller.text.trim().isNotEmpty) _send();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D2FF).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_rounded, color: Color(0xFF00D2FF), size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Quick suggestions ────────────────────────────────────────────────
        if (!_isListening && !_isSpeaking)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
            child: Row(
              children: [
                _chip('🥗 Recovery meal'),
                _chip('🔥 15m core burn'),
                _chip('💧 Hydration target'),
                _chip('🧘 Stretch routine'),
                _chip('😴 Sleep for muscle'),
                _chip('🏃 Best cardio today'),
              ],
            ),
          ),

        // ── Input row ────────────────────────────────────────────────────────
        Container(
          padding: EdgeInsets.only(
            left: 12, right: 8, top: 10,
            bottom: MediaQuery.of(context).viewInsets.bottom + 12,
          ),
          decoration: BoxDecoration(
            color: VColor.surface,
            border: const Border(top: BorderSide(color: VColor.line)),
            boxShadow: _voiceMode
                ? [BoxShadow(color: Colors.purpleAccent.withValues(alpha: 0.08), blurRadius: 12)]
                : [],
          ),
          child: _voiceMode
              ? _buildVoiceModeRow()
              : _buildTextModeRow(),
        ),
      ]),
    );
  }

  // ── Voice Mode Row — big mic button ─────────────────────────────────────────
  Widget _buildVoiceModeRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        // Big pulsing mic button
        GestureDetector(
          onTap: _isSpeaking ? _stopSpeaking : _toggleMic,
          child: AnimatedBuilder(
            animation: _micPulse,
            builder: (_, __) => Stack(
              alignment: Alignment.center,
              children: [
                if (_isListening)
                  Container(
                    width: 74 + 12 * _micPulse.value,
                    height: 74 + 12 * _micPulse.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF00D2FF).withValues(alpha: 0.12 * _micPulse.value),
                    ),
                  ),
                Container(
                  width: 70, height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: _isListening
                          ? [const Color(0xFF00D2FF), const Color(0xFF0052D4)]
                          : _isSpeaking
                              ? [Colors.purpleAccent, const Color(0xFF7B2FBE)]
                              : [VColor.accent, const Color(0xFF00A8CC)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_isListening ? const Color(0xFF00D2FF) : VColor.accent)
                            .withValues(alpha: 0.45),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isListening
                        ? Icons.mic_rounded
                        : _isSpeaking
                            ? Icons.stop_rounded
                            : Icons.mic_none_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isListening ? 'Listening…' : _isSpeaking ? 'Coach speaking…' : 'Tap to speak',
              style: TextStyle(
                color: _isListening ? const Color(0xFF00D2FF) : _isSpeaking ? Colors.purpleAccent : VColor.textMuted,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _isListening ? 'Auto-sends on silence' : _isSpeaking ? 'Tap mic to interrupt' : 'Voice conversation',
              style: const TextStyle(color: VColor.textLow, fontSize: 10),
            ),
          ],
        ),
        const Spacer(),
      ],
    );
  }

  // ── Text Mode Row ────────────────────────────────────────────────────────────
  Widget _buildTextModeRow() {
    return Row(children: [
      Expanded(
        child: TextField(
          controller: _controller,
          style: const TextStyle(color: VColor.text, fontSize: 14),
          maxLines: 4,
          minLines: 1,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: _isListening ? 'Listening...' : 'Ask your coach anything…',
            hintStyle: const TextStyle(color: VColor.textLow, fontSize: 14),
            filled: true,
            fillColor: VColor.surfaceRaised,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (_) => _send(),
        ),
      ),
      const SizedBox(width: 6),
      // Mic
      GestureDetector(
        onTap: _toggleMic,
        child: AnimatedBuilder(
          animation: _micPulse,
          builder: (_, __) => AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44, height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isListening ? const Color(0xFF00D2FF).withValues(alpha: 0.2) : VColor.surfaceRaised,
              border: Border.all(
                color: _isListening
                    ? Color.lerp(const Color(0xFF00D2FF), Colors.white, 0.3 * _micPulse.value)!
                    : const Color(0xFF00D2FF).withValues(alpha: 0.4),
              ),
            ),
            child: Icon(
              _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
              color: _isListening ? const Color(0xFF00D2FF) : VColor.textMuted,
              size: 20,
            ),
          ),
        ),
      ),
      const SizedBox(width: 6),
      // Send
      GestureDetector(
        onTap: _send,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44, height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _loading ? VColor.surfaceHigh : VColor.accent,
            boxShadow: _loading
                ? []
                : [const BoxShadow(color: VColor.accentGlow, blurRadius: 10, spreadRadius: 1)],
          ),
          child: Icon(
            _loading ? Icons.hourglass_empty_rounded : Icons.send_rounded,
            color: _loading ? VColor.textLow : VColor.textOnAccent,
            size: 20,
          ),
        ),
      ),
    ]);
  }

  Widget _chip(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        backgroundColor: VColor.surfaceRaised,
        side: const BorderSide(color: VColor.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        label: Text(label,
            style: const TextStyle(color: VColor.textMid, fontSize: 12, fontWeight: FontWeight.w600)),
        onPressed: _loading ? null : () {
          _controller.text = label;
          _send();
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sound bar widget (for speaking animation)
// ─────────────────────────────────────────────────────────────────────────────
class _SoundBar extends StatelessWidget {
  const _SoundBar({required this.delay, required this.animation, required this.color});
  final double delay;
  final Animation<double> animation;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final phase = (animation.value + delay) % 1.0;
    final h = 8.0 + 12.0 * (phase < 0.5 ? phase * 2 : (1 - phase) * 2);
    return Container(
      width: 3,
      height: h,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chat Bubble
// ─────────────────────────────────────────────────────────────────────────────
class _Bubble extends StatelessWidget {
  const _Bubble(this.msg);
  final _AiChatMessage msg;

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? VColor.accent : VColor.surfaceRaised,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: Border.all(color: isUser ? VColor.accent : VColor.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              msg.text,
              style: TextStyle(
                color: isUser ? VColor.textOnAccent : VColor.text,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                _fmt(msg.timestamp),
                style: TextStyle(
                  color: isUser
                      ? VColor.textOnAccent.withValues(alpha: 0.7)
                      : VColor.textLow,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Typing indicator
// ─────────────────────────────────────────────────────────────────────────────
class _TypingBubble extends StatelessWidget {
  const _TypingBubble();
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: VColor.surfaceRaised,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: VColor.line),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: VColor.accentGreen),
            ),
            SizedBox(width: 10),
            Text('Coach is thinking…',
                style: TextStyle(color: VColor.textMid, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error bubble
// ─────────────────────────────────────────────────────────────────────────────
class _ErrorBubble extends StatelessWidget {
  const _ErrorBubble(this.error);
  final String error;
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: VColor.warnSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: VColor.warn),
        ),
        child: Text('Error: $error',
            style: const TextStyle(color: VColor.warn, fontSize: 13)),
      ),
    );
  }
}
