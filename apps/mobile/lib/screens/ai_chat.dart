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

    // Fallback welcome message if no history exists yet
    if (_messages.isEmpty) {
      setState(() {
        _messages.add(_AiChatMessage(
          'model',
          "Hey! I'm VYRA Coach, your AI-powered fitness and nutrition guide. "
          "Ask me anything — workouts, meals, recovery, or your goals. "
          "I'm not a doctor, so for medical questions always check with a professional. 💪",
        ));
      });
    }
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
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  const _Bubble(this.msg);
  final _AiChatMessage msg;

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
              child: Text(
                msg.text,
                style: const TextStyle(color: VColor.text, fontSize: 14, height: 1.45),
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
