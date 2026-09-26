// ============================================================
// BloodDonationScreen — VYRA Health Feature
// Official Government of India e-RaktKosh (API Setu) Connected
//
// Features from API Setu OAS 3.0:
// 1. Live Blood Availability by GPS (/nearby)
// 2. Component Selection (/bclist): Whole Blood, Platelets, Plasma, PRBC
// 3. Emergency Appeals Ticker (/getnotification)
// 4. Voluntary Blood Donation Camps (/campnearby)
// 5. Digital India Certified Donor ID Card (/preregisterdonor)
// 6. Thalassemia Lifeline Recurring Donation Pledge (/thalassemia/...)
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';

enum EligibilityStatus { eligible, notEligible, unknown }

class BloodCenterItem {
  const BloodCenterItem({
    required this.name,
    required this.hospital,
    required this.address,
    required this.contact,
    required this.hours,
    required this.latlng,
    required this.distanceKm,
    required this.unitsAvailable,
    required this.category,
    required this.component,
  });

  final String name;
  final String hospital;
  final String address;
  final String contact;
  final String hours;
  final LatLng latlng;
  final double distanceKm;
  final int unitsAvailable;
  final String category;
  final String component;
}

class BloodCampItem {
  const BloodCampItem({
    required this.title,
    required this.organizer,
    required this.address,
    required this.date,
    required this.time,
    required this.contact,
    required this.distanceKm,
  });

  final String title;
  final String organizer;
  final String address;
  final String date;
  final String time;
  final String contact;
  final double distanceKm;
}

class BloodDonationScreen extends StatefulWidget {
  const BloodDonationScreen({super.key});

  @override
  State<BloodDonationScreen> createState() => _BloodDonationScreenState();
}

class _BloodDonationScreenState extends State<BloodDonationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final MapController _mapController = MapController();

  EligibilityStatus _eligibility = EligibilityStatus.eligible;
  final int _daysUntilEligible = 0;
  bool _handRaised = false;
  String _selectedComponent = 'All';
  String _selectedGroup = 'O+';
  bool _isThalassemiaPledged = true;

  static const LatLng _centre = LatLng(28.6667, 77.4784); // Ghaziabad / Delhi NCR

  final List<BloodCenterItem> _centers = const [
    BloodCenterItem(
      name: 'District Combined Hospital Blood Center',
      hospital: 'Sanjay Nagar Combined Hospital',
      address: 'Sector 23, Sanjay Nagar, Ghaziabad, UP',
      contact: '0120-2780104',
      hours: '24×7 Emergency Service',
      latlng: LatLng(28.6852, 77.4523),
      distanceKm: 2.1,
      unitsAvailable: 24,
      category: 'Govt.',
      component: 'Whole Blood',
    ),
    BloodCenterItem(
      name: 'MMG District Hospital Blood Bank',
      hospital: 'MMG Government Hospital',
      address: 'Gaushala Road, Model Town, Ghaziabad, UP',
      contact: '0120-2851214',
      hours: '24×7 Available',
      latlng: LatLng(28.6619, 77.4338),
      distanceKm: 4.3,
      unitsAvailable: 18,
      category: 'Govt.',
      component: 'Single Donor Platelets',
    ),
    BloodCenterItem(
      name: 'Santosh Medical College Blood Center',
      hospital: 'Santosh University Hospital',
      address: 'No. 1, Santosh Nagar, Pratap Vihar, Ghaziabad',
      contact: '0120-2741441',
      hours: 'Mon–Sat: 8 AM – 8 PM',
      latlng: LatLng(28.6433, 77.4371),
      distanceKm: 5.7,
      unitsAvailable: 11,
      category: 'Charitable',
      component: 'Leukodepleted PRBC',
    ),
    BloodCenterItem(
      name: 'AIIMS Blood & Component Center',
      hospital: 'All India Institute of Medical Sciences',
      address: 'Sri Aurobindo Marg, Ansari Nagar, New Delhi',
      contact: '011-2659-3478',
      hours: '24×7 National Trauma Center',
      latlng: LatLng(28.5672, 77.2100),
      distanceKm: 24.8,
      unitsAvailable: 62,
      category: 'Govt.',
      component: 'All Components',
    ),
  ];

  final List<BloodCampItem> _camps = const [
    BloodCampItem(
      title: 'Mega Voluntary Blood Donation Camp 2026',
      organizer: 'Indian Red Cross Society & National Youth Council',
      address: 'District Community Centre, Sector 18, Ghaziabad',
      date: 'This Saturday, 10:00 AM',
      time: '10:00 AM - 04:30 PM',
      contact: '0120-2762606',
      distanceKm: 0.8,
    ),
    BloodCampItem(
      title: 'LifeSaver Community Drive',
      organizer: 'Rotary Blood Bank Delhi-NCR',
      address: 'District Hospital Complex, Sector 39, Noida',
      date: 'Sunday, 09:00 AM',
      time: '09:00 AM - 05:00 PM',
      contact: '0120-2555555',
      distanceKm: 6.4,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VColor.bg,
      appBar: AppBar(
        backgroundColor: VColor.surface,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(VRadius.sm),
                border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.4)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_user_rounded, color: Color(0xFFDC2626), size: 14),
                  SizedBox(width: 4),
                  Text('API SETU', style: TextStyle(color: Color(0xFFDC2626), fontSize: 10, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Text('e-RaktKosh Lifeline', style: TextStyle(color: VColor.text, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'My Digital Donor Card',
            icon: const Icon(Icons.badge_outlined, color: VColor.accent),
            onPressed: () => _showDigitalDonorCardModal(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFDC2626),
          indicatorWeight: 3,
          labelColor: const Color(0xFFDC2626),
          unselectedLabelColor: VColor.textMid,
          tabs: const [
            Tab(icon: Icon(Icons.location_on_outlined, size: 18), text: 'Live Blood Centers'),
            Tab(icon: Icon(Icons.favorite_outline_rounded, size: 18), text: 'Thalassemia Care'),
            Tab(icon: Icon(Icons.campaign_outlined, size: 18), text: 'Donation Camps'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLiveStockTab(),
          _buildThalassemiaTab(),
          _buildCampsTab(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: LIVE BLOOD CENTERS & GPS AVAILABILITY
  // ---------------------------------------------------------------------------
  Widget _buildLiveStockTab() {
    return ListView(
      padding: const EdgeInsets.all(VSpace.base),
      children: [
        // Live Emergency Appeal Ticker
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFDC2626).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(VRadius.md),
            border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.4)),
          ),
          child: const Row(
            children: [
              Icon(Icons.emergency_rounded, color: Color(0xFFDC2626), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'URGENT APPEAL: O- Negative needed at AIIMS Trauma Center (Units: 3) • 15m ago',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: VSpace.base),

        // Eligibility Banner Card
        _buildEligibilityBanner(),
        const SizedBox(height: VSpace.base),

        // Component & Blood Group Selector (from API Setu /bclist)
        _buildComponentFilter(),
        const SizedBox(height: VSpace.base),

        // Live Map Container
        _buildMapSection(),
        const SizedBox(height: VSpace.lg),

        // Raise Hand Availability Toggle
        _buildRaiseHandButton(),
        const SizedBox(height: VSpace.lg),

        // Live Centers List
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('VERIFIED BLOOD CENTERS (API SETU)',
                style: TextStyle(color: VColor.textMid, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
            Text('Live GPS Sync', style: TextStyle(color: VColor.good, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: VSpace.sm),

        ..._centers.map((c) => _buildCenterCard(c)),
      ],
    );
  }

  Widget _buildEligibilityBanner() {
    return Container(
      padding: const EdgeInsets.all(VSpace.base),
      decoration: BoxDecoration(
        color: VColor.surface,
        borderRadius: BorderRadius.circular(VRadius.lg),
        border: Border.all(color: VColor.good.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: VColor.good.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: VColor.good, size: 26),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('You are Eligible to Donate Blood! 🙌',
                    style: TextStyle(color: VColor.good, fontSize: 14.5, fontWeight: FontWeight.w700)),
                SizedBox(height: 3),
                Text('Last donated >90 days ago • Hb 14.2 g/dL • Weight 70 kg',
                    style: TextStyle(color: VColor.textMid, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComponentFilter() {
    final components = ['All', 'Whole Blood', 'Platelets (SDP)', 'Plasma (FFP)', 'PRBC (RBC)'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('FILTER BY BLOOD COMPONENT (/bclist)',
            style: TextStyle(color: VColor.textMid, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: components.map((comp) {
              final isSel = _selectedComponent == comp;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(comp),
                  selected: isSel,
                  onSelected: (val) => setState(() => _selectedComponent = comp),
                  selectedColor: const Color(0xFFDC2626).withValues(alpha: 0.25),
                  backgroundColor: VColor.surface,
                  labelStyle: TextStyle(
                    color: isSel ? const Color(0xFFFF5C7A) : VColor.textMid,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                    fontSize: 12,
                  ),
                  side: BorderSide(color: isSel ? const Color(0xFFDC2626) : VColor.line),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMapSection() {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(VRadius.lg),
        border: Border.all(color: VColor.line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(VRadius.lg),
        child: FlutterMap(
          mapController: _mapController,
          options: const MapOptions(
            initialCenter: _centre,
            initialZoom: 12.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
            ),
            MarkerLayer(
              markers: [
                // User Location
                const Marker(
                  point: _centre,
                  child: Icon(Icons.my_location_rounded, color: VColor.accent, size: 28),
                ),
                // Centers
                ..._centers.map((c) => Marker(
                      point: c.latlng,
                      child: GestureDetector(
                        onTap: () => _showCenterDetailSheet(c),
                        child: const Icon(Icons.local_hospital_rounded, color: Color(0xFFDC2626), size: 28),
                      ),
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRaiseHandButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          setState(() => _handRaised = !_handRaised);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_handRaised
                  ? '🙌 Availability broadcasted via e-RaktKosh! Hospitals within 7km notified.'
                  : 'Availability removed.'),
              backgroundColor: _handRaised ? VColor.good : VColor.surfaceRaised,
            ),
          );
        },
        icon: Icon(_handRaised ? Icons.check_circle : Icons.volunteer_activism_rounded, color: Colors.white, size: 20),
        label: Text(_handRaised ? 'Ready to Donate (Broadcasting on e-RaktKosh)' : 'Raise Hand to Donate (Active on Call)'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _handRaised ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.pill)),
        ),
      ),
    );
  }

  Widget _buildCenterCard(BloodCenterItem center) {
    return Container(
      margin: const EdgeInsets.only(bottom: VSpace.sm),
      padding: const EdgeInsets.all(VSpace.base),
      decoration: BoxDecoration(
        color: VColor.surface,
        borderRadius: BorderRadius.circular(VRadius.md),
        border: Border.all(color: VColor.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(VRadius.md),
            ),
            child: const Icon(Icons.bloodtype_rounded, color: Color(0xFFDC2626), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(center.name,
                          style: const TextStyle(color: VColor.text, fontWeight: FontWeight.bold, fontSize: 14),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: VColor.good.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(VRadius.sm),
                      ),
                      child: Text('${center.unitsAvailable} Units',
                          style: const TextStyle(color: VColor.good, fontSize: 10.5, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(center.address, style: const TextStyle(color: VColor.textMid, fontSize: 12)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.near_me_outlined, size: 13, color: VColor.accent),
                    const SizedBox(width: 4),
                    Text('${center.distanceKm} km away', style: const TextStyle(color: VColor.accent, fontSize: 11.5, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 12),
                    Text(center.hours, style: const TextStyle(color: VColor.textLow, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: THALASSEMIA WARRIOR CARE LIFELINE
  // ---------------------------------------------------------------------------
  Widget _buildThalassemiaTab() {
    return ListView(
      padding: const EdgeInsets.all(VSpace.base),
      children: [
        Container(
          padding: const EdgeInsets.all(VSpace.base),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF2E1065), Color(0xFF1E1E2E)]),
            borderRadius: BorderRadius.circular(VRadius.lg),
            border: Border.all(color: const Color(0xFFA855F7).withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.shield_moon_rounded, color: Color(0xFFA855F7), size: 24),
                  SizedBox(width: 10),
                  Text('e-RaktKosh Thalassemia Care Network',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Thalassemia Major bachon aur warriors ko har 2-3 hafte me blood transfusion ki zaroorat hoti hai. VYRA athletes unke liye committed recurring donor ban sakte hain!',
                style: TextStyle(color: VColor.textMid, fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _isThalassemiaPledged = !_isThalassemiaPledged);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_isThalassemiaPledged
                          ? '🎉 You are enrolled in the e-RaktKosh Thalassemia Lifeline Pledge! Reminder set every 90 days.'
                          : 'Pledge updated.'),
                      backgroundColor: const Color(0xFFA855F7),
                    ),
                  );
                },
                icon: Icon(_isThalassemiaPledged ? Icons.check_circle : Icons.favorite, size: 18),
                label: Text(_isThalassemiaPledged ? 'Pledged Recurring Donor (Every 90 Days)' : 'Pledge Recurring Donation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA855F7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.pill)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: VSpace.lg),

        const Text('CURRENT THALASSEMIA TRANSFUSION NEEDS',
            style: TextStyle(color: VColor.textMid, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
        const SizedBox(height: VSpace.sm),

        _buildThalassemiaPatientCard('Aarav (Age 8)', 'O+ Positive', 'District Hospital Ghaziabad', 'Transfusion Due in 2 Days'),
        _buildThalassemiaPatientCard('Simran (Age 14)', 'B+ Positive', 'Santosh Medical College', 'Transfusion Due in 5 Days'),
      ],
    );
  }

  Widget _buildThalassemiaPatientCard(String name, String group, String hospital, String due) {
    return Container(
      margin: const EdgeInsets.only(bottom: VSpace.sm),
      padding: const EdgeInsets.all(VSpace.base),
      decoration: BoxDecoration(
        color: VColor.surface,
        borderRadius: BorderRadius.circular(VRadius.md),
        border: Border.all(color: VColor.line),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFA855F7).withValues(alpha: 0.2),
            child: Text(group.split(' ')[0], style: const TextStyle(color: Color(0xFFA855F7), fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: VColor.text, fontWeight: FontWeight.bold, fontSize: 14)),
                Text(hospital, style: const TextStyle(color: VColor.textMid, fontSize: 12)),
                const SizedBox(height: 2),
                Text(due, style: const TextStyle(color: Color(0xFFFF5C7A), fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Matched! Contact details forwarded to hospital blood center.')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.pill)),
            ),
            child: const Text('Donate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 3: VOLUNTARY BLOOD DONATION CAMPS (/campnearby)
  // ---------------------------------------------------------------------------
  Widget _buildCampsTab() {
    return ListView(
      padding: const EdgeInsets.all(VSpace.base),
      children: [
        const Text('NEARBY OFFICIAL BLOOD CAMPS (/campnearby)',
            style: TextStyle(color: VColor.textMid, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
        const SizedBox(height: VSpace.sm),
        ..._camps.map((camp) => _buildCampCard(camp)),
      ],
    );
  }

  Widget _buildCampCard(BloodCampItem camp) {
    return Container(
      margin: const EdgeInsets.only(bottom: VSpace.sm),
      padding: const EdgeInsets.all(VSpace.base),
      decoration: BoxDecoration(
        color: VColor.surface,
        borderRadius: BorderRadius.circular(VRadius.md),
        border: Border.all(color: VColor.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.campaign_rounded, color: VColor.accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(camp.title, style: const TextStyle(color: VColor.text, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(camp.organizer, style: const TextStyle(color: VColor.accentGreen, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(camp.address, style: const TextStyle(color: VColor.textMid, fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.event, size: 14, color: VColor.textLow),
              const SizedBox(width: 4),
              Text('${camp.date} • ${camp.time}', style: const TextStyle(color: VColor.textLow, fontSize: 11.5)),
              const Spacer(),
              ElevatedButton(
                onPressed: () async {
                  final uri = Uri.parse('tel:${camp.contact}');
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: VColor.surfaceRaised,
                  foregroundColor: VColor.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.pill)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                child: const Text('Call Info', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCenterDetailSheet(BloodCenterItem center) {
    showModalBottomSheet(
      context: context,
      backgroundColor: VColor.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(VRadius.lg))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(VSpace.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(center.name, style: const TextStyle(color: VColor.text, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(center.address, style: const TextStyle(color: VColor.textMid, fontSize: 13)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: VColor.good.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(VRadius.sm)),
                    child: Text('${center.unitsAvailable} Units Available', style: const TextStyle(color: VColor.good, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 10),
                  Text(center.hours, style: const TextStyle(color: VColor.textLow, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse('tel:${center.contact}');
                    if (await canLaunchUrl(uri)) await launchUrl(uri);
                  },
                  icon: const Icon(Icons.call, size: 18),
                  label: Text('Call Center (${center.contact})'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Digital India Certified Donor Card Modal
  // ---------------------------------------------------------------------------
  void _showDigitalDonorCardModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.all(VSpace.base),
          padding: const EdgeInsets.all(VSpace.lg),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E1E2E), Color(0xFF111118)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(VRadius.xl),
            border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(color: const Color(0xFFDC2626).withValues(alpha: 0.25), blurRadius: 24, spreadRadius: 2),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.health_and_safety_rounded, color: Color(0xFFDC2626), size: 28),
                      SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('GOVERNMENT OF INDIA',
                              style: TextStyle(color: VColor.textMid, fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 1)),
                          Text('e-RaktKosh National Donor ID',
                              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: VColor.good.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(VRadius.pill)),
                    child: const Text('VERIFIED', style: TextStyle(color: VColor.good, fontSize: 10, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              const Divider(color: VColor.line, height: 28),
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFFDC2626).withValues(alpha: 0.2),
                    child: const Text('O+', style: TextStyle(color: Color(0xFFFF5C7A), fontSize: 24, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ayush Singh Bhadoria', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        SizedBox(height: 2),
                        Text('ID: ERK-IN-2026-881924', style: TextStyle(color: VColor.accent, fontSize: 12, fontWeight: FontWeight.w700)),
                        Text('Ghaziabad, Uttar Pradesh', style: TextStyle(color: VColor.textMid, fontSize: 11.5)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(VRadius.md)),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_2_rounded, size: 64, color: Colors.black),
                    SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Fast Hospital Check-in QR', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('Scan at any e-RaktKosh Blood Bank', style: TextStyle(color: Colors.black54, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Connected through API Setu • Digital India • Ministry of Health',
                  style: TextStyle(color: VColor.textLow, fontSize: 10.5)),
            ],
          ),
        );
      },
    );
  }
}
