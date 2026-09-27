import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/common.dart';
import 'ai_chat.dart';
import 'clubs.dart';
import 'events.dart';
import 'feed.dart';
import 'friends.dart';
import 'messages_inbox.dart';
import 'posts.dart';

/// SOCIAL — the feed, posts, clubs, events, and friends all live here.
/// Challenges and the leaderboard live in their own tab (see
/// challenges_hub.dart) — "social" is about other athletes, "challenges" is
/// about competing.
///
/// Feed vs Posts: Feed is generated from recorded Activities (feed.dart).
/// Posts (posts.dart) is anything an athlete wants to say — text, an
/// optional photo — independent of any recorded activity.
class SocialHubScreen extends StatelessWidget {
  const SocialHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: SafeArea(
        child: Column(
          children: [
            // ── Top Header Strip with Messages & AI Coach ──
            Padding(
              padding: const EdgeInsets.fromLTRB(VSpace.base, VSpace.xs, VSpace.sm, 0),
              child: Row(
                children: [
                  const VHeaderBadge(label: 'ATHLETE SOCIAL NETWORK', accentColor: VColor.accent),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Direct Messages',
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: VColor.surfaceRaised,
                        shape: BoxShape.circle,
                        border: Border.all(color: VColor.line),
                      ),
                      child: const Icon(Icons.forum_rounded, color: VColor.accent, size: 18),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const MessagesInboxScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
            const TabBar(
              isScrollable: true,
              labelColor: VColor.accent,
              unselectedLabelColor: VColor.textMid,
              indicatorColor: VColor.accent,
              tabs: [
                Tab(text: 'Feed'),
                Tab(text: 'Posts'),
                Tab(text: 'Clubs'),
                Tab(text: 'Events'),
                Tab(text: 'Friends'),
              ],
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  FeedScreen(),
                  PostsFeedScreen(),
                  ClubsScreen(),
                  EventsScreen(),
                  FriendsScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
