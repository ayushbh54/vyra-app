import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'athlete_chat.dart';
import 'friends.dart';

/// Stitch Page 38c: Messages Inbox / Direct Athlete Channels
class MessagesInboxScreen extends StatefulWidget {
  const MessagesInboxScreen({super.key});

  @override
  State<MessagesInboxScreen> createState() => _MessagesInboxScreenState();
}

class _MessagesInboxScreenState extends State<MessagesInboxScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<ConversationItem> _conversations = [];
  bool _loading = true;
  String? _error;
  String _selectedFilter = 'all'; // 'all', 'unread', 'online'

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await context.read<VyraApi>().listConversations();
      if (mounted) {
        setState(() {
          _conversations = items;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _conversations = [];
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _conversations = [];
          _error = 'Could not load direct athlete channels. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<ConversationItem> get _filteredConversations {
    final query = _searchController.text.trim().toLowerCase();
    return _conversations.where((c) {
      if (query.isNotEmpty) {
        final matchName = c.otherName.toLowerCase().contains(query);
        final matchHandle = c.otherHandle.toLowerCase().contains(query);
        final matchMsg = (c.lastMessage ?? '').toLowerCase().contains(query);
        if (!matchName && !matchHandle && !matchMsg) return false;
      }
      return true;
    }).toList();
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Messages',
              style: TextStyle(color: VColor.text, fontSize: 18, fontWeight: FontWeight.w800),
            ),
            Row(
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: VColor.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                const Text(
                  'DIRECT ATHLETE CHANNELS',
                  style: TextStyle(
                    color: VColor.accent,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'New Conversation',
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: VColor.bgLift,
                shape: BoxShape.circle,
                border: Border.all(color: VColor.line),
              ),
              child: const Icon(Icons.edit_square, color: VColor.accent, size: 18),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const Scaffold(
                  backgroundColor: VColor.bg,
                  body: FriendsScreen(),
                )),
              ).then((_) => _load());
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: VColor.accent,
        backgroundColor: VColor.surfaceRaised,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: VSpace.base, vertical: VSpace.md),
          children: [
            // ── Search & Filter Strip ──
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: VColor.text, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search conversations or athletes...',
                hintStyle: const TextStyle(color: VColor.textLow, fontSize: 13.5),
                prefixIcon: const Icon(Icons.search_rounded, color: VColor.textLow, size: 20),
                fillColor: VColor.surfaceRaised,
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(VRadius.lg),
                  borderSide: const BorderSide(color: VColor.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(VRadius.lg),
                  borderSide: const BorderSide(color: VColor.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(VRadius.lg),
                  borderSide: const BorderSide(color: VColor.accent),
                ),
              ),
            ),
            const SizedBox(height: VSpace.md),

            // ── Filter Pills ──
            Row(
              children: [
                _filterPill('ALL CHATS', 'all', badge: '${_conversations.length}'),
                const SizedBox(width: 8),
                _filterPill('UNREAD', 'unread'),
                const SizedBox(width: 8),
                _filterPill('ONLINE NOW', 'online', dotColor: VColor.accentGreen),
              ],
            ),
            const SizedBox(height: VSpace.base),

            // ── Live Telemetry Partners Tray (Stitch Page 38c) ──
            if (_conversations.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(VSpace.md),
                decoration: BoxDecoration(
                  color: VColor.surfaceRaised,
                  borderRadius: BorderRadius.circular(VRadius.lg),
                  border: Border.all(color: VColor.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'LIVE TELEMETRY PARTNERS',
                          style: TextStyle(
                            color: VColor.textLow,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: VColor.accentGreenGlow,
                            borderRadius: BorderRadius.circular(VRadius.pill),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.fiber_manual_record, color: VColor.accentGreen, size: 8),
                              const SizedBox(width: 4),
                              Text('${_conversations.length} CHANNELS', style: const TextStyle(color: VColor.accentGreen, fontSize: 9.5, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: VSpace.sm),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final c in _conversations.take(8))
                            _partnerAvatar(
                              c.otherName.split(' ').first,
                              c.otherName.split(' ').where((s) => s.isNotEmpty).map((s) => s[0]).take(2).join().toUpperCase(),
                              c.otherUserId,
                              c.otherName,
                              c.otherHandle,
                              c.id,
                              true,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: VSpace.base),
            ],

            // ── Conversation List ──
            if (_loading)
              const Center(child: Padding(
                padding: EdgeInsets.all(32),
                child: VLoading(label: 'Loading direct channels...'),
              ))
            else if (_error != null)
              VErrorView(message: _error!, onRetry: _load)
            else if (_filteredConversations.isEmpty)
              _buildEmptyState()
            else
              for (final c in _filteredConversations) ...[
                _buildConversationTile(c),
                const SizedBox(height: VSpace.sm),
              ],
          ],
        ),
      ),
    );
  }

  Widget _filterPill(String label, String value, {String? badge, Color? dotColor}) {
    final selected = _selectedFilter == value;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedFilter = value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? VColor.accent.withValues(alpha: 0.15) : VColor.surfaceRaised,
          borderRadius: BorderRadius.circular(VRadius.pill),
          border: Border.all(
            color: selected ? VColor.accent : VColor.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(width: 6, height: 6, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? VColor.accent : VColor.textMid,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: selected ? VColor.accent : VColor.bgLift,
                  borderRadius: BorderRadius.circular(VRadius.pill),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: selected ? Colors.black : VColor.textMid,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _partnerAvatar(
    String name,
    String initials,
    String userId,
    String fullName,
    String handle,
    String convId,
    bool online,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AthleteChatScreen(
              athleteId: userId,
              athleteName: fullName,
              athleteHandle: handle,
              conversationId: convId,
            ),
          ),
        ).then((_) => _load());
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: VColor.bgLift,
                    shape: BoxShape.circle,
                    border: Border.all(color: VColor.line),
                  ),
                  child: Center(
                    child: Text(
                      initials.isNotEmpty ? initials : 'AT',
                      style: const TextStyle(color: VColor.accent, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
                if (online)
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
            const SizedBox(height: 4),
            Text(name, style: const TextStyle(color: VColor.textMid, fontSize: 10.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(VSpace.xl),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: VColor.accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.forum_outlined, color: VColor.accent, size: 28),
          ),
          const SizedBox(height: VSpace.md),
          const Text(
            'No conversations yet',
            style: TextStyle(color: VColor.text, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Connect with athletes in your city, trade running tips, and challenge each other to daily streaks.',
            textAlign: TextAlign.center,
            style: TextStyle(color: VColor.textMid, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: VSpace.lg),
          VGradientButton(
            label: 'Search Athletes to Message',
            icon: Icons.person_search_rounded,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const Scaffold(
                  backgroundColor: VColor.bg,
                  body: FriendsScreen(),
                )),
              ).then((_) => _load());
            },
          ),
        ],
      ),
    );
  }

  Widget _buildConversationTile(ConversationItem c) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(VRadius.lg),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AthleteChatScreen(
                athleteId: c.otherUserId,
                athleteName: c.otherName,
                athleteHandle: c.otherHandle,
                conversationId: c.id,
              ),
            ),
          ).then((_) => _load());
        },
        child: Container(
          padding: const EdgeInsets.all(VSpace.md),
          decoration: BoxDecoration(
            color: VColor.surfaceRaised,
            borderRadius: BorderRadius.circular(VRadius.lg),
            border: Border.all(color: VColor.line),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: VColor.bgLift,
                  shape: BoxShape.circle,
                  border: Border.all(color: VColor.line),
                ),
                child: Center(
                  child: Text(
                    c.otherName.isNotEmpty ? c.otherName[0].toUpperCase() : 'A',
                    style: const TextStyle(color: VColor.accent, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: VSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          c.otherName,
                          style: const TextStyle(color: VColor.text, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          c.lastMessageAt.length >= 10 ? c.lastMessageAt.substring(5, 10) : '',
                          style: const TextStyle(color: VColor.textLow, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      c.lastMessage ?? 'Direct channel active · Tap to chat',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.lastMessage != null ? VColor.textMid : VColor.accent,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
