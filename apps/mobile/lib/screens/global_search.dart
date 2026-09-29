import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/screen_scaffold.dart';
import 'athlete_chat.dart';
import 'exercise_detail.dart';
import 'face_hair_yoga.dart';

enum SearchCategory { all, users, clubs, events, workouts, posts }

class SearchResultItem {
  SearchResultItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    this.handle,
    this.avatarUrl,
    this.badge,
    this.detail,
    this.isVerified = false,
    this.meta,
  });

  final String id;
  final String title;
  final String subtitle;
  final SearchCategory category;
  final String? handle;
  final String? avatarUrl;
  final String? badge;
  final String? detail;
  final bool isVerified;
  final dynamic meta;
}

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({this.initialQuery, super.key});

  final String? initialQuery;

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _searchController = TextEditingController();
  SearchCategory _selectedCategory = SearchCategory.all;
  Timer? _debounce;
  bool _isLoading = false;
  List<SearchResultItem> _results = [];
  final Set<String> _followingIds = {};

  final List<String> _trendingSearches = [
    'Face Yoga Jawline',
    'Berlin Dawn Sprinters',
    'Night Cyber 10K',
    'Keto Macro Bowl',
    'Scalp Vitality Inversion',
    'HIIT Core Blaster',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _executeSearch(_searchController.text.trim());
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _executeSearch(value.trim());
    });
  }

  Future<void> _executeSearch(String query) async {
    setState(() => _isLoading = true);

    final q = query.toLowerCase();
    final List<SearchResultItem> matches = [];

    // 1. Built-in Athletes / Users
    final sampleUsers = [
      SearchResultItem(
        id: 'u-vance',
        title: 'Alex Vance',
        handle: '@alexvance',
        subtitle: 'Endurance Runner • Berlin',
        category: SearchCategory.users,
        isVerified: true,
        badge: 'ATHLETE',
      ),
      SearchResultItem(
        id: 'u-elena',
        title: 'Elena Rostova',
        handle: '@rostova_run',
        subtitle: 'Ultra-Marathoner • Tiergarten Club',
        category: SearchCategory.users,
        isVerified: true,
        badge: 'PRO',
      ),
      SearchResultItem(
        id: 'u-marcus',
        title: 'Marcus Chen',
        handle: '@marcus_iron',
        subtitle: 'Hyrox Pro & Powerlifter',
        category: SearchCategory.users,
        isVerified: false,
      ),
      SearchResultItem(
        id: 'u-priya',
        title: 'Priya Sharma',
        handle: '@priyayoga',
        subtitle: 'Vinyasa & Face Yoga Specialist',
        category: SearchCategory.users,
        isVerified: true,
        badge: 'COACH',
      ),
    ];

    // 2. Clubs / Communities
    final sampleClubs = [
      SearchResultItem(
        id: 'c-berlin',
        title: 'Berlin Dawn Sprinters',
        subtitle: '542 Members • Running & Track Club',
        category: SearchCategory.clubs,
        badge: 'VERIFIED CLUB',
      ),
      SearchResultItem(
        id: 'c-night-riders',
        title: 'Obsidian Peloton Riders',
        subtitle: '1,280 Members • Cyber Cycling & Cadence',
        category: SearchCategory.clubs,
        badge: 'ACTIVE SQUAD',
      ),
      SearchResultItem(
        id: 'c-face-vitality',
        title: 'Facial & Scalp Yoga Society',
        subtitle: '340 Members • Natural Sculpt & Prana',
        category: SearchCategory.clubs,
      ),
    ];

    // 3. Events
    final sampleEvents = [
      SearchResultItem(
        id: 'e-marathon',
        title: 'Night Cyber 10K Marathon',
        subtitle: 'Nov 12, 2025 • Brandenburg Gate, Berlin',
        category: SearchCategory.events,
        badge: 'OFFICIAL RACE',
      ),
      SearchResultItem(
        id: 'e-sunrise-yoga',
        title: 'Vernal Equinox 108 Sun Salutations',
        subtitle: 'Saturday 06:00 AM • Tiergarten Lawn',
        category: SearchCategory.events,
        badge: 'OUTDOOR',
      ),
    ];

    // 4. Exercise / Workout Library Items from API
    try {
      final items = await context.read<VyraApi>().library();
      for (final it in items) {
        if (q.isEmpty ||
            it.name.toLowerCase().contains(q) ||
            it.category.toLowerCase().contains(q) ||
            it.subcategory.toLowerCase().contains(q)) {
          matches.add(
            SearchResultItem(
              id: 'ex-${it.slug}',
              title: it.name,
              subtitle: '${it.category.toUpperCase()} • ${it.difficulty} • ${(it.defaultDurationSec / 60).ceil()} min',
              category: SearchCategory.workouts,
              badge: it.subcategory.toUpperCase(),
              meta: it,
            ),
          );
        }
      }
    } catch (_) {}

    // Add Face & Hair Yoga entries
    final yogaWorkouts = [
      SearchResultItem(
        id: 'fy-jawline',
        title: 'Jawline Sculpt & Platysma Lift',
        subtitle: 'FACE YOGA • 4 Minutes • Daily Tone',
        category: SearchCategory.workouts,
        badge: 'FACE YOGA',
      ),
      SearchResultItem(
        id: 'fy-cheekbone',
        title: 'Cheekbone Contouring & Buccal Glow',
        subtitle: 'FACE YOGA • 3 Minutes • Lymph Drainage',
        category: SearchCategory.workouts,
        badge: 'FACE YOGA',
      ),
      SearchResultItem(
        id: 'hy-inversion',
        title: 'Adho Mukha Hair Follicle Perfusion',
        subtitle: 'SCALP YOGA • 5 Minutes • Blood Perfusion',
        category: SearchCategory.workouts,
        badge: 'HAIR YOGA',
      ),
    ];

    // 5. Community Posts
    final samplePosts = [
      SearchResultItem(
        id: 'p-1',
        title: 'Elena Rostova',
        subtitle: 'Tiergarten Trail • 2h ago • 84 Kudos',
        category: SearchCategory.posts,
        detail: 'Crushed new half-marathon PR at 1:28:14 through Tiergarten with @alexvance and the Berlin Dawn crew! Pace remained sub 4:10/km throughout.',
      ),
      SearchResultItem(
        id: 'p-2',
        title: 'Alex Vance',
        subtitle: 'Olympic Stadium • 5h ago • 142 Kudos',
        category: SearchCategory.posts,
        detail: 'Zone 2 aerobic threshold session dialed in. Heart rate stayed at a flat 142 BPM across 18 km.',
      ),
    ];

    // Filter by query
    for (final u in sampleUsers) {
      if (q.isEmpty ||
          u.title.toLowerCase().contains(q) ||
          (u.handle?.toLowerCase().contains(q) ?? false) ||
          u.subtitle.toLowerCase().contains(q)) {
        matches.add(u);
      }
    }
    for (final c in sampleClubs) {
      if (q.isEmpty || uContains(c.title, q) || uContains(c.subtitle, q)) {
        matches.add(c);
      }
    }
    for (final e in sampleEvents) {
      if (q.isEmpty || uContains(e.title, q) || uContains(e.subtitle, q)) {
        matches.add(e);
      }
    }
    for (final y in yogaWorkouts) {
      if (q.isEmpty || uContains(y.title, q) || uContains(y.subtitle, q)) {
        matches.add(y);
      }
    }
    for (final p in samplePosts) {
      if (q.isEmpty ||
          uContains(p.title, q) ||
          uContains(p.detail ?? '', q) ||
          uContains(p.subtitle, q)) {
        matches.add(p);
      }
    }

    if (mounted) {
      setState(() {
        _results = matches;
        _isLoading = false;
      });
    }
  }

  bool uContains(String text, String q) => text.toLowerCase().contains(q);

  List<SearchResultItem> get _filteredResults {
    if (_selectedCategory == SearchCategory.all) return _results;
    return _results.where((r) => r.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredResults;

    return Scaffold(
      backgroundColor: VColor.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchHeader(),
            _buildCategoryChips(),
            _buildResultHeader(filtered.length),
            Expanded(
              child: _isLoading
                  ? const Center(child: VLoading(label: 'Searching VYRA directory...'))
                  : filtered.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(VSpace.base, VSpace.xs, VSpace.base, VSpace.xl),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: VSpace.sm),
                          itemBuilder: (context, index) => _buildResultCard(filtered[index]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(VSpace.base, VSpace.sm, VSpace.base, VSpace.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: VColor.text),
                onPressed: () => Navigator.of(context).maybePop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'GLOBAL DIRECTORY',
                    style: TextStyle(
                      color: VColor.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    'Search VYRA',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: VColor.text,
                        ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: VSpace.sm),
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: VColor.surfaceRaised,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: VColor.accent.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: VColor.accent.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: VColor.accent, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onQueryChanged,
                    style: const TextStyle(color: VColor.text, fontSize: 15),
                    decoration: const InputDecoration(
                      hintText: 'Search athletes, squads, telemetry...',
                      hintStyle: TextStyle(color: VColor.textLow, fontSize: 14),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      _executeSearch('');
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: VColor.surface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: VColor.textLow, size: 16),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    final categories = [
      (SearchCategory.all, 'ALL'),
      (SearchCategory.users, 'USERS'),
      (SearchCategory.clubs, 'CLUBS'),
      (SearchCategory.events, 'EVENTS'),
      (SearchCategory.workouts, 'WORKOUTS'),
      (SearchCategory.posts, 'POSTS'),
    ];

    return SizedBox(
      height: 46,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: VSpace.base, vertical: 6),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (cat, label) = categories[index];
          final selected = _selectedCategory == cat;

          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: selected
                    ? const LinearGradient(
                        colors: [VColor.accent, VColor.accentGreen],
                      )
                    : null,
                color: selected ? null : VColor.surfaceRaised,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? Colors.transparent : Colors.white10,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: VColor.accent.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.black : VColor.textMid,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResultHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(VSpace.base, VSpace.xs, VSpace.base, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: VColor.accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: VColor.accent, blurRadius: 6),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'TOP MATCHES',
                style: TextStyle(
                  color: VColor.textMid,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          Text(
            '$count FOUND',
            style: const TextStyle(
              color: VColor.textLow,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(SearchResultItem item) {
    switch (item.category) {
      case SearchCategory.users:
        return _buildUserCard(item);
      case SearchCategory.clubs:
        return _buildClubCard(item);
      case SearchCategory.events:
        return _buildEventCard(item);
      case SearchCategory.workouts:
        return _buildWorkoutCard(item);
      case SearchCategory.posts:
        return _buildPostCard(item);
      case SearchCategory.all:
        return _buildUserCard(item);
    }
  }

  Widget _buildUserCard(SearchResultItem item) {
    final isFollowing = _followingIds.contains(item.id);

    return VCard(
      tone: CardTone.raised,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: VColor.surface,
              border: Border.all(color: VColor.accent.withValues(alpha: 0.4), width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(
              item.title.isNotEmpty ? item.title[0] : '?',
              style: const TextStyle(color: VColor.accent, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.title,
                        style: const TextStyle(color: VColor.text, fontWeight: FontWeight.bold, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, color: VColor.accent, size: 16),
                    ],
                  ],
                ),
                if (item.handle != null)
                  Text(
                    item.handle!,
                    style: const TextStyle(color: VColor.accent, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: const TextStyle(color: VColor.textLow, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline, color: VColor.accent, size: 20),
                onPressed: () {
                  pushScreen(
                    context,
                    item.title,
                    AthleteChatScreen(
                      athleteId: item.id,
                      athleteName: item.title,
                      athleteHandle: item.handle ?? '@athlete',
                    ),
                  );
                },
                tooltip: 'Direct Message',
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (isFollowing) {
                      _followingIds.remove(item.id);
                    } else {
                      _followingIds.add(item.id);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isFollowing ? VColor.surface : VColor.accent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isFollowing ? Colors.white24 : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    isFollowing ? 'Following' : 'Follow',
                    style: TextStyle(
                      color: isFollowing ? VColor.textMid : Colors.black,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClubCard(SearchResultItem item) {
    return VCard(
      tone: CardTone.raised,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: VColor.accentGreenGlow,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.groups, color: VColor.accentGreen, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(color: VColor.text, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: const TextStyle(color: VColor.textLow, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: VColor.textLow),
        ],
      ),
    );
  }

  Widget _buildEventCard(SearchResultItem item) {
    return VCard(
      tone: CardTone.raised,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: VColor.accentGlow,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.event_note, color: VColor.accent, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(color: VColor.text, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: const TextStyle(color: VColor.textLow, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: VColor.textLow),
        ],
      ),
    );
  }

  Widget _buildWorkoutCard(SearchResultItem item) {
    final isYoga = item.id.startsWith('fy-') || item.id.startsWith('hy-');

    return VCard(
      tone: CardTone.raised,
      child: InkWell(
        onTap: () {
          if (isYoga) {
            pushScreen(context, 'Face & Hair Yoga', const FaceHairYogaScreen());
          } else if (item.meta is LibraryItem) {
            pushScreen(context, item.title, ExerciseDetailScreen(item: item.meta as LibraryItem));
          }
        },
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isYoga ? VColor.accentGreenGlow : VColor.accentGlow,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(
                isYoga ? Icons.spa_outlined : Icons.fitness_center,
                color: isYoga ? VColor.accentGreen : VColor.accent,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(color: VColor.text, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: const TextStyle(color: VColor.textLow, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: VColor.textLow),
          ],
        ),
      ),
    );
  }

  Widget _buildPostCard(SearchResultItem item) {
    return VCard(
      tone: CardTone.raised,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: VColor.surface,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      item.title.isNotEmpty ? item.title[0] : '?',
                      style: const TextStyle(color: VColor.accent, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.title,
                    style: const TextStyle(color: VColor.text, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(width: 4),
                  const Text('• Post', style: TextStyle(color: VColor.textLow, fontSize: 12)),
                ],
              ),
              const Row(
                children: [
                  Icon(Icons.bolt, color: VColor.accent, size: 14),
                  SizedBox(width: 2),
                  Text('Matched', style: TextStyle(color: VColor.accent, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          if (item.detail != null) ...[
            const SizedBox(height: 8),
            Text(
              item.detail!,
              style: const TextStyle(color: VColor.textMid, fontSize: 13, height: 1.4),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.subtitle,
                style: const TextStyle(color: VColor.textLow, fontSize: 11),
              ),
              const Row(
                children: [
                  Icon(Icons.favorite, color: VColor.accentGreen, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'KUDOS',
                    style: TextStyle(
                      color: VColor.accentGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(VSpace.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: VSpace.base),
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: VColor.surfaceRaised,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white10),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.search_off, color: VColor.textLow, size: 32),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'No matches found',
              style: TextStyle(color: VColor.text, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text(
              'Try searching with another keyword or explore trending topics below.',
              style: TextStyle(color: VColor.textLow, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: VSpace.xl),
          const Text(
            'TRENDING SEARCHES',
            style: TextStyle(
              color: VColor.accent,
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _trendingSearches.map((tag) {
              return ActionChip(
                backgroundColor: VColor.surfaceRaised,
                side: const BorderSide(color: Colors.white12),
                label: Text(
                  tag,
                  style: const TextStyle(color: VColor.textMid, fontSize: 12),
                ),
                onPressed: () {
                  _searchController.text = tag;
                  _executeSearch(tag);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
