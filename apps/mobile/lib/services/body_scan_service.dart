import 'dart:io';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class BodyScanService {
  static final BodyScanService instance = BodyScanService._();
  BodyScanService._();

  final _detector = PoseDetector(
    options: PoseDetectorOptions(mode: PoseDetectionMode.single),
  );

  BodyScanResult? _lastResult;
  BodyScanResult? get lastResult => _lastResult;

  Future<BodyScanResult?> scanFromPhoto() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (xfile == null) return null;
    return analyzeImage(File(xfile.path));
  }

  Future<BodyScanResult?> scanFromCamera() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (xfile == null) return null;
    return analyzeImage(File(xfile.path));
  }

  Future<BodyScanResult?> analyzeImage(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final poses = await _detector.processImage(inputImage);
      if (poses.isEmpty) return null;

      final pose = poses.first;
      final result = _extractBodyMetrics(pose);
      _lastResult = result;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('body_scan_result', jsonEncode(result.toJson()));
      return result;
    } catch (e) {
      return null;
    }
  }

  BodyScanResult _extractBodyMetrics(Pose pose) {
    final lm = pose.landmarks;

    final leftShoulder  = lm[PoseLandmarkType.leftShoulder];
    final rightShoulder = lm[PoseLandmarkType.rightShoulder];
    final leftHip       = lm[PoseLandmarkType.leftHip];
    final rightHip      = lm[PoseLandmarkType.rightHip];
    final leftAnkle     = lm[PoseLandmarkType.leftAnkle];
    final rightAnkle    = lm[PoseLandmarkType.rightAnkle];
    final nose          = lm[PoseLandmarkType.nose];
    final leftWrist     = lm[PoseLandmarkType.leftWrist];
    final rightWrist    = lm[PoseLandmarkType.rightWrist];

    double shoulderWidth = 0;
    if (leftShoulder != null && rightShoulder != null) {
      shoulderWidth = (rightShoulder.x - leftShoulder.x).abs();
    }

    double hipWidth = 0;
    if (leftHip != null && rightHip != null) {
      hipWidth = (rightHip.x - leftHip.x).abs();
    }

    // double bodyHeight = 0;
    if (nose != null && leftAnkle != null) {
      // bodyHeight = (leftAnkle.y - nose.y).abs();
    }

    double shoulderHipRatio = hipWidth > 0 ? shoulderWidth / hipWidth : 1.0;

    String bodyType;
    if (shoulderHipRatio > 1.35) {
      bodyType = 'muscular';
    } else if (shoulderHipRatio > 1.1) {
      bodyType = 'athletic';
    } else {
      bodyType = 'lean';
    }

    double armSpread = 0;
    if (leftWrist != null && rightWrist != null) {
      armSpread = (rightWrist.x - leftWrist.x).abs();
    }

    String detectedPose = 'standing';
    if (armSpread > shoulderWidth * 1.8) {
      detectedPose = 'arms_wide';
    } else if (leftAnkle != null && rightAnkle != null) {
      final ankleSpread = (rightAnkle.x - leftAnkle.x).abs();
      if (ankleSpread > hipWidth * 1.5) {
        detectedPose = 'squat_stance';
      }
    }

    final rpmBodyParam = bodyType == 'muscular' ? 'athletic' : 'default';

    return BodyScanResult(
      bodyType: bodyType,
      shoulderHipRatio: shoulderHipRatio,
      detectedPose: detectedPose,
      rpmBodyParam: rpmBodyParam,
      confidence: _averageConfidence(pose),
    );
  }

  double _averageConfidence(Pose pose) {
    final scores = pose.landmarks.values
        .map((l) => l.likelihood)
        .where((s) => s > 0)
        .toList();
    if (scores.isEmpty) return 0;
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  Future<BodyScanResult?> loadSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('body_scan_result');
      if (raw == null) return null;
      _lastResult = BodyScanResult.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      return _lastResult;
    } catch (_) {
      return null;
    }
  }

  void dispose() => _detector.close();
}

class BodyScanResult {
  final String bodyType;
  final double shoulderHipRatio;
  final String detectedPose;
  final String rpmBodyParam;
  final double confidence;

  const BodyScanResult({
    required this.bodyType,
    required this.shoulderHipRatio,
    required this.detectedPose,
    required this.rpmBodyParam,
    required this.confidence,
  });

  Map<String, dynamic> toJson() => {
    'bodyType': bodyType,
    'shoulderHipRatio': shoulderHipRatio,
    'detectedPose': detectedPose,
    'rpmBodyParam': rpmBodyParam,
    'confidence': confidence,
  };

  factory BodyScanResult.fromJson(Map<String, dynamic> j) => BodyScanResult(
    bodyType:          j['bodyType'] as String,
    shoulderHipRatio:  (j['shoulderHipRatio'] as num).toDouble(),
    detectedPose:      j['detectedPose'] as String,
    rpmBodyParam:      j['rpmBodyParam'] as String,
    confidence:        (j['confidence'] as num).toDouble(),
  );

  String get bodyTypeLabel {
    switch (bodyType) {
      case 'muscular': return 'Muscular (V-shape)';
      case 'athletic': return 'Athletic';
      default:         return 'Lean / Slim';
    }
  }

  String get poseLabel {
    switch (detectedPose) {
      case 'squat_stance': return 'Wide Stance';
      case 'arms_wide':    return 'Arms Spread';
      default:             return 'Standing';
    }
  }
}
