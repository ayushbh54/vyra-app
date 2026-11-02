import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyra/models/models.dart';
import 'package:vyra/screens/streak_calendar_screen.dart';
import 'package:vyra/services/activity_usage_service.dart';

void main() {
  group('VYRA StreakMatrix™ & Activity Heatmap Mobile Tests', () {
    test('StreakDayItem correctly parses daily stats and activity level', () {
      final json = {
        'date': '2026-11-02',
        'dayOfWeek': 'Mon',
        'level': 4,
        'checkedIn': true,
        'checkedInAt': '2026-11-02T08:30:00.000Z',
        'appUsageSec': 2520,
        'appUsageFormatted': '0h 42m',
        'exercisesCompleted': 3,
        'workoutDurationMin': 45,
        'caloriesBurned': 380,
        'caloriesConsumed': 1850,
        'netCalories': 1470,
        'waterMl': 2500,
        'steps': 9200,
        'coinsEarned': 50,
        'metGoal': true,
      };

      final item = StreakDayItem.fromJson(json);

      expect(item.date, '2026-11-02');
      expect(item.dayOfWeek, 'Mon');
      expect(item.level, 4);
      expect(item.checkedIn, isTrue);
      expect(item.appUsageSec, 2520);
      expect(item.appUsageFormatted, '0h 42m');
      expect(item.exercisesCompleted, 3);
      expect(item.workoutDurationMin, 45);
      expect(item.caloriesBurned, 380);
      expect(item.caloriesConsumed, 1850);
      expect(item.netCalories, 1470);
      expect(item.waterMl, 2500);
      expect(item.steps, 9200);
      expect(item.coinsEarned, 50);
      expect(item.metGoal, isTrue);
    });

    test('StreakCalendarData parses complete month matrix and streak metrics', () {
      final json = {
        'year': 2026,
        'month': 11,
        'monthName': 'November',
        'currentStreak': 18,
        'longestStreak': 24,
        'totalActiveDaysInMonth': 26,
        'monthlyConsistencyPct': 87,
        'days': [
          {
            'date': '2026-11-01',
            'dayOfWeek': 'Sun',
            'level': 2,
            'checkedIn': true,
            'appUsageSec': 1200,
            'appUsageFormatted': '0h 20m',
            'exercisesCompleted': 1,
            'workoutDurationMin': 20,
            'caloriesBurned': 150,
            'caloriesConsumed': 1600,
            'netCalories': 1450,
            'waterMl': 2000,
            'steps': 6000,
            'coinsEarned': 25,
            'metGoal': false,
          },
          {
            'date': '2026-11-02',
            'dayOfWeek': 'Mon',
            'level': 4,
            'checkedIn': true,
            'appUsageSec': 2700,
            'appUsageFormatted': '0h 45m',
            'exercisesCompleted': 3,
            'workoutDurationMin': 40,
            'caloriesBurned': 360,
            'caloriesConsumed': 1900,
            'netCalories': 1540,
            'waterMl': 2800,
            'steps': 10500,
            'coinsEarned': 60,
            'metGoal': true,
          },
        ],
      };

      final calendar = StreakCalendarData.fromJson(json);

      expect(calendar.year, 2026);
      expect(calendar.month, 11);
      expect(calendar.monthName, 'November');
      expect(calendar.currentStreak, 18);
      expect(calendar.longestStreak, 24);
      expect(calendar.totalActiveDaysInMonth, 26);
      expect(calendar.monthlyConsistencyPct, 87);
      expect(calendar.days.length, 2);
      expect(calendar.days.first.level, 2);
      expect(calendar.days.last.level, 4);
    });

    test('DayDetailedBreakdown parses completed exercises, app screen time, and caloric balance', () {
      final json = {
        'date': '2026-11-02',
        'formattedDate': 'Monday, 2 November 2026',
        'level': 3,
        'checkedIn': true,
        'checkedInAt': '2026-11-02T09:15:00.000Z',
        'appUsageSec': 3600,
        'appUsageFormatted': '1h 0m',
        'exercisesCompleted': [
          {
            'exerciseSlug': 'barbell-bench-press',
            'name': 'Barbell Bench Press',
            'durationSec': 720,
            'durationFormatted': '12m',
            'isCompleted': true,
            'reps': 10,
            'sets': 3,
          },
          {
            'exerciseSlug': 'incline-dumbbell-press',
            'name': 'Incline Dumbbell Press',
            'durationSec': 600,
            'durationFormatted': '10m',
            'isCompleted': true,
            'reps': 12,
            'sets': 3,
          },
        ],
        'totalExercisesCompleted': 2,
        'workoutDurationMin': 35,
        'caloriesBurned': 280,
        'caloriesConsumed': 2100,
        'netCalories': 1820,
        'waterMl': 3000,
        'steps': 8500,
        'coinsEarned': 45,
        'summaryNote': 'Metabolic stimulus delivered with solid anterior deltoid engagement.',
      };

      final breakdown = DayDetailedBreakdown.fromJson(json);

      expect(breakdown.date, '2026-11-02');
      expect(breakdown.formattedDate, 'Monday, 2 November 2026');
      expect(breakdown.level, 3);
      expect(breakdown.checkedIn, isTrue);
      expect(breakdown.appUsageSec, 3600);
      expect(breakdown.appUsageFormatted, '1h 0m');
      expect(breakdown.totalExercisesCompleted, 2);
      expect(breakdown.exercisesCompleted.length, 2);
      expect(breakdown.exercisesCompleted.first.name, 'Barbell Bench Press');
      expect(breakdown.exercisesCompleted.first.durationFormatted, '12m');
      expect(breakdown.exercisesCompleted.first.reps, 10);
      expect(breakdown.exercisesCompleted.first.sets, 3);
      expect(breakdown.summaryNote, contains('Metabolic stimulus'));
    });

    test('StreakLeaderboardData parses podium with gold, silver, bronze crowns and self pin', () {
      final json = {
        'podium': [
          {
            'rank': 1,
            'userId': 'usr_titan_1',
            'displayHandle': 'iron_priya',
            'streakDays': 48,
            'longestStreak': 52,
            'consistencyPct': 98,
            'totalActiveDays': 29,
            'badge': 'crown_gold',
            'isSelf': false,
          },
          {
            'rank': 2,
            'userId': 'usr_titan_2',
            'displayHandle': 'kabaddi_dev',
            'streakDays': 39,
            'longestStreak': 41,
            'consistencyPct': 94,
            'totalActiveDays': 28,
            'badge': 'crown_silver',
            'isSelf': false,
          },
          {
            'rank': 3,
            'userId': 'usr_titan_3',
            'displayHandle': 'yoga_ananya',
            'streakDays': 32,
            'longestStreak': 35,
            'consistencyPct': 91,
            'totalActiveDays': 27,
            'badge': 'crown_bronze',
            'isSelf': false,
          },
        ],
        'allRanks': [
          {
            'rank': 1,
            'userId': 'usr_titan_1',
            'displayHandle': 'iron_priya',
            'streakDays': 48,
            'longestStreak': 52,
            'consistencyPct': 98,
            'totalActiveDays': 29,
            'badge': 'crown_gold',
            'isSelf': false,
          },
          {
            'rank': 4,
            'userId': 'usr_self',
            'displayHandle': 'ayush_athlete',
            'streakDays': 18,
            'longestStreak': 24,
            'consistencyPct': 87,
            'totalActiveDays': 26,
            'badge': 'flame',
            'isSelf': true,
          },
        ],
        'self': {
          'rank': 4,
          'userId': 'usr_self',
          'displayHandle': 'ayush_athlete',
          'streakDays': 18,
          'longestStreak': 24,
          'consistencyPct': 87,
          'totalActiveDays': 26,
          'badge': 'flame',
          'isSelf': true,
        },
      };

      final lb = StreakLeaderboardData.fromJson(json);

      expect(lb.podium.length, 3);
      expect(lb.podium[0].badge, 'crown_gold');
      expect(lb.podium[0].streakDays, 48);
      expect(lb.podium[1].badge, 'crown_silver');
      expect(lb.podium[2].badge, 'crown_bronze');
      expect(lb.self.isSelf, isTrue);
      expect(lb.self.rank, 4);
      expect(lb.self.streakDays, 18);
      expect(lb.self.consistencyPct, 87);
    });

    testWidgets('StreakCalendarScreen renders without crash in dark mode', (WidgetTester tester) async {
      const mockData = StreakCalendarData(
        year: 2026,
        month: 11,
        monthName: 'November',
        currentStreak: 18,
        longestStreak: 24,
        totalActiveDaysInMonth: 26,
        monthlyConsistencyPct: 87,
        days: [
          const StreakDayItem(
            date: '2026-11-01',
            dayOfWeek: 'Sun',
            level: 2,
            checkedIn: true,
            appUsageSec: 1200,
            appUsageFormatted: '0h 20m',
            exercisesCompleted: 1,
            workoutDurationMin: 20,
            caloriesBurned: 150,
            caloriesConsumed: 1600,
            netCalories: 1450,
            waterMl: 2000,
            steps: 6000,
            coinsEarned: 25,
            metGoal: false,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: StreakCalendarScreen(
            initialYear: 2026,
            initialMonth: 11,
            initialCalendarData: mockData,
          ),
        ),
      );

      expect(find.byType(StreakCalendarScreen), findsOneWidget);
      expect(find.text('Streak & Activity Matrix'), findsOneWidget);
      expect(find.text('Current Streak'), findsOneWidget);
      expect(find.text('Best Streak'), findsOneWidget);
      expect(find.text('Consistency'), findsOneWidget);
    });

    test('ActivityUsageService formatHoursAndMinutes formats active time cleanly', () {
      expect(ActivityUsageService.formatHoursAndMinutes(0), '0h 0m');
      expect(ActivityUsageService.formatHoursAndMinutes(45), '0h 0m');
      expect(ActivityUsageService.formatHoursAndMinutes(300), '0h 5m');
      expect(ActivityUsageService.formatHoursAndMinutes(2520), '0h 42m');
      expect(ActivityUsageService.formatHoursAndMinutes(4500), '1h 15m');
    });

    test('ActivityUsageService accurately detects active engagement vs hands-free session', () {
      final service = ActivityUsageService.instance;

      // 1. User interaction notifies active state
      service.notifyUserInteraction();
      expect(service.isActivelyEngaged, isTrue);

      // 2. Explicit active session (e.g. child doing squats in front of camera)
      service.beginActiveSession('camera_pose_tracking');
      expect(service.isActivelyEngaged, isTrue);

      service.endActiveSession('camera_pose_tracking');
      // Still active because interaction was very recent
      expect(service.isActivelyEngaged, isTrue);
    });
  });
}
