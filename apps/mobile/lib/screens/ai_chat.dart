import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/client.dart';
import '../theme.dart';

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

  // Conversation ID returned by the backend, used for threading.
  String? _convId;

  @override
  void initState() {
    super.initState();
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
          setState(() {
            _messages.clear();
            _messages.addAll(list);
          });
          _scrollToBottom();
          return;
        }
      }
    } catch (_) {}

    // Initial realistic dummy chat conversation between user and Coach VYRA
    if (_messages.isEmpty) {
      final initialMessages = _getInitialSeedMessages();
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
        "Hey Ayush! 👋 I'm Coach VYRA, your AI-powered performance and clinical nutrition specialist.\n\n"
        "I reviewed your biometric sync: morning HRV readiness is elevated at 87%, and your 7-day workout streak is active! 🔥\n\n"
        "How is your body feeling today?",
        now.subtract(const Duration(minutes: 50)),
      ),
      _AiChatMessage(
        'user',
        "Completed 5km morning run in 24 mins! Felt great, but hamstrings feel a bit tight. What should I eat for optimal recovery right now?",
        now.subtract(const Duration(minutes: 45)),
      ),
      _AiChatMessage(
        'model',
        "Outstanding pace on that 5K! 24 mins is a solid 4:48/km cadence. 🏃‍♂️💨\n\n"
        "Here is your immediate recovery protocol:\n\n"
        "1. 🥤 Hydration: Drink 400–500ml water with a pinch of pink salt or coconut water to restore sodium and potassium lost in sweat.\n\n"
        "2. 🥗 3:1 Recovery Fuel (within 45 mins):\n"
        "   • 25g High-Bioavailability Protein + 40g Complex Carbs\n"
        "   • Ideal combos: Greek yogurt with sliced banana & chia seeds, or 2 boiled eggs / paneer bhurji with toasted whole wheat sourdough.\n\n"
        "3. 🧘 Hamstring Relief:\n"
        "   • Standing single-leg hamstring stretch (30s each side)\n"
        "   • Gentle downward dog hold (45s)\n"
        "   • Foam roll calves and glutes to relieve posterior chain tension.\n\n"
        "How is your resting heart rate today?",
        now.subtract(const Duration(minutes: 42)),
      ),
      _AiChatMessage(
        'user',
        "Resting HR was 62 bpm today, feeling energized! Can we target upper body and core tomorrow?",
        now.subtract(const Duration(minutes: 25)),
      ),
      _AiChatMessage(
        'model',
        "62 bpm resting HR confirms optimal recovery! 🎯\n\n"
        "Here is your customized Upper Body & Core target for tomorrow:\n"
        "• 3×10 Dumbbell Chest / Floor Press (controlled eccentric)\n"
        "• 3×12 Bodyweight Push-ups (focus on tempo: 2s down, 1s up)\n"
        "• 3×10 Seated Dumbbell Overhead Shoulder Press\n"
        "• 3×45s Forearm Plank holds + 3×20 Russian Twists\n\n"
        "Aim for 7.5+ hours of sleep tonight to maximize muscle protein synthesis. You've got this! 💪",
        now.subtract(const Duration(minutes: 20)),
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
          'Are you sure you want to reset your conversation with VYRA Coach?',
          style: TextStyle(color: VColor.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: VColor.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: VColor.warn),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_storageKey);
        await prefs.remove(_convStorageKey);
      } catch (_) {}
      setState(() {
        _convId = null;
        _messages.clear();
        _messages.add(_AiChatMessage(
          'model',
          "Chat reset! What would you like to focus on now? 🌟",
        ));
      });
      _saveHistory();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;
    _controller.clear();

    setState(() {
      _messages.add(_AiChatMessage('user', text));
      _loading = true;
      _error = null;
    });
    _saveHistory();
    _scrollToBottom();

    try {
      final api = context.read<VyraApi>();
      final resp = await api.chatMessage(text, conversationId: _convId);
      _convId = resp['conversationId'] as String?;
      final reply = resp['reply'] as String? ?? '...';
      setState(() => _messages.add(_AiChatMessage('model', reply)));
      _saveHistory();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _loading = false);
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
              Text('AI · Powered by Gemini', style: TextStyle(color: VColor.textLow, fontSize: 11)),
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
            '⚠️  AI coach is not a medical professional. For health concerns, consult your doctor.',
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

        // ── Quick suggestions row ──────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: Row(
            children: [
              _suggestionChip('🥗 Post-run recovery meal'),
              _suggestionChip('🔥 15m core & abs burn'),
              _suggestionChip('💧 Hydration target today'),
              _suggestionChip('🧘 Hamstring stretch routine'),
              _suggestionChip('😴 Deep sleep & muscle repair'),
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
                  hintText: 'Ask your coach anything…',
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
            const SizedBox(width: 8),
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

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 30, height: 30,
              margin: const EdgeInsets.only(right: 8, top: 2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: VColor.accentGlow,
              ),
              child: const Icon(Icons.auto_awesome, color: VColor.accentGreen, size: 16),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? VColor.accent.withValues(alpha: 0.15) : VColor.surfaceRaised,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                border: Border.all(
                  color: isUser ? VColor.accent.withValues(alpha: 0.3) : VColor.line,
                ),
              ),
              child: Column(
                crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.text,
                    style: const TextStyle(color: VColor.text, fontSize: 14, height: 1.45),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(msg.timestamp),
                    style: TextStyle(
                      color: isUser ? VColor.accent.withValues(alpha: 0.8) : VColor.textLow,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 38),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(
          width: 30, height: 30,
          margin: const EdgeInsets.only(right: 8),
          decoration: const BoxDecoration(shape: BoxShape.circle, color: VColor.accentGlow),
          child: const Icon(Icons.auto_awesome, color: VColor.accentGreen, size: 16),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: VColor.surfaceRaised,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: VColor.line),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            _Dot(delay: 0),
            SizedBox(width: 4),
            _Dot(delay: 200),
            SizedBox(width: 4),
            _Dot(delay: 400),
          ]),
        ),
      ]),
    );
  }
}

class _Dot extends StatefulWidget {
  const _Dot({required this.delay});
  final int delay;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
    _anim = Tween(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 6, height: 6,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: VColor.accentGreen),
      ),
    );
  }
}

class _ErrorBubble extends StatelessWidget {
  const _ErrorBubble(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: VColor.critSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VColor.crit.withValues(alpha: 0.3)),
      ),
      child: Text(message, style: const TextStyle(color: VColor.crit, fontSize: 13)),
    );
  }
}
