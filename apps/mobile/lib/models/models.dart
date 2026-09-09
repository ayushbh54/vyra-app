/// VYRA domain models.
///
/// These mirror `packages/types/src/api.ts` exactly. When that contract changes,
/// this file changes with it — that is the cost of not sharing a language
/// between the app and the server, and it is worth paying to keep Flutter.
///
/// Every `fromJson` is defensive: a missing or malformed field yields a sane
/// default rather than throwing. A crash on the home screen because one optional
/// number came back null is not an acceptable failure mode for a fitness app.
library;

double _d(dynamic v, [double fallback = 0]) =>
    v is num ? v.toDouble() : double.tryParse('$v') ?? fallback;

int _i(dynamic v, [int fallback = 0]) =>
    v is num ? v.toInt() : int.tryParse('$v') ?? fallback;

String _s(dynamic v, [String fallback = '']) => v is String ? v : fallback;

bool _b(dynamic v, [bool fallback = false]) => v is bool ? v : fallback;

// -----------------------------------------------------------------------------

class PlanEntry {
  final String exerciseSlug;
  final String name;
  final int durationSec;
  final bool isCompleted;
  final String? scheduledAt;

  const PlanEntry({
    required this.exerciseSlug,
    required this.name,
    required this.durationSec,
    required this.isCompleted,
    this.scheduledAt,
  });

  int get durationMin => (durationSec / 60).round();

  PlanEntry copyWith({bool? isCompleted}) => PlanEntry(
        exerciseSlug: exerciseSlug,
        name: name,
        durationSec: durationSec,
        isCompleted: isCompleted ?? this.isCompleted,
        scheduledAt: scheduledAt,
      );

  factory PlanEntry.fromJson(Map<String, dynamic> j) => PlanEntry(
        exerciseSlug: _s(j['exerciseSlug']),
        name: _s(j['name'], 'Exercise'),
        durationSec: _i(j['durationSec'], 60),
        isCompleted: _b(j['isCompleted']),
        scheduledAt: j['scheduledAt'] as String?,
      );
}

class WorkoutPlan {
  final String planDate;
  final int goalMin;
  final int capacityMin;
  final double achievedMin;
  final List<PlanEntry> entries;

  const WorkoutPlan({
    required this.planDate,
    required this.goalMin,
    required this.capacityMin,
    required this.achievedMin,
    required this.entries,
  });

  WorkoutPlan copyWith({
    List<PlanEntry>? entries,
    double? achievedMin,
  }) =>
      WorkoutPlan(
        planDate: planDate,
        goalMin: goalMin,
        capacityMin: capacityMin,
        achievedMin: achievedMin ?? this.achievedMin,
        entries: entries ?? this.entries,
      );

  int get completedCount => entries.where((e) => e.isCompleted).length;
  double get progress {
    if (entries.isNotEmpty && completedCount >= entries.length) return 1.0;
    return goalMin <= 0 ? 1 : (achievedMin / goalMin).clamp(0, 1);
  }
  int get remainingMin => (goalMin - achievedMin).ceil().clamp(0, 9999);

  factory WorkoutPlan.fromJson(Map<String, dynamic> j) => WorkoutPlan(
        planDate: _s(j['planDate']),
        goalMin: _i(j['goalMin']),
        capacityMin: _i(j['capacityMin']),
        achievedMin: _d(j['achievedMin']),
        entries: (j['entries'] as List? ?? [])
            .map((e) => PlanEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class FreeWindow {
  final String start;
  final String end;
  final int durationMin;
  final double suitability;
  final String rationale;

  const FreeWindow({
    required this.start,
    required this.end,
    required this.durationMin,
    required this.suitability,
    required this.rationale,
  });

  /// Label shown on the window chip. Thresholds match the Chrono Engine's
  /// own scoring bands so the app never contradicts the server.
  String get qualityLabel => suitability >= 0.8
      ? 'STRONG'
      : suitability >= 0.5
          ? 'USABLE'
          : 'GENTLE';

  factory FreeWindow.fromJson(Map<String, dynamic> j) => FreeWindow(
        start: _s(j['start']),
        end: _s(j['end']),
        durationMin: _i(j['durationMin']),
        suitability: _d(j['suitability']),
        rationale: _s(j['rationale']),
      );
}

/// The Adaptive Capacity Goal — the product's central idea, as data.
class Capacity {
  final int capacityMin;
  final double capacityFactor;
  final int idealTargetMin;
  final int dailyGoalMin;
  final int windowCount;
  final String explanation;

  const Capacity({
    required this.capacityMin,
    required this.capacityFactor,
    required this.idealTargetMin,
    required this.dailyGoalMin,
    required this.windowCount,
    required this.explanation,
  });

  bool get isRestDay => dailyGoalMin == 0;
  bool get wasScaledDown => capacityFactor < 1 && !isRestDay;

  factory Capacity.fromJson(Map<String, dynamic> j) => Capacity(
        capacityMin: _i(j['capacityMin']),
        capacityFactor: _d(j['capacityFactor'], 1),
        idealTargetMin: _i(j['idealTargetMin'], 30),
        dailyGoalMin: _i(j['dailyGoalMin']),
        windowCount: _i(j['windowCount']),
        explanation: _s(j['explanation']),
      );
}

class Effort {
  final double achievedMin;
  final int goalMin;
  final double effortRatio;
  final bool met;
  final String label; // rest_day | missed | partial | met | exceeded

  const Effort({
    required this.achievedMin,
    required this.goalMin,
    required this.effortRatio,
    required this.met,
    required this.label,
  });

  int get percent => (effortRatio * 100).round();

  factory Effort.fromJson(Map<String, dynamic> j) => Effort(
        achievedMin: _d(j['achievedMin']),
        goalMin: _i(j['goalMin']),
        effortRatio: _d(j['effortRatio']),
        met: _b(j['met']),
        label: _s(j['label'], 'missed'),
      );
}

class CoinBalance {
  final int balance;
  final int earnedTotal;
  final int spentTotal;
  final int level;
  final double levelProgress;
  final int coinsToNextLevel;
  final bool isMaxLevel;

  const CoinBalance({
    required this.balance,
    required this.earnedTotal,
    required this.spentTotal,
    required this.level,
    required this.levelProgress,
    required this.coinsToNextLevel,
    required this.isMaxLevel,
  });

  factory CoinBalance.fromJson(Map<String, dynamic> j) => CoinBalance(
        balance: _i(j['balance']),
        earnedTotal: _i(j['earnedTotal']),
        spentTotal: _i(j['spentTotal']),
        level: _i(j['level'], 1),
        levelProgress: _d(j['levelProgress']),
        coinsToNextLevel: _i(j['coinsToNextLevel']),
        isMaxLevel: _b(j['isMaxLevel']),
      );
}

class TodayData {
  final String date;
  final WorkoutPlan plan;
  final List<FreeWindow> windows;
  final Capacity capacity;
  final Effort effort;
  final CoinBalance coins;
  final bool dietEnabled;
  final String disclaimer;

  const TodayData({
    required this.date,
    required this.plan,
    required this.windows,
    required this.capacity,
    required this.effort,
    required this.coins,
    required this.dietEnabled,
    required this.disclaimer,
  });

  TodayData copyWith({WorkoutPlan? plan}) => TodayData(
        date: date,
        plan: plan ?? this.plan,
        windows: windows,
        capacity: capacity,
        effort: effort,
        coins: coins,
        dietEnabled: dietEnabled,
        disclaimer: disclaimer,
      );

  factory TodayData.fromJson(Map<String, dynamic> j) => TodayData(
        date: _s(j['date']),
        plan: WorkoutPlan.fromJson(j['plan'] as Map<String, dynamic>? ?? {}),
        windows: (j['windows'] as List? ?? [])
            .map((w) => FreeWindow.fromJson(w as Map<String, dynamic>))
            .toList(),
        capacity: Capacity.fromJson(j['capacity'] as Map<String, dynamic>? ?? {}),
        effort: Effort.fromJson(j['effort'] as Map<String, dynamic>? ?? {}),
        coins: CoinBalance.fromJson(j['coins'] as Map<String, dynamic>? ?? {}),
        // Absent means the user switched diet off. The key is omitted by the
        // server rather than sent as null, and the app must render nothing.
        dietEnabled: _b(j['dietEnabled']),
        disclaimer: _s(j['disclaimer']),
      );
}

class CoinOutcome {
  final String status; // applied | partially_applied | duplicate | cap_reached
  final String message;
  final int delta;
  final int capped;

  const CoinOutcome({
    required this.status,
    required this.message,
    required this.delta,
    required this.capped,
  });

  factory CoinOutcome.fromJson(Map<String, dynamic> j) => CoinOutcome(
        status: _s(j['status']),
        message: _s(j['message']),
        delta: _i(j['delta']),
        capped: _i(j['capped']),
      );
}

class CompleteResult {
  final Effort effort;
  final int streak;
  final List<CoinOutcome> coinOutcomes;
  final int balance;
  final int activityPoints;
  final int dailyCap;

  const CompleteResult({
    required this.effort,
    required this.streak,
    required this.coinOutcomes,
    required this.balance,
    required this.activityPoints,
    required this.dailyCap,
  });

  factory CompleteResult.fromJson(Map<String, dynamic> j) => CompleteResult(
        effort: Effort.fromJson(j['effort'] as Map<String, dynamic>? ?? {}),
        streak: _i(j['streak']),
        coinOutcomes: (j['coinOutcomes'] as List? ?? [])
            .map((o) => CoinOutcome.fromJson(o as Map<String, dynamic>))
            .toList(),
        balance: _i((j['balance'] as Map<String, dynamic>?)?['balance']),
        activityPoints: _i((j['points'] as Map<String, dynamic>?)?['activityPoints']),
        dailyCap: _i(j['dailyCap'], 150),
      );
}

class LibraryItem {
  final String slug;
  final String name;
  final String category;
  final String subcategory;
  final List<String> bodyParts;
  final String difficulty;
  final List<String> instructions;
  final String audioScript;
  final int defaultDurationSec;
  final List<String> equipment;
  final List<String> contraindications;
  final bool isSeatedFriendly;
  final bool isLowImpact;
  final List<String> isRecoveryFor;
  final String thumbnailUrl;
  final String gifUrl;

  const LibraryItem({
    required this.slug,
    required this.name,
    required this.category,
    required this.subcategory,
    required this.bodyParts,
    required this.difficulty,
    required this.instructions,
    required this.audioScript,
    required this.defaultDurationSec,
    required this.equipment,
    required this.contraindications,
    required this.isSeatedFriendly,
    required this.isLowImpact,
    required this.isRecoveryFor,
    required this.thumbnailUrl,
    required this.gifUrl,
  });

  static List<String> _strings(dynamic v) =>
      (v as List? ?? []).map((e) => '$e').toList();

  factory LibraryItem.fromJson(Map<String, dynamic> j) => LibraryItem(
        slug: _s(j['slug']),
        name: _s(j['name']),
        category: _s(j['category']),
        subcategory: _s(j['subcategory']),
        bodyParts: _strings(j['bodyParts']),
        difficulty: _s(j['difficulty'], 'beginner'),
        instructions: _strings(j['instructions']),
        audioScript: _s(j['audioScript']),
        defaultDurationSec: _i(j['defaultDurationSec'], 45),
        equipment: _strings(j['equipment']),
        contraindications: _strings(j['contraindications']),
        isSeatedFriendly: _b(j['isSeatedFriendly']),
        isLowImpact: _b(j['isLowImpact']),
        isRecoveryFor: _strings(j['isRecoveryFor']),
        thumbnailUrl: _s(j['thumbnailUrl']),
        gifUrl: _s(j['gifUrl']),
      );
}

class LeaderRow {
  final int rank;
  final String label;
  final int activityPoints;
  final String tier;
  final bool isSelf;

  const LeaderRow({
    required this.rank,
    required this.label,
    required this.activityPoints,
    required this.tier,
    required this.isSelf,
  });

  factory LeaderRow.fromJson(Map<String, dynamic> j) => LeaderRow(
        rank: _i(j['rank']),
        label: _s(j['label'], 'unknown'),
        activityPoints: _i(j['activityPoints']),
        tier: _s(j['tier'], 'bronze'),
        isSelf: _b(j['isSelf']),
      );
}

class Leaderboard {
  final String scope;
  final List<LeaderRow> rows;
  final int? selfRank;
  final int selfPoints;
  final String selfTier;
  final int pointsToNextTier;

  const Leaderboard({
    required this.scope,
    required this.rows,
    required this.selfRank,
    required this.selfPoints,
    required this.selfTier,
    required this.pointsToNextTier,
  });

  factory Leaderboard.fromJson(Map<String, dynamic> j) {
    final self = j['self'] as Map<String, dynamic>? ?? {};
    return Leaderboard(
      scope: _s(j['scope'], 'world'),
      rows: (j['rows'] as List? ?? [])
          .map((r) => LeaderRow.fromJson(r as Map<String, dynamic>))
          .toList(),
      selfRank: self['rank'] == null ? null : _i(self['rank']),
      selfPoints: _i(self['activityPoints']),
      selfTier: _s(self['tier'], 'bronze'),
      pointsToNextTier: _i(self['pointsToNextTier']),
    );
  }
}

class WalletData {
  final CoinBalance balance;
  final List<LedgerEntry> recent;
  final int todayEarned;
  final int dailyCap;

  const WalletData({
    required this.balance,
    required this.recent,
    required this.todayEarned,
    required this.dailyCap,
  });

  factory WalletData.fromJson(Map<String, dynamic> j) => WalletData(
        balance: CoinBalance.fromJson(j['balance'] as Map<String, dynamic>? ?? {}),
        recent: (j['recent'] as List? ?? [])
            .map((e) => LedgerEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        todayEarned: _i(j['todayEarned']),
        dailyCap: _i(j['dailyCap'], 150),
      );
}

class LedgerEntry {
  final int delta;
  final String reason;
  final String sourceType;
  final String createdAt;

  const LedgerEntry({
    required this.delta,
    required this.reason,
    required this.sourceType,
    required this.createdAt,
  });

  factory LedgerEntry.fromJson(Map<String, dynamic> j) => LedgerEntry(
        delta: _i(j['delta']),
        reason: _s(j['reason']),
        sourceType: _s(j['sourceType']),
        createdAt: _s(j['createdAt']),
      );
}

// -----------------------------------------------------------------------------
// Lab report
// -----------------------------------------------------------------------------

class LabFinding {
  final String label;
  final double value;
  final String unit;
  final String band;
  final String direction;
  final bool isCritical;
  final String summary;

  const LabFinding({
    required this.label,
    required this.value,
    required this.unit,
    required this.band,
    required this.direction,
    required this.isCritical,
    required this.summary,
  });

  bool get isNormal => band == 'normal';

  factory LabFinding.fromJson(Map<String, dynamic> j) => LabFinding(
        label: _s(j['label']),
        value: _d(j['value']),
        unit: _s(j['unit']),
        band: _s(j['band'], 'normal'),
        direction: _s(j['direction'], 'normal'),
        isCritical: _b(j['isCritical']),
        summary: _s(j['summary']),
      );
}

class DietAdjustment {
  final String label;
  final List<String> becauseOf;
  final List<String> foods;
  final String tip;
  final bool seeADoctor;

  const DietAdjustment({
    required this.label,
    required this.becauseOf,
    required this.foods,
    required this.tip,
    required this.seeADoctor,
  });

  factory DietAdjustment.fromJson(Map<String, dynamic> j) => DietAdjustment(
        label: _s(j['label']),
        becauseOf: (j['becauseOf'] as List? ?? []).map((e) => '$e').toList(),
        foods: (j['foods'] as List? ?? []).map((e) => '$e').toList(),
        tip: _s(j['tip']),
        seeADoctor: _b(j['seeADoctor']),
      );
}

class LabAnalysis {
  final bool noReadableMarkers;
  final List<LabFinding> findings;
  final bool urgentReferral;
  final List<String> urgentReasons;
  final List<DietAdjustment> adjustments;
  final List<String> suppressedAdvice;
  final String disclaimer;
  final String nextStep;

  const LabAnalysis({
    required this.noReadableMarkers,
    required this.findings,
    required this.urgentReferral,
    required this.urgentReasons,
    required this.adjustments,
    required this.suppressedAdvice,
    required this.disclaimer,
    required this.nextStep,
  });

  factory LabAnalysis.fromJson(Map<String, dynamic> j) => LabAnalysis(
        noReadableMarkers: _b(j['noReadableMarkers']),
        findings: (j['findings'] as List? ?? [])
            .map((f) => LabFinding.fromJson(f as Map<String, dynamic>))
            .toList(),
        urgentReferral: _b(j['urgentReferral']),
        urgentReasons: (j['urgentReasons'] as List? ?? []).map((e) => '$e').toList(),
        adjustments: (j['adjustments'] as List? ?? [])
            .map((a) => DietAdjustment.fromJson(a as Map<String, dynamic>))
            .toList(),
        suppressedAdvice: (j['suppressedAdvice'] as List? ?? []).map((e) => '$e').toList(),
        disclaimer: _s(j['disclaimer']),
        nextStep: _s(j['nextStep']),
      );
}

class SugarResult {
  final double sugarGrams;
  final int guidelineG;
  final int pctOfGuideline;
  final int zeroSugarStreak;
  final String? suggestionActivity;
  final String? suggestionCopy;
  final String disclaimer;

  const SugarResult({
    required this.sugarGrams,
    required this.guidelineG,
    required this.pctOfGuideline,
    required this.zeroSugarStreak,
    this.suggestionActivity,
    this.suggestionCopy,
    required this.disclaimer,
  });

  factory SugarResult.fromJson(Map<String, dynamic> j) {
    final sug = j['suggestion'] as Map<String, dynamic>?;
    return SugarResult(
      sugarGrams: _d(j['sugarGrams']),
      guidelineG: _i(j['guidelineG'], 50),
      pctOfGuideline: _i(j['pctOfGuideline']),
      zeroSugarStreak: _i(j['zeroSugarStreak']),
      suggestionActivity: sug == null ? null : _s(sug['activity']),
      suggestionCopy: sug == null ? null : _s(sug['copy']),
      disclaimer: _s(j['disclaimer']),
    );
  }
}

class MetricSeries {
  final String metric;
  final String unit;
  final List<double> values;
  final List<String> dates;
  final double? bandLow;
  final double? bandHigh;
  final String disclaimer;

  const MetricSeries({
    required this.metric,
    required this.unit,
    required this.values,
    required this.dates,
    this.bandLow,
    this.bandHigh,
    required this.disclaimer,
  });

  factory MetricSeries.fromJson(Map<String, dynamic> j) {
    final points = (j['points'] as List? ?? []).cast<Map<String, dynamic>>();
    final band = j['normalBand'] as Map<String, dynamic>?;
    return MetricSeries(
      metric: _s(j['metric']),
      unit: _s(j['unit']),
      values: points.map((p) => _d(p['value'])).toList(),
      dates: points.map((p) => _s(p['date'])).toList(),
      bandLow: band == null ? null : _d(band['low']),
      bandHigh: band == null ? null : _d(band['high']),
      disclaimer: _s(j['disclaimer']),
    );
  }
}

class Recipe {
  final String title;
  final List<({String name, String quantity})> ingredients;
  final List<String> steps;
  final int? cookTimeMin;
  final bool containsEgg;
  final bool containsMeat;
  final Map<String, double> nutrition;
  final String disclaimer;

  const Recipe({
    required this.title,
    required this.ingredients,
    required this.steps,
    this.cookTimeMin,
    required this.containsEgg,
    required this.containsMeat,
    required this.nutrition,
    required this.disclaimer,
  });

  factory Recipe.fromJson(Map<String, dynamic> j, String disclaimer) {
    final r = j['recipe'] as Map<String, dynamic>? ?? j;
    return Recipe(
      title: _s(r['title']),
      ingredients: (r['ingredients'] as List? ?? [])
          .map((e) => (
                name: _s((e as Map<String, dynamic>)['name']),
                quantity: _s(e['quantity']),
              ))
          .toList(),
      steps: (r['steps'] as List? ?? []).map((e) => '$e').toList(),
      cookTimeMin: r['cookTimeMin'] == null ? null : _i(r['cookTimeMin']),
      containsEgg: _b(r['containsEgg']),
      containsMeat: _b(r['containsMeat']),
      nutrition: ((r['nutrition'] as Map<String, dynamic>?) ?? {})
          .map((k, v) => MapEntry(k, _d(v))),
      disclaimer: disclaimer,
    );
  }
}

// -----------------------------------------------------------------------------
// Activities — GPS-recorded runs/rides, and the feed built from them
// -----------------------------------------------------------------------------

class RoutePoint {
  final double lat;
  final double lng;
  final int t;

  const RoutePoint({required this.lat, required this.lng, required this.t});

  factory RoutePoint.fromJson(Map<String, dynamic> j) =>
      RoutePoint(lat: _d(j['lat']), lng: _d(j['lng']), t: _i(j['t']));

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng, 't': t};
}

class ActivityItem {
  final String id;
  final String userId;
  final String type;
  final String title;
  final double distanceM;
  final int durationSec;
  final List<RoutePoint> route;
  final String startedAt;
  final String createdAt;
  final String authorHandle;
  final String authorName;
  final bool kudosGiven;
  final int commentCount;

  const ActivityItem({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.distanceM,
    required this.durationSec,
    required this.route,
    required this.startedAt,
    required this.createdAt,
    required this.authorHandle,
    required this.authorName,
    required this.kudosGiven,
    required this.commentCount,
  });

  double get distanceKm => distanceM / 1000;

  /// mm:ss per km — blank when there is no distance to divide by.
  String get pacePerKm {
    if (distanceKm <= 0) return '--';
    final secPerKm = durationSec / distanceKm;
    final m = (secPerKm ~/ 60);
    final s = (secPerKm % 60).round();
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String get durationLabel {
    final h = durationSec ~/ 3600;
    final m = (durationSec % 3600) ~/ 60;
    final s = durationSec % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m ${s}s';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'type': type,
        'title': title,
        'distanceM': distanceM,
        'durationSec': durationSec,
        'route': route.map((r) => r.toJson()).toList(),
        'startedAt': startedAt,
        'createdAt': createdAt,
        'authorHandle': authorHandle,
        'authorName': authorName,
        'kudosGiven': kudosGiven,
        'commentCount': commentCount,
      };

  factory ActivityItem.fromJson(Map<String, dynamic> j) => ActivityItem(
        id: _s(j['id']),
        userId: _s(j['userId']),
        type: _s(j['type'], 'run'),
        title: _s(j['title'], 'Activity'),
        distanceM: _d(j['distanceM']),
        durationSec: _i(j['durationSec']),
        route: (j['route'] as List? ?? [])
            .map((e) => RoutePoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        startedAt: _s(j['startedAt']),
        createdAt: _s(j['createdAt']),
        authorHandle: _s(j['authorHandle'], 'athlete'),
        authorName: _s(j['authorName'], 'VYRA athlete'),
        kudosGiven: _b(j['kudosGiven']),
        commentCount: _i(j['commentCount']),
      );
}

class ActivityComment {
  final String id;
  final String userId;
  final String text;
  final String authorHandle;
  final String createdAt;

  const ActivityComment({
    required this.id,
    required this.userId,
    required this.text,
    required this.authorHandle,
    required this.createdAt,
  });

  factory ActivityComment.fromJson(Map<String, dynamic> j) => ActivityComment(
        id: _s(j['id']),
        userId: _s(j['userId']),
        text: _s(j['text']),
        authorHandle: _s(j['authorHandle'], 'athlete'),
        createdAt: _s(j['createdAt']),
      );
}

// -----------------------------------------------------------------------------
// Follow / search
// -----------------------------------------------------------------------------

class SearchUser {
  final String id;
  final String handle;
  final String name;
  final bool following;

  const SearchUser({
    required this.id,
    required this.handle,
    required this.name,
    required this.following,
  });

  factory SearchUser.fromJson(Map<String, dynamic> j) => SearchUser(
        id: _s(j['id']),
        handle: _s(j['handle']),
        name: _s(j['name']),
        following: _b(j['following']),
      );
}

// -----------------------------------------------------------------------------
// Beacon — safety location sharing
// -----------------------------------------------------------------------------

class BeaconContact {
  final String name;
  final String phone;

  const BeaconContact({required this.name, required this.phone});

  factory BeaconContact.fromJson(Map<String, dynamic> j) =>
      BeaconContact(name: _s(j['name']), phone: _s(j['phone']));

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone};
}

class BeaconState {
  final bool enabled;
  final List<BeaconContact> contacts;

  const BeaconState({required this.enabled, required this.contacts});

  factory BeaconState.fromJson(Map<String, dynamic> j) => BeaconState(
        enabled: _b(j['enabled']),
        contacts: (j['contacts'] as List? ?? [])
            .map((e) => BeaconContact.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// -----------------------------------------------------------------------------
// Clubs & Events
// -----------------------------------------------------------------------------

class ClubItem {
  final String id;
  final String name;
  final String description;
  final String interestTag;
  final int memberCount;
  final bool joined;

  const ClubItem({
    required this.id,
    required this.name,
    required this.description,
    required this.interestTag,
    required this.memberCount,
    required this.joined,
  });

  factory ClubItem.fromJson(Map<String, dynamic> j) => ClubItem(
        id: _s(j['id']),
        name: _s(j['name']),
        description: _s(j['description']),
        interestTag: _s(j['interestTag']),
        memberCount: _i(j['memberCount']),
        joined: _b(j['joined']),
      );
}

class ClubPost {
  final String id;
  final String userId;
  final String body;
  final String authorHandle;
  final String createdAt;

  const ClubPost({
    required this.id,
    required this.userId,
    required this.body,
    required this.authorHandle,
    required this.createdAt,
  });

  factory ClubPost.fromJson(Map<String, dynamic> j) => ClubPost(
        id: _s(j['id']),
        userId: _s(j['userId']),
        body: _s(j['body']),
        authorHandle: _s(j['authorHandle'], 'athlete'),
        createdAt: _s(j['createdAt']),
      );
}

class EventItem {
  final String id;
  final String title;
  final String sport;
  final String location;
  final String startsAt;
  final bool registered;

  const EventItem({
    required this.id,
    required this.title,
    required this.sport,
    required this.location,
    required this.startsAt,
    required this.registered,
  });

  factory EventItem.fromJson(Map<String, dynamic> j) => EventItem(
        id: _s(j['id']),
        title: _s(j['title']),
        sport: _s(j['sport'], 'run'),
        location: _s(j['location']),
        startsAt: _s(j['startsAt']),
        registered: _b(j['registered']),
      );
}

// -----------------------------------------------------------------------------
// Movement definitions — the code-driven 3D exercise avatar's data feed
// -----------------------------------------------------------------------------

class MovementPhase {
  final String id;
  final String label;
  final String cue;
  final int durationSec;

  const MovementPhase({
    required this.id,
    required this.label,
    required this.cue,
    required this.durationSec,
  });

  factory MovementPhase.fromJson(Map<String, dynamic> j) => MovementPhase(
        id: _s(j['id']),
        label: _s(j['label']),
        cue: _s(j['cue']),
        durationSec: _i(j['durationSec']),
      );
}

// -----------------------------------------------------------------------------
// Posts — the Social-tab feed of free-form posts (separate from the
// Activity feed in feed.dart, which is generated from recorded Activities).
// -----------------------------------------------------------------------------

class PostItem {
  final String id;
  final String userId;
  final String body;
  final String? imageUrl;
  final String visibility; // public | followers
  final String authorHandle;
  final String authorName;
  final bool kudosGiven;
  final int kudosCount;
  final int commentCount;
  final String createdAt;

  const PostItem({
    required this.id,
    required this.userId,
    required this.body,
    this.imageUrl,
    required this.visibility,
    required this.authorHandle,
    required this.authorName,
    required this.kudosGiven,
    required this.kudosCount,
    required this.commentCount,
    required this.createdAt,
  });

  bool get isFollowersOnly => visibility == 'followers';

  factory PostItem.fromJson(Map<String, dynamic> j) => PostItem(
        id: _s(j['id']),
        userId: _s(j['userId']),
        body: _s(j['body']),
        imageUrl: (j['imageUrl'] as String?)?.isEmpty ?? true ? null : j['imageUrl'] as String?,
        visibility: _s(j['visibility'], 'public'),
        authorHandle: _s(j['authorHandle'], 'athlete'),
        authorName: _s(j['authorName'], 'VYRA athlete'),
        kudosGiven: _b(j['kudosGiven']),
        // The contract's /kudos response returns `count`, feed items don't
        // list one explicitly — default to 0 and let the kudos toggle fill it in.
        kudosCount: _i(j['kudosCount']),
        commentCount: _i(j['commentCount']),
        createdAt: _s(j['createdAt']),
      );
}

class PostComment {
  final String id;
  final String userId;
  final String body;
  final String authorHandle;
  final String createdAt;

  const PostComment({
    required this.id,
    required this.userId,
    required this.body,
    required this.authorHandle,
    required this.createdAt,
  });

  factory PostComment.fromJson(Map<String, dynamic> j) => PostComment(
        id: _s(j['id']),
        userId: _s(j['userId']),
        body: _s(j['body']),
        authorHandle: _s(j['authorHandle'], 'athlete'),
        createdAt: _s(j['createdAt']),
      );
}

// -----------------------------------------------------------------------------
// Rewards — the Perks Catalog, redeemable with coins earned elsewhere.
// -----------------------------------------------------------------------------

class RewardItem {
  final String id;
  final String title;
  final String description;
  final int coinCost;
  final String category;
  final int stock;

  const RewardItem({
    required this.id,
    required this.title,
    required this.description,
    required this.coinCost,
    required this.category,
    required this.stock,
  });

  bool get inStock => stock > 0;

  factory RewardItem.fromJson(Map<String, dynamic> j) => RewardItem(
        id: _s(j['id']),
        title: _s(j['title'], 'Reward'),
        description: _s(j['description']),
        coinCost: _i(j['coinCost']),
        category: _s(j['category'], 'general'),
        stock: _i(j['stock'], 1),
      );
}

class RewardRedemption {
  final String id;
  final String rewardId;
  final int coinCost;
  final String redeemedAt;

  const RewardRedemption({
    required this.id,
    required this.rewardId,
    required this.coinCost,
    required this.redeemedAt,
  });

  factory RewardRedemption.fromJson(Map<String, dynamic> j) => RewardRedemption(
        id: _s(j['id']),
        rewardId: _s(j['rewardId']),
        coinCost: _i(j['coinCost']),
        redeemedAt: _s(j['redeemedAt']),
      );
}

// -----------------------------------------------------------------------------
// Emergency contacts — distinct from Beacon (beacon.dart): these are for the
// hard "Call 112" / "Call my contact" moment, not live location sharing.
// -----------------------------------------------------------------------------

class EmergencyContact {
  final String id;
  final String name;
  final String phone;
  final String relationship;

  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.relationship,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> j) => EmergencyContact(
        id: _s(j['id']),
        name: _s(j['name']),
        phone: _s(j['phone']),
        relationship: _s(j['relationship'], 'Contact'),
      );
}

// -----------------------------------------------------------------------------
// Custom challenges — user-authored challenges with a daily check-in streak.
// -----------------------------------------------------------------------------

class CustomChallenge {
  final String id;
  final String title;
  final String rules;
  final int durationDays;
  final int streak;
  final bool checkedInToday;
  final String createdAt;

  const CustomChallenge({
    required this.id,
    required this.title,
    required this.rules,
    required this.durationDays,
    required this.streak,
    required this.checkedInToday,
    required this.createdAt,
  });

  CustomChallenge copyWith({int? streak, bool? checkedInToday}) => CustomChallenge(
        id: id,
        title: title,
        rules: rules,
        durationDays: durationDays,
        streak: streak ?? this.streak,
        checkedInToday: checkedInToday ?? this.checkedInToday,
        createdAt: createdAt,
      );

  factory CustomChallenge.fromJson(Map<String, dynamic> j) => CustomChallenge(
        id: _s(j['id']),
        title: _s(j['title'], 'Challenge'),
        rules: _s(j['rules']),
        durationDays: _i(j['durationDays'], 7),
        streak: _i(j['streak']),
        checkedInToday: _b(j['checkedInToday']),
        createdAt: _s(j['createdAt']),
      );
}

class MovementDefinition {
  final String exerciseSlug;
  final String rigId;
  final String tempo;
  final String targetMuscle;
  final List<MovementPhase> phases;
  final List<String> correctMechanics;
  final List<String> avoidCheats;

  const MovementDefinition({
    required this.exerciseSlug,
    required this.rigId,
    required this.tempo,
    required this.targetMuscle,
    required this.phases,
    required this.correctMechanics,
    required this.avoidCheats,
  });

  factory MovementDefinition.fromJson(Map<String, dynamic> j) => MovementDefinition(
        exerciseSlug: _s(j['exerciseSlug']),
        rigId: _s(j['rigId']),
        tempo: _s(j['tempo']),
        targetMuscle: _s(j['targetMuscle']),
        phases: (j['phases'] as List? ?? [])
            .map((e) => MovementPhase.fromJson(e as Map<String, dynamic>))
            .toList(),
        correctMechanics: (j['correctMechanics'] as List? ?? []).map((e) => e.toString()).toList(),
        avoidCheats: (j['avoidCheats'] as List? ?? []).map((e) => e.toString()).toList(),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// DIET CHART & CLINICAL NUTRITION MODELS
// ─────────────────────────────────────────────────────────────────────────────

class FoodToAvoid {
  final String item;
  final String category;
  final String reason;

  const FoodToAvoid({
    required this.item,
    required this.category,
    required this.reason,
  });

  factory FoodToAvoid.fromJson(Map<String, dynamic> j) => FoodToAvoid(
        item: _s(j['item']),
        category: _s(j['category']),
        reason: _s(j['reason']),
      );
}

class FoodToEat {
  final String item;
  final String category;
  final String benefit;
  final String howToConsume;

  const FoodToEat({
    required this.item,
    required this.category,
    required this.benefit,
    required this.howToConsume,
  });

  factory FoodToEat.fromJson(Map<String, dynamic> j) => FoodToEat(
        item: _s(j['item']),
        category: _s(j['category']),
        benefit: _s(j['benefit']),
        howToConsume: _s(j['howToConsume']),
      );
}

class DietMealSlot {
  final String slot;
  final String timeRange;
  final String title;
  final List<String> items;
  final String rationale;

  const DietMealSlot({
    required this.slot,
    required this.timeRange,
    required this.title,
    required this.items,
    required this.rationale,
  });

  factory DietMealSlot.fromJson(Map<String, dynamic> j) => DietMealSlot(
        slot: _s(j['slot']),
        timeRange: _s(j['timeRange']),
        title: _s(j['title']),
        items: (j['items'] as List? ?? []).map((e) => e.toString()).toList(),
        rationale: _s(j['rationale']),
      );
}

class HerbalRemedy {
  final String remedy;
  final String timing;
  final String purpose;

  const HerbalRemedy({
    required this.remedy,
    required this.timing,
    required this.purpose,
  });

  factory HerbalRemedy.fromJson(Map<String, dynamic> j) => HerbalRemedy(
        remedy: _s(j['remedy']),
        timing: _s(j['timing']),
        purpose: _s(j['purpose']),
      );
}

class DietChart {
  final String id;
  final String title;
  final String conditionSummary;
  final List<String> symptomsTargeted;
  final String dietaryPreference;
  final List<FoodToAvoid> foodsToAvoid;
  final List<FoodToEat> foodsToEat;
  final List<DietMealSlot> mealPlan;
  final List<String> hydrationGuidelines;
  final List<HerbalRemedy> herbalRemedies;
  final List<String> goldenRules;
  final String generatedAt;

  const DietChart({
    required this.id,
    required this.title,
    required this.conditionSummary,
    required this.symptomsTargeted,
    required this.dietaryPreference,
    required this.foodsToAvoid,
    required this.foodsToEat,
    required this.mealPlan,
    required this.hydrationGuidelines,
    required this.herbalRemedies,
    required this.goldenRules,
    required this.generatedAt,
  });

  factory DietChart.fromJson(Map<String, dynamic> j) => DietChart(
        id: _s(j['id']),
        title: _s(j['title']),
        conditionSummary: _s(j['conditionSummary']),
        symptomsTargeted: (j['symptomsTargeted'] as List? ?? []).map((e) => e.toString()).toList(),
        dietaryPreference: _s(j['dietaryPreference']),
        foodsToAvoid: (j['foodsToAvoid'] as List? ?? [])
            .map((e) => FoodToAvoid.fromJson(e as Map<String, dynamic>))
            .toList(),
        foodsToEat: (j['foodsToEat'] as List? ?? [])
            .map((e) => FoodToEat.fromJson(e as Map<String, dynamic>))
            .toList(),
        mealPlan: (j['mealPlan'] as List? ?? [])
            .map((e) => DietMealSlot.fromJson(e as Map<String, dynamic>))
            .toList(),
        hydrationGuidelines:
            (j['hydrationGuidelines'] as List? ?? []).map((e) => e.toString()).toList(),
        herbalRemedies: (j['herbalRemedies'] as List? ?? [])
            .map((e) => HerbalRemedy.fromJson(e as Map<String, dynamic>))
            .toList(),
        goldenRules: (j['goldenRules'] as List? ?? []).map((e) => e.toString()).toList(),
        generatedAt: _s(j['generatedAt']),
      );
}

class UserProfile {
  final String id;
  final String displayHandle;
  final String name;
  final String city;
  final String primarySport;
  final double weightKg;
  final double heightCm;
  final String dob;
  final String gender;
  final bool disabilityFlag;
  final bool accessibilityMode;
  final String disabilityType;
  final List<String> medicalConditions;
  final int onboardingStep;

  const UserProfile({
    required this.id,
    required this.displayHandle,
    required this.name,
    required this.city,
    required this.primarySport,
    required this.weightKg,
    required this.heightCm,
    required this.dob,
    required this.gender,
    required this.disabilityFlag,
    required this.accessibilityMode,
    required this.disabilityType,
    required this.medicalConditions,
    required this.onboardingStep,
  });

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        id: _s(j['id']),
        displayHandle: _s(j['displayHandle']),
        name: _s(j['name']),
        city: _s(j['city']),
        primarySport: _s(j['primarySport']),
        weightKg: _d(j['weightKg']),
        heightCm: _d(j['heightCm']),
        dob: _s(j['dob']),
        gender: _s(j['gender']),
        disabilityFlag: _b(j['disabilityFlag']),
        accessibilityMode: _b(j['accessibilityMode']),
        disabilityType: _s(j['disabilityType'], 'none'),
        medicalConditions:
            (j['medicalConditions'] as List? ?? []).map((e) => e.toString()).toList(),
        onboardingStep: _i(j['onboardingStep']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayHandle': displayHandle,
        'name': name,
        'city': city,
        'primarySport': primarySport,
        'weightKg': weightKg,
        'heightCm': heightCm,
        'dob': dob,
        'gender': gender,
        'disabilityFlag': disabilityFlag,
        'accessibilityMode': accessibilityMode,
        'disabilityType': disabilityType,
        'medicalConditions': medicalConditions,
        'onboardingStep': onboardingStep,
      };
}
