import 'package:flutter/material.dart';

import '../theme.dart';
import 'challenges.dart';
import 'rewards.dart';
import 'social.dart';

/// CHALLENGES — the coin economy, the dual leaderboard, and the Perks
/// Catalog to spend coins on. Clubs/Events/Friends live in the Social tab
/// instead (see social_hub.dart) — this tab is specifically about
/// competing, earning, and spending, not connecting.
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
                Tab(text: 'Leaderboard'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ChallengesScreen(),
                  RewardsScreen(),
                  SocialScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
