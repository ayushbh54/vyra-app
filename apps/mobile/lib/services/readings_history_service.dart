import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedReadingEntry {
  final String id;
  final DateTime timestamp;
  final String formattedDateTime;
  final int steps;
  final int waterMl;
  final int heartRateBpm;
  final double weightKg;
  final int bloodOxygenSpo2;

  const SavedReadingEntry({
    required this.id,
    required this.timestamp,
    required this.formattedDateTime,
    required this.steps,
    required this.waterMl,
    required this.heartRateBpm,
    required this.weightKg,
    this.bloodOxygenSpo2 = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'formattedDateTime': formattedDateTime,
        'steps': steps,
        'waterMl': waterMl,
        'heartRateBpm': heartRateBpm,
        'weightKg': weightKg,
        'bloodOxygenSpo2': bloodOxygenSpo2,
      };

  factory SavedReadingEntry.fromJson(Map<String, dynamic> json) => SavedReadingEntry(
        id: json['id'] as String? ?? '',
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
        formattedDateTime: json['formattedDateTime'] as String? ?? '',
        steps: (json['steps'] as num?)?.toInt() ?? 0,
        waterMl: (json['waterMl'] as num?)?.toInt() ?? 0,
        heartRateBpm: (json['heartRateBpm'] as num?)?.toInt() ?? 0,
        weightKg: (json['weightKg'] as num?)?.toDouble() ?? 0.0,
        bloodOxygenSpo2: (json['bloodOxygenSpo2'] as num?)?.toInt() ?? 0,
      );
}

class ReadingsHistoryService extends ChangeNotifier {
  ReadingsHistoryService._();
  static final ReadingsHistoryService instance = ReadingsHistoryService._();

  static const String _prefKey = 'vyra_manual_readings_history_v1';
  List<SavedReadingEntry> _entries = [];

  List<SavedReadingEntry> get entries => List.unmodifiable(_entries);

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List;
        _entries = list
            .map((e) => SavedReadingEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        _entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      }
    } catch (e) {
      debugPrint('Error loading readings history: $e');
    }
    notifyListeners();
  }

  Future<void> saveEntry(SavedReadingEntry entry) async {
    _entries.removeWhere((e) => e.id == entry.id);
    _entries.insert(0, entry);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(_entries.map((e) => e.toJson()).toList());
      await prefs.setString(_prefKey, data);
    } catch (e) {
      debugPrint('Error saving readings history: $e');
    }
  }

  Future<void> deleteEntry(String id) async {
    _entries.removeWhere((e) => e.id == id);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(_entries.map((e) => e.toJson()).toList());
      await prefs.setString(_prefKey, data);
    } catch (e) {
      debugPrint('Error deleting reading entry: $e');
    }
  }
}
