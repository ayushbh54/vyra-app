import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedBiomarker {
  final String name;
  final String value;
  final String unit;
  final String status;
  final String referenceRange;
  final String insight;

  const SavedBiomarker({
    required this.name,
    required this.value,
    required this.unit,
    required this.status,
    required this.referenceRange,
    required this.insight,
  });

  dynamic operator [](String key) {
    switch (key) {
      case 'name':
        return name;
      case 'value':
        return value;
      case 'unit':
        return unit;
      case 'status':
        return status;
      case 'referenceRange':
        return referenceRange;
      case 'insight':
      case 'summary':
        return insight;
      default:
        return null;
    }
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'value': value,
        'unit': unit,
        'status': status,
        'referenceRange': referenceRange,
        'insight': insight,
      };

  factory SavedBiomarker.fromJson(Map<String, dynamic> json) => SavedBiomarker(
        name: json['name'] as String? ?? json['marker'] as String? ?? json['label'] as String? ?? '',
        value: json['value']?.toString() ?? '',
        unit: json['unit'] as String? ?? '',
        status: json['status'] as String? ?? 'normal',
        referenceRange: json['referenceRange'] as String? ?? '',
        insight: json['insight'] as String? ?? json['summary'] as String? ?? '',
      );
}

class SavedReportItem {
  final String id;
  final DateTime timestamp;
  final String formattedDateTime;
  final String labName;
  final String reportDate;
  final String? imagePath;
  final List<SavedBiomarker> biomarkers;
  final List<String> insights;
  final List<Map<String, dynamic>> adjustments;
  final bool urgentReferral;
  final String nextStep;
  final String disclaimer;

  SavedReportItem({
    required this.id,
    required this.timestamp,
    String? formattedDateTime,
    required this.labName,
    required this.reportDate,
    this.imagePath,
    required dynamic biomarkers,
    required this.insights,
    this.adjustments = const [],
    this.urgentReferral = false,
    this.nextStep = '',
    this.disclaimer = '',
  })  : formattedDateTime = formattedDateTime ??
            '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}',
        biomarkers = (biomarkers is List)
            ? biomarkers.map((b) {
                if (b is SavedBiomarker) return b;
                if (b is Map<String, dynamic>) return SavedBiomarker.fromJson(b);
                if (b is Map) return SavedBiomarker.fromJson(b.cast<String, dynamic>());
                return SavedBiomarker(
                    name: '$b', value: '', unit: '', status: 'normal', referenceRange: '', insight: '');
              }).toList()
            : [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'formattedDateTime': formattedDateTime,
        'labName': labName,
        'reportDate': reportDate,
        'imagePath': imagePath,
        'biomarkers': biomarkers.map((b) => b.toJson()).toList(),
        'insights': insights,
        'adjustments': adjustments,
        'urgentReferral': urgentReferral,
        'nextStep': nextStep,
        'disclaimer': disclaimer,
      };

  factory SavedReportItem.fromJson(Map<String, dynamic> json) => SavedReportItem(
        id: json['id'] as String? ?? '',
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
        formattedDateTime: json['formattedDateTime'] as String? ?? '',
        labName: json['labName'] as String? ?? 'Medical Diagnostic Report',
        reportDate: json['reportDate'] as String? ?? '',
        imagePath: json['imagePath'] as String?,
        biomarkers: ((json['biomarkers'] as List?) ?? [])
            .map((b) => SavedBiomarker.fromJson(b as Map<String, dynamic>))
            .toList(),
        insights: ((json['insights'] as List?) ?? []).map((e) => '$e').toList(),
        adjustments: ((json['adjustments'] as List?) ?? [])
            .whereType<Map<String, dynamic>>()
            .toList(),
        urgentReferral: json['urgentReferral'] as bool? ?? false,
        nextStep: json['nextStep'] as String? ?? '',
        disclaimer: json['disclaimer'] as String? ?? '',
      );
}

typedef SavedReportEntry = SavedReportItem;

class ReportHistoryService extends ChangeNotifier {
  ReportHistoryService._();
  static final ReportHistoryService instance = ReportHistoryService._();

  static const String _prefKey = 'vyra_saved_report_history_v1';
  List<SavedReportItem> _reports = [];

  List<SavedReportItem> get reports => List.unmodifiable(_reports);

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List;
        _reports = list
            .map((e) => SavedReportItem.fromJson(e as Map<String, dynamic>))
            .toList();
        _reports.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      }
    } catch (e) {
      debugPrint('Error loading report history: $e');
    }
    notifyListeners();
  }

  Future<List<SavedReportItem>> getReports() async {
    if (_reports.isEmpty) {
      await init();
    }
    return reports;
  }

  Future<void> saveReport(SavedReportItem report) async {
    _reports.removeWhere((r) => r.id == report.id);
    _reports.insert(0, report);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(_reports.map((r) => r.toJson()).toList());
      await prefs.setString(_prefKey, data);
    } catch (e) {
      debugPrint('Error saving report history: $e');
    }
  }

  Future<void> deleteReport(String id) async {
    _reports.removeWhere((r) => r.id == id);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(_reports.map((r) => r.toJson()).toList());
      await prefs.setString(_prefKey, data);
    } catch (e) {
      debugPrint('Error deleting report history: $e');
    }
  }
}
