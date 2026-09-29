import 'package:flutter/material.dart';

import '../theme.dart';

/// Pushes a screen onto the navigation stack.
/// If the screen already defines its own Scaffold / AppBar, it is pushed directly
/// to ensure there is never a duplicate AppBar or double back button at the top.
Future<T?> pushScreen<T>(BuildContext context, String title, Widget screen) {
  const selfScaffoldTypes = {
    'LeaderboardScreen',
    'ExerciseDetailScreen',
    'MessagesInboxScreen',
    'AiChatScreen',
    'BloodDonationScreen',
    'RecordScreen',
    'FoodScanScreen',
    'BarcodeScanScreen',
    'FaceHairYogaScreen',
    'GlobalSearchScreen',
    'SettingsScreen',
    'ChallengesHubScreen',
    'HealthReportAiScreen',
    'NearbyDoctorsScreen',
    'AvatarStudioScreen',
    'FriendsLeaderboardScreen',
    'ChallengeDetailScreen',
    'AthleteChatScreen',
    'DietChartScreen',
    'WaterReminderScreen',
    'HealthSyncScreen',
    'UserFollowListScreen',
    'EventDetailScreen',
    'PostDetailScreen',
    'PoseTrackerScreen',
  };

  final typeName = screen.runtimeType.toString();
  if (selfScaffoldTypes.contains(typeName) || screen is Scaffold) {
    return Navigator.of(context).push<T>(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  return Navigator.of(context).push<T>(
    MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: VColor.bg,
        appBar: AppBar(
          title: Text(title),
          backgroundColor: VColor.bg,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: VColor.text),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        body: screen,
      ),
    ),
  );
}
