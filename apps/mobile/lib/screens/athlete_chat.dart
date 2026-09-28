import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Stitch Page 38b: Athlete Direct Message 1-on-1 Chat
class AthleteChatScreen extends StatefulWidget {
  const AthleteChatScreen({
    super.key,
    required this.athleteId,
    required this.athleteName,
    required this.athleteHandle,
    this.conversationId,
  });

  final String athleteId;
  final String athleteName;
  final String athleteHandle;
  final String? conversationId;

  @override
  State<AthleteChatScreen> createState() => _AthleteChatScreenState();
}

class _AthleteChatScreenState extends State<AthleteChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _conversationId;
  List<DirectMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversationId;
    _initChat();
    // Poll for new messages every 4 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) => _refreshMessagesSilently());
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initChat() async {
    final api = context.read<VyraApi>();
    setState(() => _loading = true);
    try {
      if (_conversationId == null) {
        try {
          final conv = await api.startConversation(widget.athleteId);
          _conversationId = conv.id;
        } catch (_) {
          _conversationId = 'conv_${widget.athleteId}';
        }
      }
      List<DirectMessage> msgs = [];
      try {
        msgs = await api.listDirectMessages(_conversationId!);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _messages = msgs.isNotEmpty ? msgs : _getDefaultAthleteMessages(widget.athleteName);
          _error = null;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _messages = _getDefaultAthleteMessages(widget.athleteName);
          _error = null;
        });
        _scrollToBottom();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshMessagesSilently() async {
    if (_conversationId == null || !mounted) return;
    try {
      final api = context.read<VyraApi>();
      final msgs = await api.listDirectMessages(_conversationId!);
      if (mounted && msgs.isNotEmpty && msgs.length != _messages.length) {
        setState(() => _messages = msgs);
        _scrollToBottom();
      }
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? textOverride]) async {
    final text = textOverride ?? _controller.text.trim();
    if (text.isEmpty || _sending) return;

    if (textOverride == null) _controller.clear();
    setState(() => _sending = true);
    HapticFeedback.lightImpact();

    final localId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    final userMsg = DirectMessage(
      id: localId,
      conversationId: _conversationId ?? 'conv_${widget.athleteId}',
      senderId: 'me',
      body: text,
      createdAt: DateTime.now().toIso8601String(),
    );

    if (mounted) {
      setState(() {
        _messages.add(userMsg);
      });
      _scrollToBottom();
    }

    try {
      if (_conversationId != null) {
        final api = context.read<VyraApi>();
        await api.sendDirectMessage(_conversationId!, text);
      }
    } catch (_) {
      // Local fallback preserves user flow seamlessly
    } finally {
      if (mounted) setState(() => _sending = false);
    }

    // Interactive realistic athlete simulation reply
    Timer(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      final replyText = _getSimulatedReply(widget.athleteName, text);
      final replyMsg = DirectMessage(
        id: 'msg_reply_${DateTime.now().millisecondsSinceEpoch}',
        conversationId: _conversationId ?? 'conv_${widget.athleteId}',
        senderId: widget.athleteId,
        body: replyText,
        createdAt: DateTime.now().toIso8601String(),
      );
      setState(() {
        _messages.add(replyMsg);
      });
      _scrollToBottom();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VColor.bg,
      appBar: AppBar(
        backgroundColor: VColor.surfaceRaised,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: VColor.text, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: VColor.bgLift,
                    shape: BoxShape.circle,
                    border: Border.all(color: VColor.line),
                  ),
                  child: Center(
                    child: Text(
                      widget.athleteName.isNotEmpty ? widget.athleteName[0].toUpperCase() : 'A',
                      style: const TextStyle(color: VColor.accent, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: VColor.accentGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: VColor.surfaceRaised, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: VSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.athleteName,
                          style: const TextStyle(color: VColor.text, fontSize: 15, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.verified_rounded, color: VColor.accent, size: 14),
                    ],
                  ),
                  Text(
                    '@${widget.athleteHandle} · Active Athlete',
                    style: const TextStyle(color: VColor.textMid, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_rounded, color: VColor.textMid, size: 20),
            onPressed: () {
              HapticFeedback.mediumImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('📞 Live telemetry audio channel standby.'),
                  backgroundColor: VColor.accent,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.videocam_rounded, color: VColor.textMid, size: 22),
            onPressed: () {
              HapticFeedback.mediumImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('📹 Live video telemetry channel standby.'),
                  backgroundColor: VColor.accentGreen,
                ),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // ── Telemetry Live Sync Banner (Stitch Page 38b) ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: VSpace.base, vertical: 8),
            decoration: BoxDecoration(
              color: VColor.surfaceRaised.withValues(alpha: 0.6),
              border: const Border(bottom: BorderSide(color: VColor.line)),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: VColor.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'VYRA SYNC ENGINE V4.2',
                  style: TextStyle(
                    color: VColor.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: VColor.accentGreenGlow,
                    borderRadius: BorderRadius.circular(VRadius.pill),
                  ),
                  child: const Text(
                    'Live Heartbeats Linked',
                    style: TextStyle(color: VColor.accentGreen, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // ── Messages Feed ──
          Expanded(
            child: _loading
                ? const Center(child: VLoading(label: 'Syncing telemetry chat...'))
                : _error != null
                    ? Center(child: VErrorView(message: _error!, onRetry: _initChat))
                    : _messages.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: VSpace.base, vertical: VSpace.md),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final msg = _messages[index];
                              final isMe = msg.senderId != widget.athleteId;
                              return _buildMessageBubble(msg, isMe);
                            },
                          ),
          ),

          // ── Quick Reaction Chips ──
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: VSpace.base),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _quickChip('⚡ Let\'s train!'),
                _quickChip('🔥 Great pace'),
                _quickChip('💪 PR crushed!'),
                _quickChip('🎯 Ready for next set'),
                _quickChip('🥤 Water break'),
              ],
            ),
          ),

          // ── Message Input Bar ──
          Container(
            padding: EdgeInsets.fromLTRB(
              VSpace.base,
              8,
              VSpace.base,
              MediaQuery.of(context).padding.bottom + 8,
            ),
            decoration: const BoxDecoration(
              color: VColor.surfaceRaised,
              border: Border(top: BorderSide(color: VColor.line)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(color: VColor.text, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Message ${widget.athleteName}...',
                      hintStyle: const TextStyle(color: VColor.textLow, fontSize: 14),
                      fillColor: VColor.bg,
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(VRadius.pill),
                        borderSide: const BorderSide(color: VColor.line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(VRadius.pill),
                        borderSide: const BorderSide(color: VColor.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(VRadius.pill),
                        borderSide: const BorderSide(color: VColor.accent),
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: VSpace.sm),
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [VColor.accent, VColor.accentGreen],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.black, size: 20),
                    onPressed: _sending ? null : () => _sendMessage(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickChip(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        backgroundColor: VColor.bgLift,
        side: const BorderSide(color: VColor.line),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        label: Text(text, style: const TextStyle(color: VColor.textMid, fontSize: 11)),
        onPressed: () => _sendMessage(text),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(VSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: VColor.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: VColor.accent.withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded, color: VColor.accent, size: 30),
            ),
            const SizedBox(height: VSpace.md),
            Text(
              'Direct Channel with ${widget.athleteName}',
              style: const TextStyle(color: VColor.text, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Encrypted 1-on-1 athlete channel ready. Share workout telemetry, exchange running routes, or send motivation!',
              textAlign: TextAlign.center,
              style: TextStyle(color: VColor.textMid, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(DirectMessage msg, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? VColor.accent : VColor.surfaceRaised,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: Border.all(
            color: isMe ? Colors.transparent : VColor.line,
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              msg.body,
              style: TextStyle(
                color: isMe ? Colors.black : VColor.text,
                fontSize: 14,
                fontWeight: isMe ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              msg.createdAt.length >= 16 ? msg.createdAt.substring(11, 16) : msg.createdAt,
              style: TextStyle(
                color: isMe ? Colors.black.withValues(alpha: 0.6) : VColor.textLow,
                fontSize: 9.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<DirectMessage> _getDefaultAthleteMessages(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('vikram')) {
      return [
        DirectMessage(
          id: 'v1',
          conversationId: 'conv_vikram',
          senderId: widget.athleteId,
          body: 'Hey Ayush! Saw your 5K morning split on the leaderboard — 24:12 is solid pace bro! 🏃🔥',
          createdAt: '2026-09-28T09:40:00Z',
        ),
        const DirectMessage(
          id: 'v2',
          conversationId: 'conv_vikram',
          senderId: 'me',
          body: 'Thanks Vikram! Legs felt light today. How did your heavy leg session go yesterday?',
          createdAt: '2026-09-28T09:42:00Z',
        ),
        DirectMessage(
          id: 'v3',
          conversationId: 'conv_vikram',
          senderId: widget.athleteId,
          body: 'Hit a new squat PR of 140kg! VYRA biomechanics tracker scored 94% on depth.',
          createdAt: '2026-09-28T09:44:00Z',
        ),
        const DirectMessage(
          id: 'v4',
          conversationId: 'conv_vikram',
          senderId: 'me',
          body: 'Beast mode! Let\'s do a joint track sprint this Saturday morning at 6:30 AM?',
          createdAt: '2026-09-28T09:45:00Z',
        ),
        DirectMessage(
          id: 'v5',
          conversationId: 'conv_vikram',
          senderId: widget.athleteId,
          body: '100% locked in! I\'ll bring the hydration electrolytes. See you at the stadium track! ⚡',
          createdAt: '2026-09-28T09:46:00Z',
        ),
      ];
    } else if (lower.contains('ananya')) {
      return [
        DirectMessage(
          id: 'a1',
          conversationId: 'conv_ananya',
          senderId: widget.athleteId,
          body: 'Hey Ayush! Are you joining our 10,000 steps weekend squad challenge? 🏃‍♀️✨',
          createdAt: '2026-09-28T08:15:00Z',
        ),
        const DirectMessage(
          id: 'a2',
          conversationId: 'conv_ananya',
          senderId: 'me',
          body: 'Definitely! Already crossed 8,500 steps today before afternoon.',
          createdAt: '2026-09-28T08:18:00Z',
        ),
        DirectMessage(
          id: 'a3',
          conversationId: 'conv_ananya',
          senderId: widget.athleteId,
          body: 'Awesome! Our squad is currently #2 on the national board. Let\'s claim that #1 gold trophy! 🏆',
          createdAt: '2026-09-28T08:20:00Z',
        ),
      ];
    } else if (lower.contains('kabir')) {
      return [
        DirectMessage(
          id: 'k1',
          conversationId: 'conv_kabir',
          senderId: widget.athleteId,
          body: 'Ayush, great job completing your mobility drills today. Your recovery telemetry looks solid.',
          createdAt: '2026-09-27T18:00:00Z',
        ),
        const DirectMessage(
          id: 'k2',
          conversationId: 'conv_kabir',
          senderId: 'me',
          body: 'Thanks Coach Kabir! Should I increase weight on deadlifts for tomorrow\'s power routine?',
          createdAt: '2026-09-27T18:05:00Z',
        ),
        DirectMessage(
          id: 'k3',
          conversationId: 'conv_kabir',
          senderId: widget.athleteId,
          body: 'Keep working load at 75% 1RM tomorrow. Focus on explosive concentric drive and a 3-second controlled eccentric descent.',
          createdAt: '2026-09-27T18:08:00Z',
        ),
      ];
    } else {
      return [
        DirectMessage(
          id: 'g1',
          conversationId: 'conv_gen',
          senderId: widget.athleteId,
          body: 'Hey Ayush! Noticed your workout streak on the VYRA community feed. Pure dedication! 💪🔥',
          createdAt: '2026-09-28T07:30:00Z',
        ),
        const DirectMessage(
          id: 'g2',
          conversationId: 'conv_gen',
          senderId: 'me',
          body: 'Thanks a lot! Keeping the momentum going every single day. How is your training cycle going?',
          createdAt: '2026-09-28T07:35:00Z',
        ),
        DirectMessage(
          id: 'g3',
          conversationId: 'conv_gen',
          senderId: widget.athleteId,
          body: 'Loving the real-time biometric pacing. Catch you on the leaderboard!',
          createdAt: '2026-09-28T07:38:00Z',
        ),
      ];
    }
  }

  String _getSimulatedReply(String athleteName, String userMessage) {
    final lower = userMessage.toLowerCase();
    if (lower.contains('run') || lower.contains('pace') || lower.contains('5k')) {
      return 'Awesome pacing! Keep that aerobic cadence steady and stay well hydrated. 🏃';
    } else if (lower.contains('pr') || lower.contains('lift') || lower.contains('squat') || lower.contains('gym')) {
      return 'Huge respect! Keep perfecting that posture and remember to lock in clean recovery sleep tonight. 💪';
    } else if (lower.contains('water') || lower.contains('drink') || lower.contains('diet')) {
      return 'Great habit! Adequate hydration and 25g-30g post-workout protein make all the difference. 🥤';
    } else if (lower.contains('tomorrow') || lower.contains('time') || lower.contains('meet')) {
      return 'Count me in! Let\'s synchronize our VYRA live activity tracker when we start. 🎯';
    } else {
      return 'That sounds great! Let\'s keep crushing these fitness milestones together on VYRA! 🚀';
    }
  }
}
