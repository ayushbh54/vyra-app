import 'package:flutter/material.dart';
import '../services/social_integration_service.dart';
import '../theme.dart';

/// SUBWAY SURFERS & WHATSAPP STYLE SOCIAL LEADERBOARD & AUTO-DISCOVERY
///
/// Addresses the core user problem:
/// "Link kis kis ko bhejoge aur relative use kr rahe hain kaise pata lagega?"
///
/// Features:
/// 1. Facebook Graph Sync (Subway Surfers model): Auto-detects real Facebook friends on VYRA
/// 2. Contacts Auto-Discovery (WhatsApp model): Auto-matches phonebook contacts to relatives (Chachu, Didi, Mama)
/// 3. 1-Tap WhatsApp Family Cup launcher
/// 4. 1-Tap Instagram Story achievement exporter
class FriendsLeaderboardScreen extends StatefulWidget {
  const FriendsLeaderboardScreen({super.key});

  @override
  State<FriendsLeaderboardScreen> createState() => _FriendsLeaderboardScreenState();
}

class _FriendsLeaderboardScreenState extends State<FriendsLeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _socialService = SocialIntegrationService.instance;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _socialService.init();
    _socialService.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _socialService.removeListener(_onServiceUpdate);
    _tabController.dispose();
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VColor.bg,
      appBar: AppBar(
        backgroundColor: VColor.surface,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [VColor.accent, VColor.accentGreen]),
                borderRadius: BorderRadius.circular(VRadius.sm),
              ),
              child: const Text('VYRA SOCIAL',
                  style: TextStyle(color: VColor.bg, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.1)),
            ),
            const SizedBox(width: 10),
            const Text('Social Leaderboards',
                style: TextStyle(color: VColor.text, fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Share via WhatsApp',
            icon: const Icon(Icons.share_rounded, color: VColor.accentGreen),
            onPressed: () => _socialService.shareFamilyChallengeOnWhatsApp(
              userName: 'Ayush',
              userSteps: 64200,
            ),
          ),
          IconButton(
            tooltip: 'Instagram Story Export',
            icon: const Icon(Icons.camera_alt_outlined, color: VColor.accent),
            onPressed: () => _showInstagramShareSheet(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: VColor.accent,
          indicatorWeight: 3,
          labelColor: VColor.accent,
          unselectedLabelColor: VColor.textMid,
          tabs: const [
            Tab(icon: Icon(Icons.family_restroom, size: 20), text: 'Relatives & Contacts'),
            Tab(icon: Icon(Icons.facebook, size: 20), text: 'Facebook Friends'),
            Tab(icon: Icon(Icons.public, size: 20), text: 'All India Rank'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildContactsTab(),
          _buildFacebookTab(),
          _buildAllIndiaTab(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: RELATIVES & PHONE CONTACTS (WhatsApp Model)
  // ---------------------------------------------------------------------------
  Widget _buildContactsTab() {
    final contacts = _socialService.discoveredContacts;
    final relativesCount = _socialService.relativeMatchesCount;

    return RefreshIndicator(
      onRefresh: () => _socialService.syncPhoneContacts(),
      color: VColor.accent,
      child: ListView(
        padding: const EdgeInsets.all(VSpace.base),
        children: [
          // Banner explaining how relatives are automatically matched
          Container(
            padding: const EdgeInsets.all(VSpace.base),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [VColor.accent.withValues(alpha: 0.15), VColor.surface],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(VRadius.lg),
              border: Border.all(color: VColor.accent.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: VColor.accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.contact_phone_rounded, color: VColor.bg, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Phonebook Auto-Discovery',
                              style: TextStyle(color: VColor.text, fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(
                            _socialService.isContactsSynced
                                ? '🎉 $relativesCount Relatives & ${contacts.length - relativesCount} Friends active on VYRA!'
                                : 'Sync contacts to see which relatives are using VYRA',
                            style: const TextStyle(color: VColor.accentGreen, fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Aapko kisi ko link bhejne ki zaroorat nahi hai. VYRA aapke saved phone contacts (Chacha, Mama, Didi, Friends) ko unki fitness profile ke sath auto-detect kar leta hai!',
                  style: TextStyle(color: VColor.textMid, fontSize: 12.5, height: 1.4),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isSyncing
                            ? null
                            : () async {
                                setState(() => _isSyncing = true);
                                await _socialService.syncPhoneContacts();
                                if (mounted) setState(() => _isSyncing = false);
                              },
                        icon: _isSyncing
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: VColor.bg))
                            : const Icon(Icons.sync_rounded, size: 18),
                        label: Text(_socialService.isContactsSynced ? 'Re-Sync Contacts' : 'Auto-Find Relatives'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VColor.accent,
                          foregroundColor: VColor.bg,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.pill)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _socialService.followAllContacts(),
                      icon: const Icon(Icons.group_add_outlined, size: 18),
                      label: const Text('Connect All'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: VColor.accentGreen,
                        side: const BorderSide(color: VColor.accentGreen),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.pill)),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: VSpace.lg),

          // Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('DISCOVERED FAMILY & CONTACTS',
                  style: TextStyle(color: VColor.textMid, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: VColor.surfaceRaised,
                  borderRadius: BorderRadius.circular(VRadius.pill),
                  border: Border.all(color: VColor.line),
                ),
                child: Text('${contacts.length} found',
                    style: const TextStyle(color: VColor.textLow, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: VSpace.sm),

          // Contacts List
          ...contacts.map((contact) => _buildContactCard(contact)),

          const SizedBox(height: VSpace.lg),
          // WhatsApp Family Challenge Banner
          _buildWhatsAppFamilyBanner(),
        ],
      ),
    );
  }

  Widget _buildContactCard(SyncedContactFriend contact) {
    return Container(
      margin: const EdgeInsets.only(bottom: VSpace.sm),
      padding: const EdgeInsets.all(VSpace.base),
      decoration: BoxDecoration(
        color: VColor.surface,
        borderRadius: BorderRadius.circular(VRadius.lg),
        border: Border.all(
          color: contact.isRelative ? VColor.accentGreen.withValues(alpha: 0.3) : VColor.line,
        ),
      ),
      child: Row(
        children: [
          // Avatar with Relative Badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: contact.isRelative ? VColor.accentGreenGlow : VColor.accentGlow,
                child: Text(contact.initials,
                    style: TextStyle(
                      color: contact.isRelative ? VColor.accentGreen : VColor.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    )),
              ),
              if (contact.isRelative)
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: VColor.accentGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.star, size: 10, color: VColor.bg),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),

          // Contact Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        contact.contactBookName,
                        style: const TextStyle(color: VColor.text, fontSize: 14.5, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (contact.isRelative) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: VColor.accentGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(VRadius.sm),
                        ),
                        child: const Text('FAMILY',
                            style: TextStyle(color: VColor.accentGreen, fontSize: 9.5, fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${contact.displayName} • ${contact.vyraHandle}',
                  style: const TextStyle(color: VColor.textLow, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.directions_walk_rounded, size: 14, color: VColor.accent),
                    const SizedBox(width: 4),
                    Text(
                      '${contact.weeklySteps.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} steps/wk',
                      style: const TextStyle(color: VColor.accent, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Follow/Challenge Button
          ElevatedButton(
            onPressed: () => _socialService.toggleFollowContact(contact.vyraUserId),
            style: ElevatedButton.styleFrom(
              backgroundColor: contact.isFollowing ? VColor.surfaceRaised : VColor.accent,
              foregroundColor: contact.isFollowing ? VColor.textMid : VColor.bg,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(VRadius.pill),
                side: BorderSide(color: contact.isFollowing ? VColor.line : Colors.transparent),
              ),
            ),
            child: Text(
              contact.isFollowing ? 'Following' : 'Challenge',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: FACEBOOK FRIENDS LEADERBOARD (Subway Surfers Model)
  // ---------------------------------------------------------------------------
  Widget _buildFacebookTab() {
    final isConnected = _socialService.isFacebookConnected;
    final fbFriends = _socialService.facebookFriends;

    return ListView(
      padding: const EdgeInsets.all(VSpace.base),
      children: [
        // Facebook Connection Status Card
        Container(
          padding: const EdgeInsets.all(VSpace.base),
          decoration: BoxDecoration(
            color: const Color(0xFF1877F2).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(VRadius.lg),
            border: Border.all(color: const Color(0xFF1877F2).withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFF1877F2),
                  shape: BoxShape.circle,
                ),
                child: const Center(child: Icon(Icons.facebook, color: Colors.white, size: 28)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isConnected ? 'Facebook Connected: ${_socialService.facebookUserName}' : 'Subway Surfers Style Facebook Sync',
                      style: const TextStyle(color: VColor.text, fontWeight: FontWeight.bold, fontSize: 14.5),
                    ),
                    Text(
                      isConnected
                          ? 'Showing all ${fbFriends.length} mutual Facebook friends on VYRA'
                          : 'Connect to auto-populate your friends leaderboard!',
                      style: const TextStyle(color: VColor.textMid, fontSize: 12),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: isConnected
                    ? () => _socialService.disconnectFacebook()
                    : () => _socialService.connectFacebook(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isConnected ? VColor.surfaceRaised : const Color(0xFF1877F2),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.pill)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                child: Text(isConnected ? 'Disconnect' : 'Connect FB', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        ),
        const SizedBox(height: VSpace.lg),

        // Podium top 3
        if (fbFriends.length >= 3) _buildSubwaySurfersPodium(fbFriends),

        const SizedBox(height: VSpace.base),
        const Text('WEEKLY FACEBOOK LEADERBOARD',
            style: TextStyle(color: VColor.textMid, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
        const SizedBox(height: VSpace.sm),

        // List
        ...fbFriends.map((f) => _buildFacebookListTile(f)),
      ],
    );
  }

  Widget _buildSubwaySurfersPodium(List<FacebookFriend> friends) {
    final gold = friends[0];
    final silver = friends[1];
    final bronze = friends[2];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: VSpace.lg, horizontal: VSpace.sm),
      decoration: BoxDecoration(
        color: VColor.surface,
        borderRadius: BorderRadius.circular(VRadius.lg),
        border: Border.all(color: VColor.line),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 20),
              SizedBox(width: 6),
              Text('FACEBOOK WEEKLY CUP',
                  style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: VSpace.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _podiumPillar(silver, 2, 95, const Color(0xFFC0C0C0)),
              _podiumPillar(gold, 1, 125, const Color(0xFFFFD700)),
              _podiumPillar(bronze, 3, 80, const Color(0xFFCD7F32)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _podiumPillar(FacebookFriend friend, int rank, double pillarHeight, Color crownColor) {
    return Column(
      children: [
        Icon(Icons.workspace_premium_rounded, color: crownColor, size: 26),
        const SizedBox(height: 4),
        CircleAvatar(
          radius: 22,
          backgroundColor: crownColor.withValues(alpha: 0.3),
          child: Text(friend.name.isNotEmpty ? friend.name[0] : 'U',
              style: TextStyle(color: crownColor, fontWeight: FontWeight.bold, fontSize: 18)),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 80,
          child: Text(
            friend.name,
            style: const TextStyle(color: VColor.text, fontWeight: FontWeight.w700, fontSize: 11),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text('${friend.weeklySteps} pts',
            style: TextStyle(color: crownColor, fontSize: 10, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Container(
          width: 75,
          height: pillarHeight,
          decoration: BoxDecoration(
            color: crownColor.withValues(alpha: 0.15),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: crownColor.withValues(alpha: 0.5)),
          ),
          child: Center(
            child: Text('$rank',
                style: TextStyle(color: crownColor, fontSize: 28, fontWeight: FontWeight.w900)),
          ),
        ),
      ],
    );
  }

  Widget _buildFacebookListTile(FacebookFriend friend) {
    final isSelf = friend.name.contains('You');
    return Container(
      margin: const EdgeInsets.only(bottom: VSpace.sm),
      padding: const EdgeInsets.symmetric(horizontal: VSpace.base, vertical: 12),
      decoration: BoxDecoration(
        color: isSelf ? VColor.accentGlow : VColor.surface,
        borderRadius: BorderRadius.circular(VRadius.md),
        border: Border.all(color: isSelf ? VColor.accent : VColor.line),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('#${friend.rank}',
                style: TextStyle(
                  color: friend.rank <= 3 ? const Color(0xFFFFD700) : VColor.textMid,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                )),
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF1877F2).withValues(alpha: 0.2),
            child: Text(friend.name.isNotEmpty ? friend.name[0] : 'U',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(friend.name,
                    style: TextStyle(
                      color: isSelf ? VColor.accent : VColor.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    )),
                const Text('Mutual Facebook Friend', style: TextStyle(color: VColor.textLow, fontSize: 11)),
              ],
            ),
          ),
          Text(
            '${friend.weeklySteps.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} pts',
            style: TextStyle(
              color: isSelf ? VColor.accent : VColor.accentGreen,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 3: ALL INDIA RANK (National Board)
  // ---------------------------------------------------------------------------
  Widget _buildAllIndiaTab() {
    return ListView(
      padding: const EdgeInsets.all(VSpace.base),
      children: [
        Container(
          padding: const EdgeInsets.all(VSpace.base),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1A1A24), Color(0xFF13131A)]),
            borderRadius: BorderRadius.circular(VRadius.lg),
            border: Border.all(color: VColor.line),
          ),
          child: const Row(
            children: [
              Icon(Icons.workspace_premium_outlined, color: VColor.accent, size: 30),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('National Fitness League 2026',
                        style: TextStyle(color: VColor.text, fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('Top 50 athletes across India receive VYRA Elite Vouchers',
                        style: TextStyle(color: VColor.textMid, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: VSpace.base),
        for (var i = 1; i <= 6; i++)
          Container(
            margin: const EdgeInsets.only(bottom: VSpace.sm),
            padding: const EdgeInsets.all(VSpace.base),
            decoration: BoxDecoration(
              color: VColor.surface,
              borderRadius: BorderRadius.circular(VRadius.md),
              border: Border.all(color: VColor.line),
            ),
            child: Row(
              children: [
                Text('#$i', style: const TextStyle(color: VColor.accent, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(width: 14),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: VColor.surfaceRaised,
                  child: Text('A$i', style: const TextStyle(color: VColor.text, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Athlete $i • @india_fit$i',
                          style: const TextStyle(color: VColor.text, fontWeight: FontWeight.w600, fontSize: 13.5)),
                      Text('Delhi NCR • Level ${18 - i}', style: const TextStyle(color: VColor.textLow, fontSize: 11)),
                    ],
                  ),
                ),
                Text('${(95000 - i * 4500)} pts',
                    style: const TextStyle(color: VColor.accentGreen, fontWeight: FontWeight.w800, fontSize: 13)),
              ],
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // WhatsApp Family Banner
  // ---------------------------------------------------------------------------
  Widget _buildWhatsAppFamilyBanner() {
    return Container(
      padding: const EdgeInsets.all(VSpace.base),
      decoration: BoxDecoration(
        color: const Color(0xFF25D366).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(VRadius.lg),
        border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF25D366), size: 24),
              SizedBox(width: 10),
              Text('WhatsApp Family Fitness Cup',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Family WhatsApp group me direct challenge bhejo. Ek click me Chachu, Mama aur Didi leader board me shamil ho jayenge!',
            style: TextStyle(color: VColor.textMid, fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _socialService.shareFamilyChallengeOnWhatsApp(
                userName: 'Ayush',
                userSteps: 64200,
              ),
              icon: const Icon(Icons.share, size: 18),
              label: const Text('Send WhatsApp Family Cup Challenge'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.pill)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Instagram Story Share Sheet
  // ---------------------------------------------------------------------------
  void _showInstagramShareSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: VColor.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(VRadius.lg)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(VSpace.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFFCB045)]),
                      borderRadius: BorderRadius.circular(VRadius.md),
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('Instagram Stories Viral Share',
                      style: TextStyle(color: VColor.text, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Aapka weekly rank card with 3D Avatar ek sleek dark-mode sticker ke roop me direct Instagram Stories par export hoga with dynamic swipe-up challenge link!',
                style: TextStyle(color: VColor.textMid, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _socialService.shareToInstagramStory(
                    title: 'Top 10% on VYRA National Board!',
                    statText: '64,200 Steps this week',
                    streakDays: 14,
                  );
                },
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Export to Instagram Stories'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE1306C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.pill)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
