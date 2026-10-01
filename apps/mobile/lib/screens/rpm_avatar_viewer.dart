import 'dart:io';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'rpm_avatar_creator.dart';
import '../services/body_scan_service.dart';
import '../services/avatar_customization_service.dart';
import '../theme.dart';

class RpmAvatarViewerScreen extends StatefulWidget {
  const RpmAvatarViewerScreen({super.key});

  @override
  State<RpmAvatarViewerScreen> createState() => _RpmAvatarViewerScreenState();
}

class _RpmAvatarViewerScreenState extends State<RpmAvatarViewerScreen> {
  String? _avatarUrl;
  String? _gender;
  String? _lastUpdated;
  bool _isLoading = true;
  String _currentAnim = 'idle';
  BodyScanResult? _bodyScanResult;

  final Map<String, File?> _bodyPhotos = {
    'front': null,
    'back': null,
    'left': null,
    'right': null,
  };
  bool _isScanning = false;

  static const exercises = [
    {'id': 'idle',          'label': 'Idle',        'icon': Icons.person_outline_rounded,          'anim': 'idle'},
    {'id': 'running',       'label': 'Running',     'icon': Icons.directions_run_rounded,           'anim': 'run'},
    {'id': 'boxing',        'label': 'Boxing',      'icon': Icons.sports_mma_rounded,               'anim': 'punch'},
    {'id': 'yoga',          'label': 'Yoga',        'icon': Icons.self_improvement_rounded,         'anim': 'idle'},
    {'id': 'cycling',       'label': 'Cycling',     'icon': Icons.directions_bike_rounded,          'anim': 'idle'},
    {'id': 'weightlifting', 'label': 'Weights',     'icon': Icons.fitness_center_rounded,           'anim': 'idle'},
    {'id': 'squat',         'label': 'Squat',       'icon': Icons.accessibility_new_rounded,        'anim': 'idle'},
    {'id': 'plank',         'label': 'Plank',       'icon': Icons.horizontal_rule_rounded,          'anim': 'idle'},
    {'id': 'pushup',        'label': 'Push-up',     'icon': Icons.arrow_downward_rounded,           'anim': 'idle'},
    {'id': 'swimming',      'label': 'Swimming',    'icon': Icons.pool_rounded,                     'anim': 'idle'},
    {'id': 'dancing',       'label': 'Dance',       'icon': Icons.music_note_rounded,               'anim': 'idle'},
    {'id': 'football',      'label': 'Football',    'icon': Icons.sports_soccer_rounded,            'anim': 'idle'},
    {'id': 'cricket',       'label': 'Cricket',     'icon': Icons.sports_cricket_rounded,           'anim': 'idle'},
    {'id': 'skipping',      'label': 'Skipping',    'icon': Icons.loop_rounded,                     'anim': 'jump'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    AvatarCustomizationService.instance.addListener(_onExerciseChanged);
    _loadCurrentAnim();
  }

  void _onExerciseChanged() {
    if (!mounted) return;
    final newAnim = AvatarCustomizationService.instance.currentRpmExercisePose;
    if (newAnim != _currentAnim) {
      setState(() => _currentAnim = newAnim);
    }
  }

  Future<void> _loadCurrentAnim() async {
    final prefs = await SharedPreferences.getInstance();
    final anim = prefs.getString('rpm_current_anim') ?? 'idle';
    if (mounted) setState(() => _currentAnim = anim);
  }

  @override
  void dispose() {
    AvatarCustomizationService.instance.removeListener(_onExerciseChanged);
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final bodyScan = await BodyScanService.instance.loadSaved();
    setState(() {
      _avatarUrl = prefs.getString('rpm_avatar_url');
      _gender = prefs.getString('rpm_gender');
      _lastUpdated = prefs.getString('rpm_avatar_updated_at');
      _bodyScanResult = bodyScan;
      _isLoading = false;
    });
  }

  Future<void> _openCreator() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const RpmAvatarCreatorScreen()),
    );
    if (result != null) {
      _loadData();
    }
  }

  void _showBodyScanSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: VColor.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: VColor.line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('📸 Body Scan',
                  style: TextStyle(color: VColor.text, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('Upload photos from all 4 sides for best avatar match',
                  style: TextStyle(color: VColor.textMuted, fontSize: 12)),
                const SizedBox(height: 20),
                GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.1,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _photoSlot('front', '🫅', 'Front View',   setSheetState),
                    _photoSlot('back',  '🔙', 'Back View',    setSheetState),
                    _photoSlot('left',  '👈', 'Left Side',    setSheetState),
                    _photoSlot('right', '👉', 'Right Side',   setSheetState),
                  ],
                ),
                const SizedBox(height: 20),
                if (_bodyScanResult != null)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: VColor.accentGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: VColor.accentGreen.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: VColor.accentGreen, size: 20),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Body: ${_bodyScanResult!.bodyTypeLabel}',
                              style: const TextStyle(color: VColor.text, fontWeight: FontWeight.w700, fontSize: 13)),
                            Text('Pose: ${_bodyScanResult!.poseLabel} • Confidence: ${(_bodyScanResult!.confidence * 100).toInt()}%',
                              style: const TextStyle(color: VColor.textMuted, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                if (_bodyScanResult != null) const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _bodyPhotos.values.any((f) => f != null)
                      ? () async {
                          setSheetState(() => _isScanning = true);
                          await _scanAllPhotos(setSheetState);
                          setSheetState(() => _isScanning = false);
                        }
                      : null,
                    icon: _isScanning
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.person_search_rounded),
                    label: Text(_isScanning ? 'Analyzing…' : 'Create Avatar from Photos'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VColor.accent,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: VColor.surface,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _photoSlot(String key, String emoji, String label, StateSetter setSheetState) {
    final file = _bodyPhotos[key];
    return GestureDetector(
      onTap: () async {
        final picker = ImagePicker();
        final xfile = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 80,
        );
        if (xfile != null) {
          setSheetState(() => _bodyPhotos[key] = File(xfile.path));
          setState(() {});
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: file != null 
            ? VColor.accent.withValues(alpha: 0.1)
            : VColor.surfaceRaised,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: file != null ? VColor.accent : VColor.line,
            width: file != null ? 1.5 : 1,
          ),
        ),
        child: file != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(file, fit: BoxFit.cover),
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      color: Colors.black54,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  Positioned(
                    top: 6, right: 6,
                    child: GestureDetector(
                      onTap: () => setSheetState(() => _bodyPhotos[key] = null),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(height: 6),
                Text(label,
                  style: const TextStyle(color: VColor.textMuted, fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                const Text('Tap to upload',
                  style: TextStyle(color: VColor.textLow, fontSize: 10)),
              ],
            ),
      ),
    );
  }

  Future<void> _scanAllPhotos(StateSetter setSheetState) async {
    final uploadedFiles = _bodyPhotos.values.whereType<File>().toList();
    if (uploadedFiles.isEmpty) return;
    
    BodyScanResult? best;
    for (final file in uploadedFiles) {
      final result = await BodyScanService.instance.analyzeImage(file);
      if (result != null) {
        if (best == null || result.confidence > best.confidence) {
          best = result;
        }
      }
    }
    
    if (best != null) {
      setState(() => _bodyScanResult = best);
      setSheetState(() {});
      
      if (mounted) {
        Navigator.pop(context);
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          final url = await Navigator.push<String>(
            context,
            MaterialPageRoute(builder: (_) => RpmAvatarCreatorScreen(
              bodyScanResult: best,
            )),
          );
          if (url != null) {
            _loadData();
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0F),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreator,
        icon: const Icon(Icons.edit),
        label: Text(_avatarUrl == null ? 'Create Avatar' : 'Edit Avatar'),
        backgroundColor: VColor.accent,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: VColor.accent))
          : _avatarUrl == null
              ? _buildEmptyState()
              : _buildAvatarView(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.accessibility_new_rounded, size: 80, color: VColor.textMuted),
          const SizedBox(height: 16),
          const Text('No 3D Avatar Yet',
              style: TextStyle(color: VColor.text, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Create your personalized 3D coach!',
              style: TextStyle(color: VColor.textMuted)),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: VColor.accent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: _openCreator,
            child: const Text('Create Now', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarView() {
    return Stack(
      children: [
        ModelViewer(
          src: _avatarUrl!,
          alt: '3D Avatar',
          ar: false,
          autoRotate: false,
          cameraControls: true,
          shadowIntensity: 1,
          backgroundColor: const Color(0xFF0D0D0F),
          cameraOrbit: '0deg 75deg 2m',
          exposure: 1.1,
          animationName: _currentAnim,
        ),
        
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                bottom: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [VColor.bg, VColor.bg.withValues(alpha: 0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Row(
              children: [
                const Text('My 3D Avatar',
                    style: TextStyle(
                        color: VColor.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
                const Spacer(),
                GestureDetector(
                  onTap: _openCreator,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: VColor.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: VColor.accent.withValues(alpha: 0.5)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_rounded, size: 16, color: VColor.accent),
                        SizedBox(width: 6),
                        Text('Edit',
                            style: TextStyle(
                                color: VColor.accent,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert, color: VColor.text),
                  onPressed: _showBodyScanSheet,
                  tooltip: 'Body Scan',
                ),
              ],
            ),
          ),
        ),

        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildBottomSheet(),
        ),
      ],
    );
  }

  Widget _buildBottomSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: VColor.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DefaultTabController(
        length: 2,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TabBar(
              indicatorColor: VColor.accent,
              labelColor: VColor.accent,
              unselectedLabelColor: VColor.textMuted,
              tabs: [
                Tab(text: 'Poses'),
                Tab(text: 'Info'),
              ],
            ),
            SizedBox(
              height: 120,
              child: TabBarView(
                children: [
                  _buildPosesTab(),
                  _buildInfoTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPosesTab() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: exercises.length,
      itemBuilder: (context, index) {
        final exercise = exercises[index];
        final isSelected = _currentAnim == exercise['anim'];
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () {
              AvatarCustomizationService.instance.setActiveExercisePose(exercise['id'] as String);
            },
            child: Chip(
              backgroundColor: isSelected ? VColor.accent.withValues(alpha: 0.2) : VColor.bg,
              side: BorderSide(
                color: isSelected ? VColor.accent : Colors.transparent,
              ),
              avatar: Icon(
                exercise['icon'] as IconData,
                color: isSelected ? VColor.accent : VColor.textMuted,
                size: 18,
              ),
              label: Text(
                exercise['label'] as String,
                style: TextStyle(
                  color: isSelected ? VColor.accent : VColor.textMuted,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Gender: ${_gender ?? "Not specified"}', style: const TextStyle(color: VColor.text)),
          const SizedBox(height: 8),
          Text('Last Updated: ${_lastUpdated != null ? DateTime.parse(_lastUpdated!).toLocal().toString().split('.')[0] : "Never"}', 
            style: const TextStyle(color: VColor.textMuted)),
        ],
      ),
    );
  }
}
