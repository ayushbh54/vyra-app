import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  calculateActivityLevel,
  formatDuration,
  formatAppUsage,
  buildStreakCalendar,
  getDaySummary,
  buildStreakLeaderboard,
} from './streaks';
import { MemoryStore, type StoredUser } from '../store';

const mockUser: StoredUser = {
  id: 'usr_streak_test',
  displayHandle: 'ayush_athlete',
  name: 'Ayush Singh',
  gender: 'male',
  dob: '2001-05-15',
  heightCm: 178,
  weightKg: 72,
  disabilityFlag: false,
  accessibilityMode: false,
  fitnessGoal: 'gain_weight',
  dietToggle: true,
  dietPreference: 'vegetarian',
  primarySport: 'gym',
  dmPrivacy: 'following',
  accountStatus: 'active',
  onboardingStep: 4,
  createdAt: new Date().toISOString(),
};

describe('VYRA StreakMatrix™ & Activity Heatmap Engine', () => {
  describe('calculateActivityLevel', () => {
    it('returns 0 for completely inactive days', () => {
      const level = calculateActivityLevel({
        checkedIn: false,
        workoutMinutes: 0,
        metGoal: false,
        caloriesBurned: 0,
        steps: 0,
      });
      assert.equal(level, 0);
    });

    it('returns 1 for app check-in only', () => {
      const level = calculateActivityLevel({
        checkedIn: true,
        workoutMinutes: 0,
        metGoal: false,
        caloriesBurned: 0,
        steps: 0,
      });
      assert.equal(level, 1);
    });

    it('returns 2 for moderate workouts or steps', () => {
      const level = calculateActivityLevel({
        checkedIn: true,
        workoutMinutes: 20,
        metGoal: false,
        caloriesBurned: 160,
        steps: 6000,
      });
      assert.equal(level, 2);
    });

    it('returns 3 when daily workout goal is met', () => {
      const level = calculateActivityLevel({
        checkedIn: true,
        workoutMinutes: 32,
        metGoal: true,
        caloriesBurned: 240,
        steps: 7500,
      });
      assert.equal(level, 3);
    });

    it('returns 4 for high-intensity Beast Mode', () => {
      const level = calculateActivityLevel({
        checkedIn: true,
        workoutMinutes: 45,
        metGoal: true,
        caloriesBurned: 400,
        steps: 12000,
      });
      assert.equal(level, 4);
    });
  });

  describe('formatDuration', () => {
    it('formats seconds into clean hour and minute strings', () => {
      assert.equal(formatDuration(45), '0m');
      assert.equal(formatDuration(300), '5m');
      assert.equal(formatDuration(2520), '42m');
      assert.equal(formatDuration(4200), '1h 10m');
    });
  });

  describe('formatAppUsage', () => {
    it('formats active screen time into hour and minute strings', () => {
      assert.equal(formatAppUsage(0), '0h 0m');
      assert.equal(formatAppUsage(2520), '0h 42m');
      assert.equal(formatAppUsage(3600), '1h 0m');
      assert.equal(formatAppUsage(4320), '1h 12m');
    });
  });

  describe('buildStreakCalendar', () => {
    it('generates a full month calendar matrix with days and active stats', async () => {
      const store = new MemoryStore();
      await store.recordCheckin(mockUser.id, '2026-11-01', '2026-11-01T08:00:00Z');
      await store.recordCheckin(mockUser.id, '2026-11-02', '2026-11-02T08:00:00Z');

      const data = await buildStreakCalendar(mockUser, 2026, 11, store, '2026-11-02');
      assert.equal(data.year, 2026);
      assert.equal(data.month, 11);
      assert.equal(data.monthName, 'November');
      assert.equal(data.days.length, 30);
      assert.ok(data.currentStreak >= 1);
      assert.ok(data.longestStreak >= data.currentStreak);

      const day1 = data.days.find((d) => d.date === '2026-11-01');
      assert.ok(day1);
      assert.equal(day1?.checkedIn, true);
      assert.ok((day1?.level ?? 0) >= 1);
    });
  });

  describe('getDaySummary', () => {
    it('extracts complete day activity details for inspection', async () => {
      const store = new MemoryStore();
      await store.recordCheckin(mockUser.id, '2026-11-02', '2026-11-02T09:30:00Z');
      await store.recordAppUsage(mockUser.id, '2026-11-02', 1800);

      await store.upsertPlan({
        userId: mockUser.id,
        planDate: '2026-11-02',
        goalMin: 20,
        capacityMin: 30,
        achievedMin: 20,
        entries: [
          {
            exerciseSlug: 'barbell-bench-press',
            name: 'Barbell Bench Press',
            durationSec: 600,
            isCompleted: true,
          },
        ],
      });

      const summary = await getDaySummary(mockUser, '2026-11-02', store);
      assert.equal(summary.date, '2026-11-02');
      assert.equal(summary.checkedIn, true);
      assert.equal(summary.totalExercisesCompleted, 1);
      assert.equal(summary.exercisesCompleted[0].name, 'Barbell Bench Press');
      assert.ok(summary.appUsageSec >= 1800);
      assert.ok(summary.caloriesBurned > 0);
      assert.ok(summary.summaryNote.length > 5);
    });
  });

  describe('buildStreakLeaderboard', () => {
    it('creates podium and ranked leaderboard with user pinned', () => {
      const lb = buildStreakLeaderboard(mockUser.id, mockUser.displayHandle, 21);
      assert.equal(lb.podium.length, 3);
      assert.equal(lb.podium[0].rank, 1);
      assert.equal(lb.podium[0].badge, 'crown_gold');
      assert.ok(lb.allRanks.length >= 8);
      assert.ok(lb.self.isSelf);
      assert.equal(lb.self.handle, 'ayush_athlete');
    });
  });
});
