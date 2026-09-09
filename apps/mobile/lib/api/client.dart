import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// =============================================================================
/// VYRA API CLIENT
/// =============================================================================
/// Every network call goes through here, so three things are handled once
/// instead of on every screen:
///
///   1. The response envelope. The server always returns `{ok, data}` or
///      `{ok: false, error}`. Unwrapping in one place means no screen forgets.
///   2. Offline. Indian mobile data drops constantly. GET responses are cached,
///      so a plan already downloaded still opens on a train with no signal.
///   3. Auth. The token is attached once, and a 401 clears the session cleanly
///      rather than leaving the app half signed-in.
/// =============================================================================

class ApiException implements Exception {
  final String code;
  final String message;
  final int status;

  const ApiException(this.code, this.message, this.status);

  /// True when retrying might genuinely help — decides whether the UI offers
  /// a retry button or just explains what happened.
  bool get isRetryable => status == 0 || status >= 500 || code == 'RATE_LIMITED';

  @override
  String toString() => message;
}

class VyraApi {
  VyraApi({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? const String.fromEnvironment(
          'VYRA_API_URL',
          defaultValue: 'https://vyra-app.onrender.com',
        ),
        _http = client ?? http.Client();

  /// 10.0.2.2 is how the Android emulator reaches the host machine's localhost.
  /// On a physical phone, pass your computer's LAN IP:
  ///   flutter run --dart-define=VYRA_API_URL=http://192.168.1.5:4000
  final String baseUrl;
  final http.Client _http;

  static const _tokenKey = 'vyra.accessToken';
  static const _cachePrefix = 'vyra.cache.';

  String? _token;

  // ---------------------------------------------------------------------------
  // Session
  // ---------------------------------------------------------------------------

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
  }

  Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove(_tokenKey);
    } else {
      await prefs.setString(_tokenKey, token);
    }
  }

  bool get isSignedIn => _token != null;

  // ---------------------------------------------------------------------------
  // Transport
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? cacheKey,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = {
      'content-type': 'application/json',
      if (_token != null) 'authorization': 'Bearer $_token',
    };

    try {
      final http.Response res = await switch (method) {
        'POST' => _http.post(uri, headers: headers, body: jsonEncode(body ?? {})),
        'DELETE' => _http.delete(uri, headers: headers),
        _ => _http.get(uri, headers: headers),
      }
          .timeout(timeout);

      final decoded = jsonDecode(res.body) as Map<String, dynamic>;

      if (decoded['ok'] != true) {
        final err = decoded['error'] as Map<String, dynamic>? ?? {};
        // A dead token should sign the user out cleanly, not leave them tapping
        // a screen that silently fails.
        if (res.statusCode == 401) await setToken(null);
        throw ApiException(
          '${err['code'] ?? 'INTERNAL'}',
          '${err['message'] ?? 'Something went wrong.'}',
          res.statusCode,
        );
      }

      final data = decoded['data'];
      final map = data is Map<String, dynamic> ? data : <String, dynamic>{'value': data};

      if (method == 'GET' && cacheKey != null) {
        unawaited(_writeCache(cacheKey, map));
      }
      return map;
    } on ApiException {
      rethrow;
    } catch (e) {
      // Network failure. Serve the cache if we have one.
      if (method == 'GET' && cacheKey != null) {
        final cached = await _readCache(cacheKey);
        if (cached != null) return cached;
      }
      final isTimeout = e is TimeoutException;
      throw ApiException(
        isTimeout ? 'TIMEOUT' : 'OFFLINE',
        isTimeout
            ? 'That took too long. Check your connection and try again.'
            : 'You appear to be offline. Your progress is saved and will sync when you reconnect.',
        0,
      );
    }
  }

  Future<void> _writeCache(String key, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_cachePrefix$key', jsonEncode(data));
    } catch (_) {
      // A cache write failing must never break the request that succeeded.
    }
  }

  Future<Map<String, dynamic>?> _readCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_cachePrefix$key');
      return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Endpoints
  // ---------------------------------------------------------------------------

  Future<bool> health() async {
    final j = await _request('GET', '/health');
    return j['ok'] == true;
  }

  /// One-tap demo account. Presets: student, nurse, homemaker, open.
  Future<void> startDemoSession(String preset) async {
    final j = await _request('POST', '/v1/demo/session', body: {'preset': preset});
    await setToken('${j['accessToken']}');
  }

  /// Real account creation — only name/email/password are required here.
  /// Everything else (body info, goals, activities...) is collected by the
  /// onboarding flow right after and saved via [completeOnboarding].
  /// Returns the new account's onboarding step (always 0 for a fresh signup).
  Future<int> signUp({required String name, required String email, required String password}) async {
    final j = await _request('POST', '/v1/auth/signup', body: {
      'name': name, 'email': email, 'password': password,
    });
    await setToken('${j['accessToken']}');
    return 0;
  }

  /// Returns the account's onboarding step so the caller knows whether to
  /// resume onboarding or go straight to the home feed.
  Future<int> logIn({required String email, required String password}) async {
    final j = await _request('POST', '/v1/auth/login', body: {'email': email, 'password': password});
    await setToken('${j['accessToken']}');
    return (j['onboardingStep'] as num?)?.toInt() ?? 0;
  }

  /// Authenticates using Google identity / token, links account and returns onboardingStep.
  Future<int> logInWithGoogle({String? idToken, required String email, String? name, String? googleId}) async {
    final j = await _request('POST', '/v1/auth/google', body: {
      if (idToken != null && idToken.isNotEmpty) 'idToken': idToken,
      'email': email,
      if (name != null && name.isNotEmpty) 'name': name,
      if (googleId != null && googleId.isNotEmpty) 'googleId': googleId,
    });
    await setToken('${j['accessToken']}');
    return (j['onboardingStep'] as num?)?.toInt() ?? 0;
  }

  /// Resets an account password with secure verification.
  Future<String> resetPassword({required String email, required String newPassword}) async {
    final j = await _request('POST', '/v1/auth/reset-password', body: {
      'email': email,
      'newPassword': newPassword,
    });
    return j['message'] as String? ?? 'Password updated successfully.';
  }

  /// Fills in everything signup deliberately skipped, and marks the account
  /// ready (onboardingStep = 9 on the backend). Fields left null keep
  /// whatever the account already has.
  Future<void> completeOnboarding({
    String? name,
    String? dob,
    String? gender,
    double? heightCm,
    double? weightKg,
    bool? disabilityFlag,
    bool? accessibilityMode,
    String? fitnessGoal,
    bool? dietToggle,
    String? dietPreference,
    String? city,
    String? primarySport,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (dob != null) body['dob'] = dob;
    if (gender != null) body['gender'] = gender;
    if (heightCm != null) body['heightCm'] = heightCm;
    if (weightKg != null) body['weightKg'] = weightKg;
    if (disabilityFlag != null) body['disabilityFlag'] = disabilityFlag;
    if (accessibilityMode != null) body['accessibilityMode'] = accessibilityMode;
    if (fitnessGoal != null) body['fitnessGoal'] = fitnessGoal;
    if (dietToggle != null) body['dietToggle'] = dietToggle;
    if (dietPreference != null) body['dietPreference'] = dietPreference;
    if (city != null) body['city'] = city;
    if (primarySport != null) body['primarySport'] = primarySport;
    await _request('POST', '/v1/onboarding/complete', body: body);
  }

  Future<TodayData> today() async {
    return TodayData.fromJson(await _request('GET', '/v1/today', cacheKey: 'today'));
  }

  Future<List<LibraryItem>> library({
    String? category,
    bool seatedOnly = false,
    String? search,
  }) async {
    final q = <String, String>{
      if (category != null) 'category': category,
      if (seatedOnly) 'seatedOnly': 'true',
      if (search != null && search.isNotEmpty) 'search': search,
    };
    final qs = q.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    final j = await _request('GET', '/v1/library?$qs', cacheKey: 'library.$qs');
    return (j['items'] as List? ?? [])
        .map((e) => LibraryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CompleteResult> completeExercise(String slug, int actualDurationSec) async {
    return CompleteResult.fromJson(await _request(
      'POST',
      '/v1/workout/complete',
      body: {'exerciseSlug': slug, 'actualDurationSec': actualDurationSec},
    ));
  }

  /// Null when this exercise has no 3D animation yet — most of the library
  /// doesn't, by design (see the movement-definitions MVP scope).
  Future<MovementDefinition?> movementFor(String exerciseSlug) async {
    final j = await _request('GET', '/v1/exercises/$exerciseSlug/movement');
    final def = j['definition'];
    return def == null ? null : MovementDefinition.fromJson(def as Map<String, dynamic>);
  }

  Future<void> saveSchedule(List<Map<String, dynamic>> blocks) async {
    await _request('POST', '/v1/schedule', body: {'blocks': blocks});
  }

  Future<String?> logTracking(Map<String, num> values, {String? source}) async {
    final body = <String, dynamic>{...values};
    if (source != null) body['source'] = source;
    final j = await _request('POST', '/v1/tracking', body: body);
    final outcome = j['coinOutcome'] as Map<String, dynamic>?;
    return outcome == null ? null : '${outcome['message']}';
  }

  Future<MetricSeries> trackingSeries(String metric) async {
    return MetricSeries.fromJson(
      await _request('GET', '/v1/tracking/series?metric=$metric', cacheKey: 'series.$metric'),
    );
  }

  Future<SugarResult> logSugar(double grams) async {
    return SugarResult.fromJson(
      await _request('POST', '/v1/sugar', body: {'sugarGrams': grams}),
    );
  }

  Future<WalletData> wallet() async {
    return WalletData.fromJson(await _request('GET', '/v1/wallet', cacheKey: 'wallet'));
  }

  Future<Leaderboard> leaderboard({String scope = 'world'}) async {
    final s = scope == 'global' ? 'world' : scope;
    return Leaderboard.fromJson(
      await _request('GET', '/v1/leaderboard?scope=$s', cacheKey: 'lb.$s'),
    );
  }

  Future<Recipe> generateRecipe(List<String> ingredients) async {
    // Generation is slower than a normal request, so it gets its own timeout
    // rather than inheriting one tuned for plain reads.
    final j = await _request(
      'POST',
      '/v1/ai/recipe',
      body: {'ingredients': ingredients},
      timeout: const Duration(seconds: 35),
    );
    return Recipe.fromJson(j, '${j['disclaimer'] ?? ''}');
  }

  Future<DietChart> generateDietChart({
    required List<String> symptoms,
    String? customCondition,
    String? preference,
  }) async {
    final j = await _request(
      'POST',
      '/v1/ai/diet-chart',
      body: {
        'symptoms': symptoms,
        if (customCondition != null && customCondition.isNotEmpty) 'customCondition': customCondition,
        if (preference != null && preference.isNotEmpty) 'preference': preference,
      },
      timeout: const Duration(seconds: 40),
    );
    return DietChart.fromJson(j);
  }

  Future<LabAnalysis> analyseLabReport(List<Map<String, dynamic>> readings) async {
    return LabAnalysis.fromJson(
      await _request('POST', '/v1/lab-report', body: {'readings': readings}),
    );
  }

  Future<List<Map<String, dynamic>>> missedDays() async {
    final j = await _request('GET', '/v1/missed');
    return (j['missed'] as List? ?? []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> rebalancePreview(String missedDate) async {
    return _request('POST', '/v1/rebalance/preview', body: {'missedDate': missedDate});
  }

  Future<Map<String, dynamic>> exportMyData() async {
    return _request('GET', '/v1/privacy/export');
  }

  Future<void> eraseAccount() async {
    await _request('DELETE', '/v1/privacy/erase');
    await setToken(null);
  }

  // ---------------------------------------------------------------------------
  // Activities / Feed — the Record tab and the Home feed
  // ---------------------------------------------------------------------------

  Future<ActivityItem> createActivity({
    required String type,
    required String title,
    required double distanceM,
    required int durationSec,
    required List<RoutePoint> route,
    required DateTime startedAt,
    int? stepCount,        // from Health Connect — null if unavailable
  }) async {
    final body = <String, dynamic>{
      'type': type,
      'title': title,
      'distanceM': distanceM,
      'durationSec': durationSec,
      'route': route.map((p) => p.toJson()).toList(),
      'startedAt': startedAt.toIso8601String(),
      if (stepCount != null && stepCount > 0) 'stepCount': stepCount,
    };
    final j = await _request('POST', '/v1/activities', body: body);
    return ActivityItem.fromJson(j['activity'] as Map<String, dynamic>);
  }

  Future<List<ActivityItem>> feed({int limit = 20}) async {
    final j = await _request('GET', '/v1/feed?limit=$limit', cacheKey: 'feed');
    return (j['items'] as List? ?? [])
        .map((e) => ActivityItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ActivityItem>> myActivities({int limit = 50}) async {
    final j = await _request('GET', '/v1/activities/mine?limit=$limit', cacheKey: 'my_activities');
    return (j['items'] as List? ?? [])
        .map((e) => ActivityItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<bool> toggleKudos(String activityId) async {
    final j = await _request('POST', '/v1/activities/$activityId/kudos');
    return j['given'] == true;
  }

  Future<List<ActivityComment>> comments(String activityId) async {
    final j = await _request('GET', '/v1/activities/$activityId/comments');
    return (j['items'] as List? ?? [])
        .map((e) => ActivityComment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ActivityComment> addComment(String activityId, String text) async {
    final j = await _request('POST', '/v1/activities/$activityId/comments', body: {'text': text});
    return ActivityComment.fromJson(j['comment'] as Map<String, dynamic>);
  }

  // ---------------------------------------------------------------------------
  // Follow / search
  // ---------------------------------------------------------------------------

  Future<List<SearchUser>> searchUsers(String query) async {
    final j = await _request('GET', '/v1/users/search?q=${Uri.encodeComponent(query)}');
    return (j['items'] as List? ?? [])
        .map((e) => SearchUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> follow(String userId) async {
    await _request('POST', '/v1/follow/$userId');
  }

  Future<void> unfollow(String userId) async {
    await _request('DELETE', '/v1/follow/$userId');
  }

  // ---------------------------------------------------------------------------
  // Beacon — safety location sharing
  // ---------------------------------------------------------------------------

  Future<BeaconState> beacon() async {
    return BeaconState.fromJson(await _request('GET', '/v1/beacon', cacheKey: 'beacon'));
  }

  Future<BeaconState> setBeacon(bool enabled, List<BeaconContact> contacts) async {
    return BeaconState.fromJson(await _request('POST', '/v1/beacon', body: {
      'enabled': enabled,
      'contacts': contacts.map((c) => c.toJson()).toList(),
    }));
  }

  // ---------------------------------------------------------------------------
  // Profile edit
  // ---------------------------------------------------------------------------

  Future<UserProfile> getProfile() async {
    final j = await _request('GET', '/v1/me', cacheKey: 'profile.me');
    return UserProfile.fromJson(j);
  }

  Future<Map<String, dynamic>> me() async {
    return _request('GET', '/v1/me');
  }

  Future<void> updateProfile({
    String? name,
    String? city,
    String? primarySport,
    double? weightKg,
    bool? disabilityFlag,
    bool? accessibilityMode,
    String? disabilityType,
    List<String>? medicalConditions,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (city != null) body['city'] = city;
    if (primarySport != null) body['primarySport'] = primarySport;
    if (weightKg != null) body['weightKg'] = weightKg;
    if (disabilityFlag != null) body['disabilityFlag'] = disabilityFlag;
    if (accessibilityMode != null) body['accessibilityMode'] = accessibilityMode;
    if (disabilityType != null) body['disabilityType'] = disabilityType;
    if (medicalConditions != null) body['medicalConditions'] = medicalConditions;
    await _request('PATCH', '/v1/me', body: body);
  }

  // ---------------------------------------------------------------------------
  // Clubs
  // ---------------------------------------------------------------------------

  Future<List<ClubItem>> clubs() async {
    final j = await _request('GET', '/v1/clubs', cacheKey: 'clubs');
    return (j['items'] as List? ?? []).map((e) => ClubItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> joinClub(String clubId) async {
    await _request('POST', '/v1/clubs/$clubId/join');
  }

  Future<void> leaveClub(String clubId) async {
    await _request('DELETE', '/v1/clubs/$clubId/join');
  }

  Future<List<ClubPost>> clubPosts(String clubId) async {
    final j = await _request('GET', '/v1/clubs/$clubId/posts');
    return (j['items'] as List? ?? []).map((e) => ClubPost.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ClubPost> addClubPost(String clubId, String body) async {
    final j = await _request('POST', '/v1/clubs/$clubId/posts', body: {'body': body});
    return ClubPost.fromJson(j['post'] as Map<String, dynamic>);
  }

  // ---------------------------------------------------------------------------
  // Events
  // ---------------------------------------------------------------------------

  Future<List<EventItem>> events() async {
    final j = await _request('GET', '/v1/events', cacheKey: 'events');
    return (j['items'] as List? ?? []).map((e) => EventItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> registerForEvent(String eventId) async {
    await _request('POST', '/v1/events/$eventId/register');
  }

  Future<void> unregisterFromEvent(String eventId) async {
    await _request('DELETE', '/v1/events/$eventId/register');
  }

  // ---------------------------------------------------------------------------
  // Posts — Social tab, free-form posts (distinct from the Activity feed above)
  // ---------------------------------------------------------------------------

  Future<PostItem> createPost({
    required String body,
    String? imageUrl,
    String visibility = 'public',
    String? linkedActivityId,
  }) async {
    final j = await _request('POST', '/v1/posts', body: {
      'body': body,
      if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
      'visibility': visibility,
      if (linkedActivityId != null) 'linkedActivityId': linkedActivityId,
    });
    return PostItem.fromJson(j['post'] as Map<String, dynamic>);
  }

  Future<List<PostItem>> postsFeed() async {
    final j = await _request('GET', '/v1/posts/feed', cacheKey: 'posts_feed');
    return (j['items'] as List? ?? []).map((e) => PostItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<PostItem>> myPosts() async {
    final j = await _request('GET', '/v1/posts/mine', cacheKey: 'my_posts');
    return (j['items'] as List? ?? []).map((e) => PostItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PostItem> updatePost(String postId, {String? body, String? visibility}) async {
    final b = <String, dynamic>{};
    if (body != null) b['body'] = body;
    if (visibility != null) b['visibility'] = visibility;
    final j = await _request('PATCH', '/v1/posts/$postId', body: b);
    return PostItem.fromJson(j['post'] as Map<String, dynamic>);
  }

  Future<void> deletePost(String postId) async {
    await _request('DELETE', '/v1/posts/$postId');
  }

  Future<bool> togglePostKudos(String postId) async {
    final j = await _request('POST', '/v1/posts/$postId/kudos');
    return j['given'] == true;
  }

  Future<List<PostComment>> postComments(String postId) async {
    final j = await _request('GET', '/v1/posts/$postId/comments');
    return (j['items'] as List? ?? [])
        .map((e) => PostComment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PostComment> addPostComment(String postId, String body) async {
    final j = await _request('POST', '/v1/posts/$postId/comments', body: {'body': body});
    return PostComment.fromJson(j['comment'] as Map<String, dynamic>);
  }

  // ---------------------------------------------------------------------------
  // Rewards — Perks Catalog, lives in the Challenges tab
  // ---------------------------------------------------------------------------

  Future<List<RewardItem>> rewards() async {
    final j = await _request('GET', '/v1/rewards', cacheKey: 'rewards');
    return (j['items'] as List? ?? []).map((e) => RewardItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Throws [ApiException] with a message like "not enough coins" when the
  /// balance can't cover [rewardId]'s cost — the screen shows `e.message` as-is.
  Future<RewardRedemption> redeemReward(String rewardId) async {
    final j = await _request('POST', '/v1/rewards/$rewardId/redeem');
    return RewardRedemption.fromJson(j['redemption'] as Map<String, dynamic>);
  }

  Future<List<RewardRedemption>> myRedemptions() async {
    final j = await _request('GET', '/v1/rewards/redemptions/mine', cacheKey: 'my_redemptions');
    return (j['items'] as List? ?? [])
        .map((e) => RewardRedemption.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Emergency contacts — distinct from Beacon; max 3, surfaced from Profile
  // ---------------------------------------------------------------------------

  Future<List<EmergencyContact>> emergencyContacts() async {
    final j = await _request('GET', '/v1/emergency-contacts', cacheKey: 'emergency_contacts');
    return (j['items'] as List? ?? [])
        .map((e) => EmergencyContact.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Response shape for a single created contact isn't specified in the
  /// contract — this assumes `{contact: {...}}`, falling back to the raw
  /// envelope if the field is absent.
  Future<EmergencyContact> addEmergencyContact({
    required String name,
    required String phone,
    required String relationship,
  }) async {
    final j = await _request('POST', '/v1/emergency-contacts', body: {
      'name': name,
      'phone': phone,
      'relationship': relationship,
    });
    return EmergencyContact.fromJson((j['contact'] as Map<String, dynamic>?) ?? j);
  }

  Future<void> deleteEmergencyContact(String contactId) async {
    await _request('DELETE', '/v1/emergency-contacts/$contactId');
  }

  // ---------------------------------------------------------------------------
  // Custom challenges — user-authored, with a daily check-in streak
  // ---------------------------------------------------------------------------

  /// Response shape isn't specified in the contract — this assumes
  /// `{challenge: {...}}`, falling back to the raw envelope if absent.
  Future<CustomChallenge> createCustomChallenge({
    required String title,
    required String rules,
    required int durationDays,
  }) async {
    final j = await _request('POST', '/v1/challenges/custom', body: {
      'title': title,
      'rules': rules,
      'durationDays': durationDays,
    });
    return CustomChallenge.fromJson((j['challenge'] as Map<String, dynamic>?) ?? j);
  }

  Future<int> checkinChallenge(String challengeId) async {
    final j = await _request('POST', '/v1/challenges/$challengeId/checkin');
    return (j['streak'] as num?)?.toInt() ?? 0;
  }

  /// ASSUMED endpoint — not in the given backend contract, which only lists
  /// create + checkin for custom challenges. Without a list endpoint there is
  /// no way to render the user's existing challenges or their streaks, so this
  /// assumes `GET /v1/challenges/custom/mine -> {items: [...]}` matching the
  /// shape of a single challenge from create/checkin. Flag this to the backend
  /// so it can be added or this call adjusted to the real path.
  Future<List<CustomChallenge>> myCustomChallenges() async {
    final j = await _request('GET', '/v1/challenges/custom/mine', cacheKey: 'my_challenges');
    return (j['items'] as List? ?? [])
        .map((e) => CustomChallenge.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // AI Chat — Gemini-powered coach conversation
  // ---------------------------------------------------------------------------

  /// Sends a message to the AI coach and returns the reply + conversationId.
  /// Pass [conversationId] on subsequent turns for threading.
  Future<Map<String, dynamic>> chatMessage(
    String message, {
    String? conversationId,
  }) async {
    final body = <String, dynamic>{'message': message};
    if (conversationId != null) body['conversationId'] = conversationId;
    return _request('POST', '/v1/chat/message', body: body);
  }

  // ---------------------------------------------------------------------------
  // Food Scan — AI vision nutrition analysis
  // ---------------------------------------------------------------------------

  /// Uploads a base64 image to /v1/food/scan and returns items + disclaimer.
  Future<Map<String, dynamic>> scanFood({
    required String imageBase64,
    required String mimeType,
  }) async {
    return _request('POST', '/v1/food/scan', body: {
      'imageBase64': imageBase64,
      'mimeType': mimeType,
    });
  }

  // ---------------------------------------------------------------------------
  // Lab Report — AI marker analysis (diet-only, no medicine)
  // ---------------------------------------------------------------------------

  /// Uploads a base64 lab report image and returns findings + diet adjustments.
  Future<Map<String, dynamic>> scanLabReport({
    required String imageBase64,
    required String mimeType,
  }) async {
    return _request('POST', '/v1/lab-report/analyse', body: {
      'imageBase64': imageBase64,
      'mimeType': mimeType,
    });
  }

  // ---------------------------------------------------------------------------
  // Safety & Moderation
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> reportUser({
    required String reportedUserId,
    required String reason,
    String? detail,
  }) async {
    final body = <String, dynamic>{
      'reportedUserId': reportedUserId,
      'reason': reason,
    };
    if (detail != null && detail.isNotEmpty) body['detail'] = detail;
    return _request('POST', '/v1/reports', body: body);
  }

  Future<Map<String, dynamic>> blockUser(String userId) async {
    return _request('POST', '/v1/blocks/$userId');
  }

  Future<Map<String, dynamic>> unblockUser(String userId) async {
    return _request('DELETE', '/v1/blocks/$userId');
  }

  Future<List<dynamic>> listBlocked() async {
    final j = await _request('GET', '/v1/blocks');
    return (j['items'] as List?) ?? [];
  }
}
