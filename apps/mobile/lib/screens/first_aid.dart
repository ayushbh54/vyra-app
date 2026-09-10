import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';
import '../widgets/common.dart';

/// FIRST AID & INJURY TRIAGE — Stitch Pages 42, 43, 44, 45
///
/// Comprehensive emergency response, gym trauma triage, R.I.C.E injury protocol,
/// and instant 112 / 108 emergency dispatch hotline for athletes.
class FirstAidScreen extends StatefulWidget {
  const FirstAidScreen({super.key});

  @override
  State<FirstAidScreen> createState() => _FirstAidScreenState();
}

class _FirstAidScreenState extends State<FirstAidScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _callEmergency() async {
    final uri = Uri.parse('tel:112');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VColor.bg,
      appBar: AppBar(
        backgroundColor: VColor.surface,
        leading: const BackButton(color: VColor.text),
        title: const Text(
          'First Aid & Triage',
          style: TextStyle(color: VColor.text, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(VSpace.base),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const VHeaderBadge(label: 'TRAUMA & ATHLETIC CARE', accentColor: VColor.warn),
                  const SizedBox(height: 6),
                  const Text(
                    'FIRST AID KNOWLEDGE',
                    style: TextStyle(
                      color: VColor.text,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Rapid athletic emergency response, acute injury protocols & triage guidance',
                    style: TextStyle(color: VColor.textMid, fontSize: 13),
                  ),
                  const SizedBox(height: VSpace.md),

                  // ── Emergency Hotline Banner ──
                  Container(
                    padding: const EdgeInsets.all(VSpace.base),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          VColor.critSoft,
                          VColor.surfaceRaised,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(VRadius.lg),
                      border: Border.all(color: VColor.crit.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: VColor.crit,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.call, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: VSpace.md),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Emergency Medical Hotline',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'National Ambulance / SOS: Dial 112 / 108',
                                style: TextStyle(color: VColor.textMid, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: VColor.crit,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          onPressed: _callEmergency,
                          child: const Text('Call 112', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: VSpace.md),

                  // ── Tab Bar ──
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: VColor.surface,
                      borderRadius: BorderRadius.circular(VRadius.pill),
                      border: Border.all(color: VColor.line),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: VColor.accent,
                        borderRadius: BorderRadius.circular(VRadius.pill),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: VColor.textOnAccent,
                      unselectedLabelColor: VColor.textMid,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      tabs: const [
                        Tab(text: 'Gym Floor'),
                        Tab(text: 'R.I.C.E Protocol'),
                        Tab(text: 'Heat & Fainting'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildGymFloorTab(),
                  _buildRiceProtocolTab(),
                  _buildHeatFaintingTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGymFloorTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: VSpace.base),
      children: [
        _firstAidCard(
          title: 'Muscle Cramps & Spasms',
          severity: 'MILD TO MODERATE',
          color: VColor.accent,
          icon: Icons.fitness_center_rounded,
          steps: [
            'Stop movement immediately and gently stretch the contracted muscle.',
            'Massage the muscle knot with firm circular pressure.',
            'Hydrate with electrolyte or salted water (sodium/potassium replenishment).',
            'Apply ice pack if lingering soreness persists after relaxation.',
          ],
        ),
        const SizedBox(height: VSpace.md),
        _firstAidCard(
          title: 'Weight Collapses & Pinches',
          severity: 'IMMEDIATE ATTENTION',
          color: VColor.warn,
          icon: Icons.warning_amber_rounded,
          steps: [
            'Do not attempt to rapidly lift the bar alone; signal a spotter or floor coach.',
            'Check for joint dislocation or open skin abrasions.',
            'Clean wounds with antiseptic wipe, elevate the pinched limb.',
            'If joint mobility is lost, immobilize and seek medical evaluation.',
          ],
        ),
        const SizedBox(height: VSpace.md),
        _firstAidCard(
          title: 'Dizziness After Heavy Lifts',
          severity: 'VASOVAGAL EPISODE',
          color: VColor.accentGreen,
          icon: Icons.airline_seat_recline_normal_rounded,
          steps: [
            'Sit down immediately with head resting between knees or lie flat on back.',
            'Avoid sudden standing to prevent blood pooling in lower limbs.',
            'Inhale deeply through the nose and exhale slowly through pursed lips.',
            'Sip cool water once lightheadedness clears.',
          ],
        ),
        const SizedBox(height: VSpace.xxl),
      ],
    );
  }

  Widget _buildRiceProtocolTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: VSpace.base),
      children: [
        Container(
          padding: const EdgeInsets.all(VSpace.base),
          decoration: BoxDecoration(
            color: VColor.surfaceRaised,
            borderRadius: BorderRadius.circular(VRadius.lg),
            border: Border.all(color: VColor.accentGreen.withValues(alpha: 0.4)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.verified_rounded, color: VColor.accentGreen, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Standard R.I.C.E Acute Sprain Formula',
                    style: TextStyle(color: VColor.text, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              SizedBox(height: 6),
              Text(
                'Apply within the first 24–48 hours of ankle sprains, knee twists, or tendon pulls.',
                style: TextStyle(color: VColor.textMid, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: VSpace.md),
        _protocolStep('R', 'REST', 'Protect the injured limb from weight bearing. Cease activity to prevent further fiber tear.', VColor.accent),
        const SizedBox(height: VSpace.sm),
        _protocolStep('I', 'ICE', 'Apply wrapped ice for 15–20 minutes every 2 hours. Never apply bare ice directly to skin.', VColor.accentGreen),
        const SizedBox(height: VSpace.sm),
        _protocolStep('C', 'COMPRESSION', 'Wrap with an elastic compression bandage from distal to proximal. Keep snug but do not cut off pulse.', VColor.accentOrange),
        const SizedBox(height: VSpace.sm),
        _protocolStep('E', 'ELEVATION', 'Prop the injured joint above heart level on pillows to encourage fluid drainage and reduce swelling.', VColor.accent),
        const SizedBox(height: VSpace.xxl),
      ],
    );
  }

  Widget _buildHeatFaintingTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: VSpace.base),
      children: [
        _firstAidCard(
          title: 'Heat Exhaustion vs Heat Stroke',
          severity: 'CRITICAL DIFFERENTIAL',
          color: VColor.crit,
          icon: Icons.thermostat_rounded,
          steps: [
            'Heat Exhaustion: Heavy sweating, pale clammy skin, fast weak pulse. Move to shaded cool area, fan body, sip cool water.',
            'Heat Stroke (Emergency!): Hot dry or flushed skin, confusion, loss of consciousness. Call 112 immediately and cool body with cold wet towels.',
          ],
        ),
        const SizedBox(height: VSpace.md),
        _firstAidCard(
          title: 'Exercise-Induced Dehydration',
          severity: 'PREVENTIVE TRIAGE',
          color: VColor.accent,
          icon: Icons.water_drop_rounded,
          steps: [
            'Mild Dehydration: Dry mouth, dark urine, mild fatigue. Drink 500ml water with a pinch of salt & lemon.',
            'Severe: Sunken eyes, rapid heartbeat, confusion. Avoid caffeine/sugary sodas; take oral rehydration salts (ORS).',
          ],
        ),
        const SizedBox(height: VSpace.xxl),
      ],
    );
  }

  Widget _protocolStep(String letter, String title, String desc, Color color) {
    return Container(
      padding: const EdgeInsets.all(VSpace.base),
      decoration: BoxDecoration(
        color: VColor.surfaceRaised,
        borderRadius: BorderRadius.circular(VRadius.md),
        border: Border.all(color: VColor.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color),
            ),
            alignment: Alignment.center,
            child: Text(
              letter,
              style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ),
          const SizedBox(width: VSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: VColor.text, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 3),
                Text(desc, style: const TextStyle(color: VColor.textMid, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _firstAidCard({
    required String title,
    required String severity,
    required Color color,
    required IconData icon,
    required List<String> steps,
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
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: VColor.text, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  severity,
                  style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: VSpace.sm),
          const Divider(color: VColor.line, height: 1),
          const SizedBox(height: VSpace.sm),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${i + 1}. ',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Expanded(
                    child: Text(
                      steps[i],
                      style: const TextStyle(color: VColor.textMid, fontSize: 13, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
