import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/screen_scaffold.dart';
import 'exercise_detail.dart';
import 'face_hair_yoga.dart';
import 'global_search.dart';

const _categories = [
  (null, 'All'),
  ('exercise', 'Exercises'),
  ('yoga', 'Yoga'),
  ('breathing', 'Breathing'),
  ('meditation', 'Meditation'),
  ('special', 'Trending'),
];

/// LIBRARY — every exercise/yoga/breathing/meditation item in one browsable,
/// filterable list. This is the screen behind Stitch's "All Exercises",
/// "Exercise Library", "Yoga", "Breathing", "Meditation" and "Special
/// Trending Workouts" pages — one screen, category chips do the rest,
/// rather than five near-identical screens.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({this.initialCategory, super.key});

  final String? initialCategory;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String? _category;
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<LibraryItem>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await context.read<VyraApi>().library(
            category: _category,
            search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
          );
      if (mounted) setState(() { _items = items; _error = null; });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(VSpace.base, VSpace.base, VSpace.base, VSpace.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Exercise Library', style: Theme.of(context).textTheme.headlineMedium),
                    IconButton(
                      icon: const Icon(Icons.travel_explore, color: VColor.accent),
                      onPressed: () => pushScreen(context, 'Global Search', const GlobalSearchScreen()),
                      tooltip: 'Global Directory Search',
                    ),
                  ],
                ),
                const SizedBox(height: VSpace.xs),
                InkWell(
                  onTap: () => pushScreen(context, 'Face & Scalp Yoga', const FaceHairYogaScreen()),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: VSpace.xs),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [VColor.accent.withOpacity(0.12), VColor.accentGreen.withOpacity(0.12)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: VColor.accent.withOpacity(0.25)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.spa_outlined, color: VColor.accentGreen, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Face & Scalp Yoga Protocols (Stitch 19/20)',
                            style: TextStyle(color: VColor.text, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: VColor.accent, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(color: VColor.text),
                  decoration: const InputDecoration(
                    hintText: 'Search exercises, yoga, breathing...',
                    prefixIcon: Icon(Icons.search, color: VColor.textLow),
                  ),
                ),
                const SizedBox(height: VSpace.sm),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: VSpace.sm),
                    itemBuilder: (context, i) {
                      final (value, label) = _categories[i];
                      final selected = _category == value;
                      return ChoiceChip(
                        label: Text(label),
                        selected: selected,
                        onSelected: (_) {
                          setState(() => _category = value);
                          _load();
                        },
                        selectedColor: VColor.accent,
                        backgroundColor: VColor.surfaceRaised,
                        labelStyle: TextStyle(
                            color: selected ? VColor.textOnAccent : VColor.text,
                            fontWeight: FontWeight.w600, fontSize: 13),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) Expanded(child: VErrorView(message: _error!, onRetry: _load)),
          if (_error == null && _items == null) const Expanded(child: VLoading(label: 'Loading library')),
          if (_items != null && _items!.isEmpty)
            const Expanded(
              child: VEmptyState(title: 'No matches', body: 'Try a different search or category.'),
            ),
          if (_items != null && _items!.isNotEmpty)
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(VSpace.base, 0, VSpace.base, VSpace.xxxl),
                itemCount: _items!.length,
                separatorBuilder: (_, __) => const SizedBox(height: VSpace.sm),
                itemBuilder: (context, i) => _ExerciseCard(item: _items![i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.item});
  final LibraryItem item;

  @override
  Widget build(BuildContext context) {
    return VCard(
      tone: CardTone.raised,
      child: InkWell(
        onTap: () => pushScreen(context, item.name, ExerciseDetailScreen(item: item)),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: VColor.accentGlow,
                borderRadius: BorderRadius.circular(VRadius.md),
              ),
              alignment: Alignment.center,
              child: Icon(_categoryIcon(item.category), color: VColor.accent),
            ),
            const SizedBox(width: VSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    '${item.subcategory} · ${item.difficulty} · ${(item.defaultDurationSec / 60).ceil()} min',
                    style: const TextStyle(color: VColor.textLow, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (item.isSeatedFriendly)
              const Padding(
                padding: EdgeInsets.only(right: VSpace.xs),
                child: Icon(Icons.chair_alt_outlined, color: VColor.textLow, size: 18),
              ),
            const Icon(Icons.chevron_right, color: VColor.textLow),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'yoga': return Icons.self_improvement;
      case 'breathing': return Icons.air;
      case 'meditation': return Icons.spa_outlined;
      case 'special': return Icons.bolt;
      default: return Icons.fitness_center;
    }
  }
}
