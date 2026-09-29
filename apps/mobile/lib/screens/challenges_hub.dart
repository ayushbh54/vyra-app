import 'package:flutter/material.dart';

import '../theme.dart';
import 'challenges.dart';
import 'rewards.dart';

/// CHALLENGES & REWARDS HUB
///
/// Personal streaks, community-wide leagues, and transparent coin economics.
class ChallengesHubScreen extends StatelessWidget {
  const ChallengesHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: SafeArea(
        child: Column(
          children: [
            TabBar(
              isScrollable: false,
              labelColor: VColor.accent,
              unselectedLabelColor: VColor.textMid,
              indicatorColor: VColor.accent,
              tabs: [
                Tab(text: 'Challenges'),
                Tab(text: 'Rewards'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ChallengesScreen(),
                  RewardsScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
