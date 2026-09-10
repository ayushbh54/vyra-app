import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../widgets/common.dart';

/// Stitch Pages 19 & 20: Face Yoga & Scalp/Hair Yoga Vitality Protocols
class FaceHairYogaScreen extends StatefulWidget {
  const FaceHairYogaScreen({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  State<FaceHairYogaScreen> createState() => _FaceHairYogaScreenState();
}

class _FaceHairYogaScreenState extends State<FaceHairYogaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int? _activeTimerSeconds;
  Timer? _timer;
  String? _activePoseName;

  final List<({
    String name,
    String target,
    String benefit,
    int durationSec,
    String reps,
    IconData icon,
    List<String> instructions,
  })> _facePoses = const [
    (
      name: 'Jawline Sculptor',
      target: 'Platysma & Digastric Muscles',
      benefit: 'Defines mandibular border, reduces submental double-chin tension',
      durationSec: 30,
      reps: '3 Sets · 30s Hold',
      icon: Icons.face_retouching_natural_rounded,
      instructions: [
        'Tilt your head back smoothly and look toward the ceiling.',
        'Push your lower jaw forward until you feel a firm stretch in the neck.',
        'Press your tongue flat against the roof of your mouth.',
        'Hold for 30 seconds while breathing steadily through the nose.',
      ],
    ),
    (
      name: 'Cheekbone Lifter',
      target: 'Zygomaticus Major & Minor',
      benefit: 'Natural cheek elevation, prevents mid-face volume sag',
      durationSec: 30,
      reps: '3 Sets · 30s Hold',
      icon: Icons.sentiment_very_satisfied_rounded,
      instructions: [
        'Form an "O" shape with your mouth, hiding your teeth with your lips.',
        'Smile widely from the corners of your mouth toward your temples.',
        'Place index fingers lightly on top of cheek apples to feel muscle engagement.',
        'Hold and pulse upward gently for 30 seconds.',
      ],
    ),
    (
      name: 'Platysma Neck Smoother',
      target: 'Sternocleidomastoid & Cervical Fascia',
      benefit: 'Eliminates tech-neck horizontal creases, drains cervical lymph',
      durationSec: 45,
      reps: '2 Sets · 45s Flow',
      icon: Icons.accessibility_new_rounded,
      instructions: [
        'Place both hands flat over your collarbone to anchor the skin.',
        'Gently lean head back and look up at a 45-degree angle.',
        'Pout your lower lip slightly outward to intensify the stretch.',
        'Hold and swallow slowly to engage deep throat muscles.',
      ],
    ),
    (
      name: 'Orbicularis Eye Awakening',
      target: 'Orbicularis Oculi & Procerus',
      benefit: 'Stimulates periorbital microcirculation, dispels dark shadows',
      durationSec: 30,
      reps: '2 Sets · 30s Hold',
      icon: Icons.remove_red_eye_rounded,
      instructions: [
        'Place index fingers at outer corners of eyes and thumbs under cheekbones.',
        'Squint your lower eyelids upward while keeping upper lids open.',
        'Feel the lower muscle contract firmly beneath your fingertips.',
        'Release and repeat in rhythmic 5-second hold intervals.',
      ],
    ),
  ];

  final List<({
    String name,
    String target,
    String benefit,
    int durationSec,
    String asanaType,
    IconData icon,
    List<String> instructions,
  })> _hairPoses = const [
    (
      name: 'Adho Mukha Svanasana',
      target: 'Downward-Facing Dog Inversion',
      benefit: '+38% microcapillary cranial perfusion to hair follicles',
      durationSec: 60,
      asanaType: 'Cranial Perfusion Inversion',
      icon: Icons.self_improvement_rounded,
      instructions: [
        'Begin on hands and knees, tuck toes and lift hips high toward the ceiling.',
        'Press heels gently toward the ground with a soft bend in knees.',
        'Let head and neck hang completely loose, allowing gravity to relax cervical spine.',
        'Deep diaphragmatic breaths allow oxygenated arterial blood to pool in scalp.',
      ],
    ),
    (
      name: 'Sarvangasana',
      target: 'Shoulder Stand Thyroid Activation',
      benefit: 'Stimulates thyroid gland metabolism, strengthens dermal papilla cells',
      durationSec: 45,
      asanaType: 'Endocrine & Scalp Flush',
      icon: Icons.bolt_rounded,
      instructions: [
        'Lie supine, lift legs smoothly upward and support lower back with palms.',
        'Elbows stay parallel and grounded on the mat.',
        'Align spine vertically and breathe slow, calming breaths.',
        'Avoid turning head sideways during hold to protect cervical discs.',
      ],
    ),
    (
      name: 'Balasana with Acupressure',
      target: 'Child\'s Pose Vertex Stimulation',
      benefit: 'Downregulates cortisol-driven hair shedding, relaxes epicranial aponeurosis',
      durationSec: 90,
      asanaType: 'Scalp Decompression',
      icon: Icons.spa_rounded,
      instructions: [
        'Kneel on mat with big toes touching, sit back on heels and fold forward.',
        'Rest forehead on mat, extend arms forward or beside your feet.',
        'Use fingertips to perform light circular tapotement over crown and occiput.',
        'Maintain deep rhythmic belly breathing for full nervous system downshift.',
      ],
    ),
    (
      name: 'Matsyasana (Fish Pose)',
      target: 'Crown Vertex Floor Contact',
      benefit: 'Stimulates Sahasrara vertex chakra and scalp micro-circulation',
      durationSec: 45,
      asanaType: 'Vertex Circulation',
      icon: Icons.favorite_border_rounded,
      instructions: [
        'Lie flat, slide hands under hips palms down.',
        'Press elbows into mat, lift chest and arch back until crown lightly touches floor.',
        'Keep minimal weight on the crown — 90% of support remains in elbows and forearms.',
        'Breathe deeply expanding the ribcage fully.',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _startTimer(String name, int seconds) {
    _timer?.cancel();
    HapticFeedback.heavyImpact();
    setState(() {
      _activePoseName = name;
      _activeTimerSeconds = seconds;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_activeTimerSeconds != null && _activeTimerSeconds! > 1) {
        setState(() => _activeTimerSeconds = _activeTimerSeconds! - 1);
      } else {
        t.cancel();
        HapticFeedback.vibrate();
        setState(() {
          _activeTimerSeconds = null;
          _activePoseName = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 $name completed! Cellular protocol logged.'),
            backgroundColor: VColor.accentGreen,
          ),
        );
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _activeTimerSeconds = null;
      _activePoseName = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VColor.bg,
      appBar: AppBar(
        backgroundColor: VColor.surfaceRaised,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: VColor.text, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vitality Protocols',
              style: TextStyle(color: VColor.text, fontSize: 18, fontWeight: FontWeight.w800),
            ),
            Row(
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(color: VColor.accentGreen, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                const Text(
                  'BIOMETRIC MIRROR & OXYGENATION',
                  style: TextStyle(
                    color: VColor.accentGreen,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: VColor.accent,
          labelColor: VColor.accent,
          unselectedLabelColor: VColor.textMid,
          tabs: const [
            Tab(text: 'Face Yoga (Stitch 19)'),
            Tab(text: 'Hair Yoga (Stitch 20)'),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildFaceYogaTab(),
              _buildHairYogaTab(),
            ],
          ),

          // Active Timer Floating Overlay
          if (_activeTimerSeconds != null)
            Positioned(
              left: VSpace.base,
              right: VSpace.base,
              bottom: VSpace.xl,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: VSpace.base, vertical: VSpace.md),
                decoration: BoxDecoration(
                  color: VColor.surfaceRaised,
                  borderRadius: BorderRadius.circular(VRadius.xl),
                  border: Border.all(color: VColor.accent, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: VColor.accent.withValues(alpha: 0.25),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: VColor.bg,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$_activeTimerSeconds',
                          style: const TextStyle(
                            color: VColor.accent,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: VSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('PROTOCOL ACTIVE', style: TextStyle(color: VColor.accent, fontSize: 10, fontWeight: FontWeight.bold)),
                          Text(
                            _activePoseName ?? 'Pose Active',
                            style: const TextStyle(color: VColor.text, fontSize: 14, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.stop_circle_rounded, color: Colors.redAccent, size: 30),
                      onPressed: _stopTimer,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFaceYogaTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(VSpace.base, VSpace.base, VSpace.base, 100),
      children: [
        // Header Banner
        Container(
          padding: const EdgeInsets.all(VSpace.base),
          decoration: BoxDecoration(
            color: VColor.surfaceRaised,
            borderRadius: BorderRadius.circular(VRadius.xl),
            border: Border.all(color: VColor.line),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    VHeaderBadge(label: 'SUBMENTAL & PLATYSMA', accentColor: VColor.accent),
                    SizedBox(height: 6),
                    Text(
                      'Face Yoga & Sculpting',
                      style: TextStyle(color: VColor.text, fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Targeted isometric facial exercises that tighten the jawline and drain puffiness.',
                      style: TextStyle(color: VColor.textMid, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: VColor.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: VColor.accent.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.face_retouching_natural_rounded, color: VColor.accent, size: 28),
              ),
            ],
          ),
        ),
        const SizedBox(height: VSpace.base),

        for (final pose in _facePoses) ...[
          _buildPoseCard(
            name: pose.name,
            target: pose.target,
            benefit: pose.benefit,
            durationSec: pose.durationSec,
            badgeText: pose.reps,
            badgeColor: VColor.accent,
            icon: pose.icon,
            instructions: pose.instructions,
          ),
          const SizedBox(height: VSpace.md),
        ],
      ],
    );
  }

  Widget _buildHairYogaTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(VSpace.base, VSpace.base, VSpace.base, 100),
      children: [
        // Header Banner
        Container(
          padding: const EdgeInsets.all(VSpace.base),
          decoration: BoxDecoration(
            color: VColor.surfaceRaised,
            borderRadius: BorderRadius.circular(VRadius.xl),
            border: Border.all(color: VColor.line),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    VHeaderBadge(label: 'MICROVASCULAR PERFUSION', accentColor: VColor.accentGreen),
                    SizedBox(height: 6),
                    Text(
                      'Hair Yoga & Scalp Health',
                      style: TextStyle(color: VColor.text, fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Inverted asanas that surge microcapillary scalp perfusion by up to 38% and down-regulate shedding.',
                      style: TextStyle(color: VColor.textMid, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: VColor.accentGreen.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: VColor.accentGreen.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.spa_rounded, color: VColor.accentGreen, size: 28),
              ),
            ],
          ),
        ),
        const SizedBox(height: VSpace.base),

        for (final pose in _hairPoses) ...[
          _buildPoseCard(
            name: pose.name,
            target: pose.target,
            benefit: pose.benefit,
            durationSec: pose.durationSec,
            badgeText: pose.asanaType,
            badgeColor: VColor.accentGreen,
            icon: pose.icon,
            instructions: pose.instructions,
          ),
          const SizedBox(height: VSpace.md),
        ],
      ],
    );
  }

  Widget _buildPoseCard({
    required String name,
    required String target,
    required String benefit,
    required int durationSec,
    required String badgeText,
    required Color badgeColor,
    required IconData icon,
    required List<String> instructions,
  }) {
    return Container(
      padding: const EdgeInsets.all(VSpace.base),
      decoration: BoxDecoration(
        color: VColor.surfaceRaised,
        borderRadius: BorderRadius.circular(VRadius.lg),
        border: Border.all(color: VColor.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(VRadius.md),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                ),
                child: Icon(icon, color: badgeColor, size: 22),
              ),
              const SizedBox(width: VSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${durationSec}s',
                          style: const TextStyle(color: VColor.textMid, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(name, style: const TextStyle(color: VColor.text, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(target, style: const TextStyle(color: VColor.textLow, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: VSpace.md),
          Text('✨ $benefit', style: const TextStyle(color: VColor.textMid, fontSize: 12.5, height: 1.35)),
          const SizedBox(height: VSpace.sm),

          // Steps Accordion / List
          for (int i = 0; i < instructions.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${i + 1}. ', style: TextStyle(color: badgeColor, fontSize: 11.5, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Text(instructions[i], style: const TextStyle(color: VColor.textLow, fontSize: 11.5)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: VSpace.md),

          // Action Start Timer Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: VColor.bgLift,
                foregroundColor: VColor.text,
                side: BorderSide(color: badgeColor.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.pill)),
              ),
              onPressed: () => _startTimer(name, durationSec),
              icon: Icon(Icons.play_circle_fill_rounded, size: 18, color: badgeColor),
              label: Text('Begin ${durationSec}s Protocol', style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 12.5)),
            ),
          ),
        ],
      ),
    );
  }
}
