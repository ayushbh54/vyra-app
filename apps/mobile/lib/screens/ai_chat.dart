import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../api/client.dart';
import '../theme.dart';
import '../services/avatar_customization_service.dart';


/// AI COACH CHAT — powered by Gemini.
///
/// A conversational interface where the athlete can ask anything about
/// fitness, nutrition, recovery, or their VYRA data. Every response carries
/// a disclaimer that this is not medical advice.
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

class _AiChatScreenState extends State<AiChatScreen> {
  static const _storageKey = 'vyra_chat_history_v1';
  static const _convStorageKey = 'vyra_chat_conv_id';

  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_AiChatMessage> _messages = [];
  bool _loading = false;
  String? _error;

  late stt.SpeechToText _speech;
  bool _isListening = false;

  // Conversation ID returned by the backend, used for threading.
  String? _convId;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _loadHistory();
  }

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

    if (_messages.isEmpty) {
      final initialMessages = _getInitialSeedMessages();
      if (!mounted) return;
      setState(() {
        _messages.addAll(initialMessages);
      });
      
      _saveHistory();
      _scrollToBottom();
    }
  }

  List<_AiChatMessage> _getInitialSeedMessages() {
    final now = DateTime.now();
    return [
      _AiChatMessage(
        'model',
        "Hey Athlete! 👋 I'm Coach VYRA, your AI-powered performance and clinical nutrition specialist.\n\n"
        "How is your body feeling today? Ask me anything about your training, diet, recovery, or medical wellness.",
        now.subtract(const Duration(minutes: 5)),
      ),
    ];
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(_messages.map((m) => m.toJson()).toList());
      await prefs.setString(_storageKey, raw);
      if (_convId != null) {
        await prefs.setString(_convStorageKey, _convId!);
      }
    } catch (_) {}
  }

  Future<void> _clearChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VColor.surface,
        title: const Text('Clear Chat History?', style: TextStyle(color: VColor.text)),
        content: const Text(
          'This will delete all messages in this conversation. This cannot be undone.',
          style: TextStyle(color: VColor.textMid),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: VColor.textLow)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear', style: TextStyle(color: VColor.warn)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      setState(() {
        _messages.clear();
        _error = null;
        _convId = null;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      await prefs.remove(_convStorageKey);
    }
  }

  Future<void> _listen() async {
    if (!_isListening) {
      try {
        final available = await _speech.initialize(
          onError: (_) {
            if (mounted) setState(() => _isListening = false);
          },
          onStatus: (val) {
            if (val == 'done' || val == 'notListening') {
              if (mounted) setState(() => _isListening = false);
            }
          },
        );
        if (available) {
          setState(() => _isListening = true);
          _speech.listen(
            onResult: (val) {
              if (mounted) {
                setState(() {
                  _controller.text = val.recognizedWords;
                });
              }
            },
          );
        }
      } catch (_) {
        if (mounted) setState(() => _isListening = false);
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

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

    if (nonFitnessKeywords.any((kw) => q.contains(kw))) {
      return true;
    }

    final healthKeywords = [
      'health', 'fitness', 'sport', 'run', 'workout', 'diet', 'food', 'calorie', 'protein',
      'carb', 'fat', 'exercise', 'gym', 'muscle', 'recovery', 'sleep', 'water', 'hydrate',
      'hydration', 'heart', 'hrv', 'bpm', 'blood', 'report', 'lab', 'doctor', 'pain',
      'stretch', 'yoga', 'squat', 'pushup', 'curl', 'walk', 'step', 'weight', 'fat loss',
      'gain', 'bmi', 'sugar', 'glucose', 'cholesterol', 'vitamin', 'injury', 'cardio',
      'endurance', 'stamina', 'routine', 'plan', 'eat', 'meal', 'nutrition', 'sore',
      'chest', 'back', 'leg', 'arm', 'hamstring', 'glute', 'abs', 'core', 'training',
      'athlet', 'medical', 'fever', 'cough', 'energy', 'supplement', 'creatine'
    ];

    final hasHealthContext = healthKeywords.any((kw) => q.contains(kw));
    // If it mentions neither fitness nor allowed small talk, and has more than 3 words, guardrail it
    if (!hasHealthContext && q.split(' ').length > 2) {
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    _speech.stop();
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;
    _controller.clear();

    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
    }

    setState(() {
      _messages.add(_AiChatMessage('user', text));
      _loading = true;
      _error = null;
    });
    
      _saveHistory();
    _scrollToBottom();

    // Out-of-field check
    if (_isOutOfField(text)) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      setState(() {
        _loading = false;
        _messages.add(
          _AiChatMessage(
            'model',
            "THE QUESTION ASKED IS OUT OF MY FIELD, KINDLY ASK ME QUESTIONS RELATED TO HEALTH , FITNESS , SPORTS AND MEDICAL QUERIES. THANK YOU !",
          ),
        );
      });
      
      _saveHistory();
      _scrollToBottom();
      return;
    }

    try {
      final api = context.read<VyraApi>();
      final resp = await api.chatMessage(text, conversationId: _convId);
      _convId = resp['conversationId'] as String?;
      final reply = resp['reply'] as String? ?? '...';
      _syncAvatarFromAiResponse(reply);
      if (mounted) {
        setState(() => _messages.add(_AiChatMessage('model', reply)));
      }
      
      _saveHistory();
    } on ApiException catch (e) {
      if (mounted) {
        if (e.statusCode == 429) {
          setState(() {
            _messages.add(
              _AiChatMessage(
                'model',
                "⚡ Coach VYRA is momentarily catching her breath! Please wait 15 seconds before asking your next question.",
              ),
            );
          });
        } else {
          setState(() => _error = e.message);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = "Network connection issue. Please check your internet.");
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
      
      _saveHistory();
      _scrollToBottom();
    }
  }

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
              border: Border.all(color: VColor.accentGreen, width: 1.5),
            ),
            child: const Icon(Icons.auto_awesome, color: VColor.accentGreen, size: 18),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('VYRA Coach', style: TextStyle(color: VColor.text, fontSize: 15, fontWeight: FontWeight.w600)),
              Text('AI · Health & Fitness Specialist', style: TextStyle(color: VColor.textLow, fontSize: 11)),
            ],
          ),
        ]),
        actions: [
          IconButton(
            tooltip: 'Clear Chat',
            icon: const Icon(Icons.delete_sweep_outlined, color: VColor.textMuted, size: 20),
            onPressed: _clearChat,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: VColor.accentGreenGlow,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: VColor.accentGreen.withValues(alpha: 0.4)),
              ),
              child: const Text('LIVE', style: TextStyle(color: VColor.accentGreen, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ),
        ],
      ),
      body: Column(children: [
        // ── Disclaimer banner ──────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          color: VColor.warnSoft,
          child: const Text(
            '⚠️  AI coach is not a medical professional. For clinical emergencies, consult a doctor immediately.',
            style: TextStyle(color: VColor.warn, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ),

        // ── Message list ───────────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
            itemCount: _messages.length + (_loading ? 1 : 0) + (_error != null ? 1 : 0),
            itemBuilder: (ctx, i) {
              if (i < _messages.length) {
                return _Bubble(_messages[i]);
              }
              if (_loading && i == _messages.length) {
                return const _TypingBubble();
              }
              return _ErrorBubble(_error!);
            },
          ),
        ),

        // ── Voice Listening Indicator ──────────────────────────────────────
        if (_isListening)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF00D2FF).withValues(alpha: 0.15),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mic_rounded, color: Color(0xFF00D2FF), size: 18),
                SizedBox(width: 8),
                Text(
                  "Listening... Speak your fitness or nutrition question",
                  style: TextStyle(color: Color(0xFF00D2FF), fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ],
            ),
          ),

        // ── Quick suggestions row ──────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: Row(
            children: [
              _suggestionChip('🥗 Post-workout recovery meal'),
              _suggestionChip('🔥 15m core & abs burn'),
              _suggestionChip('💧 Hydration target today'),
              _suggestionChip('🧘 Hamstring stretch routine'),
              _suggestionChip('😴 Sleep for muscle repair'),
            ],
          ),
        ),

        // ── Input row ──────────────────────────────────────────────────────
        Container(
          padding: EdgeInsets.only(
            left: 12, right: 8, top: 10,
            bottom: MediaQuery.of(context).viewInsets.bottom + 12,
          ),
          decoration: const BoxDecoration(
            color: VColor.surface,
            border: Border(top: BorderSide(color: VColor.line)),
          ),
          child: Row(children: [
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

            // Microphone speech-to-text button
            GestureDetector(
              onTap: _listen,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44, height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isListening ? Colors.redAccent : VColor.surfaceRaised,
                  border: Border.all(
                    color: _isListening ? Colors.red : const Color(0xFF00D2FF).withValues(alpha: 0.4),
                  ),
                ),
                child: Icon(
                  _isListening ? Icons.mic_off_rounded : Icons.mic_rounded,
                  color: _isListening ? Colors.white : const Color(0xFF00D2FF),
                  size: 20,
                ),
              ),
            ),

            const SizedBox(width: 6),

            // Send button
            GestureDetector(
              onTap: _send,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44, height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _loading ? VColor.surfaceHigh : VColor.accent,
                  boxShadow: _loading ? [] : [const BoxShadow(color: VColor.accentGlow, blurRadius: 10, spreadRadius: 1)],
                ),
                child: Icon(
                  _loading ? Icons.hourglass_empty_rounded : Icons.send_rounded,
                  color: _loading ? VColor.textLow : VColor.textOnAccent,
                  size: 20,
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  void _syncAvatarFromAiResponse(String aiResponse) {
    final lower = aiResponse.toLowerCase();
    
    final exerciseKeywords = {
      'running': 'running', 'run ': 'running', 'jog': 'running', 'sprint': 'running',
      'squat': 'squat', 'squats': 'squat',
      'push-up': 'pushup', 'pushup': 'pushup', 'push up': 'pushup',
      'plank': 'plank',
      'yoga': 'yoga',
      'cycling': 'cycling', 'cycle': 'cycling', 'bike': 'cycling',
      'boxing': 'boxing', 'punch': 'boxing',
      'swimming': 'swimming', 'swim': 'swimming',
      'weight': 'weightlifting', 'deadlift': 'weightlifting', 'bench': 'weightlifting',
      'dance': 'dancing', 'zumba': 'dancing',
      'football': 'football', 'soccer': 'football',
      'cricket': 'cricket',
      'skipping': 'skipping', 'jump rope': 'skipping', 'burpee': 'skipping',
    };
    
    for (final entry in exerciseKeywords.entries) {
      if (lower.contains(entry.key)) {
        AvatarCustomizationService.instance.setActiveExercisePose(entry.value);
        break;
      }
    }
  }

  Widget _suggestionChip(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        backgroundColor: VColor.surfaceRaised,
        side: const BorderSide(color: VColor.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        label: Text(
          label,
          style: const TextStyle(color: VColor.textMid, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        onPressed: _loading
            ? null
            : () {
                _controller.text = label;
                _send();
              },
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

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
                _formatTime(msg.timestamp),
                style: TextStyle(
                  color: isUser ? VColor.textOnAccent.withValues(alpha: 0.7) : VColor.textLow,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

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
            Text('Coach is thinking…', style: TextStyle(color: VColor.textMid, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

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
        child: Text(
          'Error: $error',
          style: const TextStyle(color: VColor.warn, fontSize: 13),
        ),
      ),
    );
  }
}
