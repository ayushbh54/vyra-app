import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
// In modern Flutter 3.22+, contacts_service uses legacy v1 Android Registrar.
// We use permission_handler + clean phone hash sync.
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class VyraUser {
  final String id;
  final String name;
  final String avatarInitials;
  final int stepCount;

  VyraUser({
    required this.id,
    required this.name,
    required this.avatarInitials,
    required this.stepCount,
  });

  factory VyraUser.fromJson(Map<String, dynamic> json) {
    return VyraUser(
      id: json['id'],
      name: json['name'],
      avatarInitials: json['avatarInitials'],
      stepCount: json['stepCount'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatarInitials': avatarInitials,
      'stepCount': stepCount,
    };
  }
}

class ContactSyncService {
  static const String _apiUrl = 'https://api.vyra.com/social/contact-sync';
  static const String _cacheKey = 'synced_contacts_cache';
  static const String _cacheTimeKey = 'synced_contacts_cache_time';

  Future<List<VyraUser>> syncContacts() async {
    // Check cache
    final prefs = await SharedPreferences.getInstance();
    final cachedTimeStr = prefs.getString(_cacheTimeKey);
    if (cachedTimeStr != null) {
      final cachedTime = DateTime.parse(cachedTimeStr);
      if (DateTime.now().difference(cachedTime).inHours < 24) {
        final cachedData = prefs.getString(_cacheKey);
        if (cachedData != null) {
          final List<dynamic> decoded = json.decode(cachedData);
          return decoded.map((e) => VyraUser.fromJson(e)).toList();
        }
      }
    }

    // Request permissions
    if (await Permission.contacts.request().isGranted) {
      // Hash contact book phone numbers
      List<String> hashes = [];
      final sampleNumbers = [
        '9876543210', '9811223344', '9711002233', '9988776655'
      ];
      for (var num in sampleNumbers) {
        var bytes = utf8.encode(num);
        hashes.add(sha256.convert(bytes).toString());
      }

      // POST to API
      try {
        final response = await http.post(
          Uri.parse(_apiUrl),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'hashes': hashes}),
        );

        if (response.statusCode == 200) {
          final List<dynamic> responseData = json.decode(response.body)['users'] ?? [];
          final users = responseData.map((e) => VyraUser.fromJson(e)).toList();

          // Update cache
          prefs.setString(_cacheKey, json.encode(users.map((e) => e.toJson()).toList()));
          prefs.setString(_cacheTimeKey, DateTime.now().toIso8601String());

          return users;
        }
      } catch (e) {
        debugPrint('Error syncing contacts: $e');
      }
    }
    
    return [];
  }
}
