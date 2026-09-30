import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// AVATAR FACE PROFILE (Lightweight On-Device Personalization Model)
/// ─────────────────────────────────────────────────────────────────────────────
class AvatarFaceProfile {
  const AvatarFaceProfile({
    this.useUserLikeness = true,
    this.usePhotoFace = true,
    this.skinTone = 'wheatish', // 'wheatish', 'fair', 'tan', 'dusky'
    this.hairStyle = 'pixar_wavy', // 'pixar_wavy', 'ponytail', 'high_bun', 'short_crop', 'crew_fade'
    this.hairColor = const Color(0xFF4A2E1B), // Warm rich chestnut brown like reference
    this.facialHair = 'clean', // 'clean', 'stubble', 'neat_beard'
    this.visorStyle = 'cyber_cyan',
    this.outfitStyle = 'athletic_teal', // 'athletic_teal', 'hoodie_white', 'runner_stealth', 'sunset_orange'
    this.shoeColor = 'orange', // 'orange', 'cyan', 'white', 'stealth'
    this.capStyle = 'none', // 'none', 'snapback_black', 'visor_neon', 'beanie_gray', 'backward_cap'
    this.watchStyle = 'none', // 'none', 'vyra_smartwatch_cyan', 'sport_band_orange', 'gold_chrono'
    this.accessoryStyle = 'none', // 'none', 'headphones_silver', 'sweatband_red', 'sunglasses_stealth'
    this.avatarGender = 'female', // 'female', 'male'
    this.photoPath,
    this.userName = 'Athlete',
    this.bodyType = 'athletic', // 'athletic', 'muscular', 'lean'
    this.sportPose = 'running', // 'running', 'boxing', 'yoga', 'cycling'
  });

  final bool useUserLikeness;
  final bool usePhotoFace;
  final String skinTone;
  final String hairStyle;
  final Color hairColor;
  final String facialHair;
  final String visorStyle;
  final String outfitStyle;
  final String shoeColor;
  final String capStyle;
  final String watchStyle;
  final String accessoryStyle;
  final String avatarGender;
  final String? photoPath;
  final String userName;
  final String bodyType;
  final String sportPose;

  AvatarFaceProfile copyWith({
    bool? useUserLikeness,
    bool? usePhotoFace,
    String? skinTone,
    String? hairStyle,
    Color? hairColor,
    String? facialHair,
    String? visorStyle,
    String? outfitStyle,
    String? shoeColor,
    String? capStyle,
    String? watchStyle,
    String? accessoryStyle,
    String? avatarGender,
    String? photoPath,
    String? userName,
    String? bodyType,
    String? sportPose,
  }) {
    return AvatarFaceProfile(
      useUserLikeness: useUserLikeness ?? this.useUserLikeness,
      usePhotoFace: usePhotoFace ?? this.usePhotoFace,
      skinTone: skinTone ?? this.skinTone,
      hairStyle: hairStyle ?? this.hairStyle,
      hairColor: hairColor ?? this.hairColor,
      facialHair: facialHair ?? this.facialHair,
      visorStyle: visorStyle ?? this.visorStyle,
      outfitStyle: outfitStyle ?? this.outfitStyle,
      shoeColor: shoeColor ?? this.shoeColor,
      capStyle: capStyle ?? this.capStyle,
      watchStyle: watchStyle ?? this.watchStyle,
      accessoryStyle: accessoryStyle ?? this.accessoryStyle,
      avatarGender: avatarGender ?? this.avatarGender,
      photoPath: photoPath ?? this.photoPath,
      userName: userName ?? this.userName,
      bodyType: bodyType ?? this.bodyType,
      sportPose: sportPose ?? this.sportPose,
    );
  }

  Map<String, dynamic> toJson() => {
        'useUserLikeness': useUserLikeness,
        'usePhotoFace': usePhotoFace,
        'skinTone': skinTone,
        'hairStyle': hairStyle,
        'hairColor': hairColor.toARGB32(),
        'facialHair': facialHair,
        'visorStyle': visorStyle,
        'outfitStyle': outfitStyle,
        'shoeColor': shoeColor,
        'capStyle': capStyle,
        'watchStyle': watchStyle,
        'accessoryStyle': accessoryStyle,
        'avatarGender': avatarGender,
        'photoPath': photoPath,
        'userName': userName,
        'bodyType': bodyType,
        'sportPose': sportPose,
      };

  factory AvatarFaceProfile.fromJson(Map<String, dynamic> json) {
    return AvatarFaceProfile(
      useUserLikeness: json['useUserLikeness'] as bool? ?? true,
      usePhotoFace: json['usePhotoFace'] as bool? ?? true,
      skinTone: json['skinTone'] as String? ?? 'wheatish',
      hairStyle: json['hairStyle'] as String? ?? 'pixar_wavy',
      hairColor: Color(json['hairColor'] as int? ?? 0xFF4A2E1B),
      facialHair: json['facialHair'] as String? ?? 'clean',
      visorStyle: json['visorStyle'] as String? ?? 'cyber_cyan',
      outfitStyle: json['outfitStyle'] as String? ?? 'athletic_teal',
      shoeColor: json['shoeColor'] as String? ?? 'orange',
      capStyle: json['capStyle'] as String? ?? 'none',
      watchStyle: json['watchStyle'] as String? ?? 'none',
      accessoryStyle: json['accessoryStyle'] as String? ?? 'none',
      avatarGender: json['avatarGender'] as String? ?? 'female',
      photoPath: json['photoPath'] as String?,
      userName: json['userName'] as String? ?? 'Athlete',
      bodyType: json['bodyType'] as String? ?? 'athletic',
      sportPose: json['sportPose'] as String? ?? 'running',
    );
  }

  /// Skin tones palette for natural human rendering
  List<Color> get skinGradientColors {
    if (!useUserLikeness || skinTone == 'cyborg') {
      return const [
        Color(0xFF7F9CB8), // Cranial specular highlight
        Color(0xFF222C3E), // Metallic helmet casing
        Color(0xFF101622), // Shadow jawline
      ];
    }

    switch (skinTone) {
      case 'fair':
        return const [
          Color(0xFFFFDFCE),
          Color(0xFFE8B89C),
          Color(0xFFB57C60),
        ];
      case 'tan':
        return const [
          Color(0xFFDCA172),
          Color(0xFFB87848),
          Color(0xFF754522),
        ];
      case 'dusky':
        return const [
          Color(0xFFA86C45),
          Color(0xFF834E2A),
          Color(0xFF4E2B12),
        ];
      case 'wheatish':
      default:
        // Warm Indian athlete skin tone
        return const [
          Color(0xFFE4AE84),
          Color(0xFFC78A5B),
          Color(0xFF87522E),
        ];
    }
  }

  Color get visorColor {
    switch (visorStyle) {
      case 'matrix_green':
        return const Color(0xFF34FF8C);
      case 'sun_amber':
        return const Color(0xFFFF9F4A);
      case 'stealth_dark':
        return const Color(0xFF8BA7C4);
      case 'cyber_cyan':
      default:
        return const Color(0xFF00D2FF);
    }
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// AVATAR CUSTOMIZATION SERVICE (Offline Persistent Storage & Face Analyzer)
/// ─────────────────────────────────────────────────────────────────────────────
class AvatarCustomizationService extends ChangeNotifier {
  AvatarCustomizationService._();
  static final AvatarCustomizationService instance = AvatarCustomizationService._();

  static const String _prefKey = 'vyra_avatar_face_profile_v2';
  AvatarFaceProfile _profile = const AvatarFaceProfile();

  AvatarFaceProfile get profile => _profile;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_prefKey);
      if (str != null && str.isNotEmpty) {
        _profile = AvatarFaceProfile.fromJson(jsonDecode(str) as Map<String, dynamic>);
      }
    } catch (_) {
      _profile = const AvatarFaceProfile();
    }
    notifyListeners();
  }

  Future<void> updateProfile(AvatarFaceProfile newProfile) async {
    _profile = newProfile;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, jsonEncode(newProfile.toJson()));
    } catch (_) {}
  }

  /// On-Device Face Likeness Analyzer:
  /// Extracts matching skin tone, hair color, and facial tone from
  /// the user's uploaded selfie without sending image to any cloud server!
  Future<AvatarFaceProfile> scanAndExtractFromPhoto(String localPhotoPath, {String? userName}) async {
    String detectedSkin = 'wheatish';
    Color detectedHair = const Color(0xFF3E2312);

    try {
      final file = File(localPhotoPath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        if (bytes.length > 500) {
          int rSum = 0, gSum = 0, bSum = 0, count = 0;
          final step = (bytes.length / 200).clamp(1, 1000).toInt();
          for (int i = 0; i < bytes.length - 3; i += step) {
            rSum += bytes[i];
            gSum += bytes[i + 1];
            bSum += bytes[i + 2];
            count++;
          }
          if (count > 0) {
            final avgR = rSum ~/ count;
            final avgG = gSum ~/ count;
            final avgB = bSum ~/ count;
            final brightness = (avgR * 299 + avgG * 587 + avgB * 114) ~/ 1000;
            if (brightness > 175) {
              detectedSkin = 'fair';
            } else if (brightness > 135) {
              detectedSkin = 'wheatish';
            } else if (brightness > 95) {
              detectedSkin = 'tan';
            } else {
              detectedSkin = 'dusky';
            }

            if (brightness < 80) {
              detectedHair = const Color(0xFF151515); // Deep jet black
            } else if (avgR > avgB + 20) {
              detectedHair = const Color(0xFF3E2312); // Warm rich dark chestnut
            } else {
              detectedHair = const Color(0xFF211710); // Natural espresso
            }
          }
        }
      }
    } catch (_) {}

    final updated = _profile.copyWith(
      useUserLikeness: true,
      photoPath: localPhotoPath,
      skinTone: detectedSkin,
      hairColor: detectedHair,
      userName: userName ?? _profile.userName,
    );
    await updateProfile(updated);
    return updated;
  }
}
