import 'package:flutter/material.dart';

import '../theme.dart';
import 'challenges.dart';
import 'friends_leaderboard.dart';
import 'rewards.dart';

/// CHALLENGES — the coin economy, the dual leaderboard, and the Perks
/// Catalog to spend coins on.
class ChallengesHubScreen extends StatelessWidget {
  const ChallengesHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 3,
      child: SafeArea(
        child: Column(
          children: [
            TabBar(
              isScrollable: true,
              labelColor: VColor.accent,
              unselectedLabelColor: VColor.textMid,
              indicatorColor: VColor.accent,
              tabs: [
                Tab(text: 'Challenges'),
                Tab(text: 'Rewards'),
                Tab(text: 'Social Leaderboard'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ChallengesScreen(),
                  RewardsScreen(),
                  FriendsLeaderboardScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
