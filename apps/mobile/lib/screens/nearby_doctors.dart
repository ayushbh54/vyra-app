// ============================================================
// NearbyDoctorsScreen — VYRA Health Feature
// Practo/DocOnline-style premium dark UI for discovering
// nearby doctors with AI recommendation, specialty filters,
// and detailed booking bottom sheet.
// ============================================================

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';

// ─── Data models ─────────────────────────────────────────────

enum DoctorSpecialty {
  general,
  cardiologist,
  orthopedic,
  dermatologist,
  nutritionist,
  gynecologist,
  endocrinologist,
  dentist,
}

extension DoctorSpecialtyLabel on DoctorSpecialty {
  String get label => switch (this) {
        DoctorSpecialty.general => 'General',
        DoctorSpecialty.cardiologist => 'Cardiologist',
        DoctorSpecialty.orthopedic => 'Orthopedic',
        DoctorSpecialty.dermatologist => 'Dermatologist',
        DoctorSpecialty.nutritionist => 'Nutritionist',
        DoctorSpecialty.gynecologist => 'Gynecologist',
        DoctorSpecialty.endocrinologist => 'Endocrinologist',
        DoctorSpecialty.dentist => 'Dentist',
      };

  IconData get icon => switch (this) {
        DoctorSpecialty.general => Icons.local_hospital_outlined,
        DoctorSpecialty.cardiologist => Icons.favorite_border_rounded,
        DoctorSpecialty.orthopedic => Icons.accessibility_new_rounded,
        DoctorSpecialty.dermatologist => Icons.face_outlined,
        DoctorSpecialty.nutritionist => Icons.restaurant_outlined,
        DoctorSpecialty.gynecologist => Icons.pregnant_woman_outlined,
        DoctorSpecialty.endocrinologist => Icons.science_outlined,
        DoctorSpecialty.dentist => Icons.sentiment_satisfied_alt_outlined,
      };

  Color get color => switch (this) {
        DoctorSpecialty.general => VColor.accent,
        DoctorSpecialty.cardiologist => const Color(0xFFFF5C7A),
        DoctorSpecialty.orthopedic => VColor.warn,
        DoctorSpecialty.dermatologist => const Color(0xFFB47CFF),
        DoctorSpecialty.nutritionist => VColor.accentGreen,
        DoctorSpecialty.gynecologist => const Color(0xFFFF7AC6),
        DoctorSpecialty.endocrinologist => const Color(0xFFFF9F4A),
        DoctorSpecialty.dentist => VColor.accentDeep,
      };
}

class Doctor {
  const Doctor({
    required this.id,
    required this.name,
    required this.specialty,
    required this.qualifications,
    required this.clinic,
    required this.address,
    required this.phone,
    required this.rating,
    required this.reviewCount,
    required this.distanceKm,
    required this.consultationFee,
    required this.availableToday,
    required this.nextSlot,
    required this.experience,
    required this.avatarColor,
    required this.avatarInitials,
    required this.languages,
  });

  final String id;
  final String name;
  final DoctorSpecialty specialty;
  final String qualifications;
  final String clinic;
  final String address;
  final String phone;
  final double rating;
  final int reviewCount;
  final double distanceKm;
  final int consultationFee; // in INR
  final bool availableToday;
  final String nextSlot;
  final int experience; // years
  final Color avatarColor;
  final String avatarInitials;
  final List<String> languages;
}

// ─── Mock data — 10 doctors ───────────────────────────────────

const List<Doctor> _kDoctors = [
  Doctor(
    id: 'd1',
    name: 'Dr. Priya Sharma',
    specialty: DoctorSpecialty.nutritionist,
    qualifications: 'M.Sc Nutrition · PhD Dietetics · AIIMS',
    clinic: 'NutriWell Clinic',
    address: 'Hauz Khas, New Delhi — 110016',
    phone: '+91-98106-11234',
    rating: 4.9,
    reviewCount: 312,
    distanceKm: 1.4,
    consultationFee: 800,
    availableToday: true,
    nextSlot: 'Today, 4:30 PM',
    experience: 9,
    avatarColor: Color(0xFF34FF8C),
    avatarInitials: 'PS',
    languages: ['Hindi', 'English'],
  ),
  Doctor(
    id: 'd2',
    name: 'Dr. Arjun Mehta',
    specialty: DoctorSpecialty.cardiologist,
    qualifications: 'MD Cardiology · DM · Apollo Hospitals',
    clinic: 'HeartCare Centre',
    address: 'Saket, New Delhi — 110017',
    phone: '+91-98104-52300',
    rating: 4.8,
    reviewCount: 521,
    distanceKm: 2.1,
    consultationFee: 1500,
    availableToday: true,
    nextSlot: 'Today, 6:00 PM',
    experience: 15,
    avatarColor: Color(0xFFFF5C7A),
    avatarInitials: 'AM',
    languages: ['English', 'Hindi', 'Gujarati'],
  ),
  Doctor(
    id: 'd3',
    name: 'Dr. Sunita Rao',
    specialty: DoctorSpecialty.gynecologist,
    qualifications: 'MBBS · MS OB-GYN · Fortis Hospital',
    clinic: 'WomenFirst Health',
    address: 'Green Park, New Delhi — 110016',
    phone: '+91-91507-78890',
    rating: 4.7,
    reviewCount: 288,
    distanceKm: 2.8,
    consultationFee: 1200,
    availableToday: false,
    nextSlot: 'Tomorrow, 10:00 AM',
    experience: 12,
    avatarColor: Color(0xFFFF7AC6),
    avatarInitials: 'SR',
    languages: ['English', 'Kannada', 'Hindi'],
  ),
  Doctor(
    id: 'd4',
    name: 'Dr. Rohan Kapoor',
    specialty: DoctorSpecialty.orthopedic,
    qualifications: 'MS Orthopaedics · AIIMS · Joint Replacement Specialist',
    clinic: 'OrthoPlus Clinic',
    address: 'Vasant Kunj, New Delhi — 110070',
    phone: '+91-93109-34521',
    rating: 4.6,
    reviewCount: 198,
    distanceKm: 3.5,
    consultationFee: 1000,
    availableToday: true,
    nextSlot: 'Today, 2:00 PM',
    experience: 18,
    avatarColor: Color(0xFFFFC93C),
    avatarInitials: 'RK',
    languages: ['English', 'Hindi', 'Punjabi'],
  ),
  Doctor(
    id: 'd5',
    name: 'Dr. Ananya Iyer',
    specialty: DoctorSpecialty.dermatologist,
    qualifications: 'MD Dermatology · DNB · Kokilaben Hospital',
    clinic: 'DermaCure Skin Centre',
    address: 'Lajpat Nagar, New Delhi — 110024',
    phone: '+91-88200-93411',
    rating: 4.8,
    reviewCount: 445,
    distanceKm: 4.2,
    consultationFee: 900,
    availableToday: true,
    nextSlot: 'Today, 5:15 PM',
    experience: 10,
    avatarColor: Color(0xFFB47CFF),
    avatarInitials: 'AI',
    languages: ['English', 'Tamil', 'Hindi'],
  ),
  Doctor(
    id: 'd6',
    name: 'Dr. Vikram Singh',
    specialty: DoctorSpecialty.general,
    qualifications: 'MBBS · MD General Medicine · 10+ Years',
    clinic: 'Wellness Point',
    address: 'Karol Bagh, New Delhi — 110005',
    phone: '+91-97116-20045',
    rating: 4.4,
    reviewCount: 673,
    distanceKm: 1.8,
    consultationFee: 500,
    availableToday: true,
    nextSlot: 'Today, 12:30 PM',
    experience: 10,
    avatarColor: Color(0xFF00D2FF),
    avatarInitials: 'VS',
    languages: ['Hindi', 'English'],
  ),
  Doctor(
    id: 'd7',
    name: 'Dr. Meena Krishnan',
    specialty: DoctorSpecialty.endocrinologist,
    qualifications: 'MD · DM Endocrinology · Medanta Hospital',
    clinic: 'HormoneBalance Clinic',
    address: 'Dwarka, New Delhi — 110075',
    phone: '+91-81301-56678',
    rating: 4.7,
    reviewCount: 167,
    distanceKm: 6.1,
    consultationFee: 1800,
    availableToday: false,
    nextSlot: 'Tomorrow, 3:00 PM',
    experience: 14,
    avatarColor: Color(0xFFFF9F4A),
    avatarInitials: 'MK',
    languages: ['English', 'Telugu', 'Hindi'],
  ),
  Doctor(
    id: 'd8',
    name: 'Dr. Kabir Malhotra',
    specialty: DoctorSpecialty.dentist,
    qualifications: 'BDS · MDS Prosthodontics · Implant Specialist',
    clinic: 'SmileFirst Dental Studio',
    address: 'Rajouri Garden, New Delhi — 110027',
    phone: '+91-92501-34678',
    rating: 4.9,
    reviewCount: 389,
    distanceKm: 3.0,
    consultationFee: 700,
    availableToday: true,
    nextSlot: 'Today, 7:00 PM',
    experience: 8,
    avatarColor: Color(0xFF0099B8),
    avatarInitials: 'KM',
    languages: ['Hindi', 'English', 'Punjabi'],
  ),
  Doctor(
    id: 'd9',
    name: 'Dr. Sneha Bose',
    specialty: DoctorSpecialty.nutritionist,
    qualifications: 'M.Sc Clinical Nutrition · Certified Diabetic Educator',
    clinic: 'Diet & Wellness Hub',
    address: 'Pitampura, New Delhi — 110034',
    phone: '+91-99101-22334',
    rating: 4.5,
    reviewCount: 142,
    distanceKm: 5.8,
    consultationFee: 600,
    availableToday: true,
    nextSlot: 'Today, 11:00 AM',
    experience: 6,
    avatarColor: Color(0xFF34FF8C),
    avatarInitials: 'SB',
    languages: ['English', 'Bengali', 'Hindi'],
  ),
  Doctor(
    id: 'd10',
    name: 'Dr. Tarun Nair',
    specialty: DoctorSpecialty.cardiologist,
    qualifications: 'MD · DM Cardiology · Max Super Specialty',
    clinic: 'CardioMax Centre',
    address: 'Rohini, New Delhi — 110085',
    phone: '+91-86050-78912',
    rating: 4.6,
    reviewCount: 278,
    distanceKm: 8.3,
    consultationFee: 2000,
    availableToday: false,
    nextSlot: 'Mon, 9:00 AM',
    experience: 20,
    avatarColor: Color(0xFFFF5C7A),
    avatarInitials: 'TN',
    languages: ['English', 'Malayalam', 'Hindi'],
  ),
];

// ─── Distance filter options ──────────────────────────────────

enum DistanceFilter { two, five, ten, any }

extension DistanceFilterLabel on DistanceFilter {
  String get label => switch (this) {
        DistanceFilter.two => '2 km',
        DistanceFilter.five => '5 km',
        DistanceFilter.ten => '10 km',
        DistanceFilter.any => 'Any',
      };

  double get km => switch (this) {
        DistanceFilter.two => 2.0,
        DistanceFilter.five => 5.0,
        DistanceFilter.ten => 10.0,
        DistanceFilter.any => double.infinity,
      };
}

enum RatingFilter { fourPlus, threePlus, any }

extension RatingFilterLabel on RatingFilter {
  String get label => switch (this) {
        RatingFilter.fourPlus => '4+ ★',
        RatingFilter.threePlus => '3+ ★',
        RatingFilter.any => 'Any',
      };

  double get minRating => switch (this) {
        RatingFilter.fourPlus => 4.0,
        RatingFilter.threePlus => 3.0,
        RatingFilter.any => 0.0,
      };
}

// ─── Main Screen ───────────────────────────────────────────────

class NearbyDoctorsScreen extends StatefulWidget {
  const NearbyDoctorsScreen({super.key});

  @override
  State<NearbyDoctorsScreen> createState() => _NearbyDoctorsScreenState();
}

class _NearbyDoctorsScreenState extends State<NearbyDoctorsScreen> {
  // ── Filter state ───────────────────────────────────────────

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  /// null = All specialties
  DoctorSpecialty? _selectedSpecialty;

  DistanceFilter _distanceFilter = DistanceFilter.any;
  RatingFilter _ratingFilter = RatingFilter.any;
  bool _availableTodayOnly = false;

  /// Dismissable AI recommendation card visibility.
  bool _showAiCard = true;

  // ── Computed list ──────────────────────────────────────────

  List<Doctor> get _filteredDoctors {
    return _kDoctors.where((d) {
      // Specialty filter
      if (_selectedSpecialty != null && d.specialty != _selectedSpecialty) return false;
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!d.name.toLowerCase().contains(q) &&
            !d.specialty.label.toLowerCase().contains(q) &&
            !d.clinic.toLowerCase().contains(q)) {
          return false;
        }
      }
      // Distance filter
      if (d.distanceKm > _distanceFilter.km) return false;
      // Rating filter
      if (d.rating < _ratingFilter.minRating) return false;
      // Availability filter
      if (_availableTodayOnly && !d.availableToday) return false;
      return true;
    }).toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Filter bottom sheet ────────────────────────────────────

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: VColor.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(VRadius.xl)),
      ),
      builder: (_) => _FilterSheet(
        distanceFilter: _distanceFilter,
        ratingFilter: _ratingFilter,
        availableTodayOnly: _availableTodayOnly,
        onApply: (dist, rating, avail) {
          setState(() {
            _distanceFilter = dist;
            _ratingFilter = rating;
            _availableTodayOnly = avail;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  // ── Doctor detail bottom sheet ─────────────────────────────

  void _showDoctorDetail(Doctor doc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: VColor.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(VRadius.xl)),
      ),
      builder: (_) => _DoctorDetailSheet(doctor: doc),
    );
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredDoctors;

    return Scaffold(
      backgroundColor: VColor.bg,
      body: CustomScrollView(
        slivers: [
          // ── App bar + search ──────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 130,
            backgroundColor: VColor.bg,
            surfaceTintColor: Colors.transparent,
            actions: [
              IconButton(
                onPressed: _showFilterSheet,
                icon: const Icon(Icons.tune_rounded, color: VColor.accent),
                tooltip: 'Filters',
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: EdgeInsets.zero,
              title: Container(
                color: VColor.bg,
                padding: const EdgeInsets.fromLTRB(VSpace.base, 0, VSpace.sm, VSpace.sm),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Find a Doctor',
                      style: TextStyle(
                        color: VColor.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: VSpace.xs),
                    // Search bar
                    SizedBox(
                      height: 42,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        style: const TextStyle(color: VColor.text, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search doctors, specialties, clinics…',
                          hintStyle: const TextStyle(color: VColor.textLow, fontSize: 13),
                          prefixIcon: const Icon(Icons.search_rounded, color: VColor.textLow, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18, color: VColor.textLow),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: VSpace.base),
                          filled: true,
                          fillColor: VColor.surfaceHigh,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(VRadius.pill),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(VRadius.pill),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(VRadius.pill),
                            borderSide: const BorderSide(color: VColor.accent, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              background: Container(color: VColor.bg),
            ),
          ),

          // ── Specialty chips ───────────────────────────────
          SliverToBoxAdapter(
            child: SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: VSpace.base),
                children: [
                  // "All" chip
                  Padding(
                    padding: const EdgeInsets.only(right: VSpace.sm),
                    child: _SpecialtyChip(
                      label: 'All',
                      icon: Icons.grid_view_rounded,
                      color: VColor.accent,
                      selected: _selectedSpecialty == null,
                      onTap: () => setState(() => _selectedSpecialty = null),
                    ),
                  ),
                  ...DoctorSpecialty.values.map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(right: VSpace.sm),
                      child: _SpecialtyChip(
                        label: s.label,
                        icon: s.icon,
                        color: s.color,
                        selected: _selectedSpecialty == s,
                        onTap: () => setState(() {
                          _selectedSpecialty = _selectedSpecialty == s ? null : s;
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── AI recommendation card ────────────────────────
          if (_showAiCard)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(VSpace.base, VSpace.base, VSpace.base, 0),
                child: _AiRecommendationCard(
                  onDismiss: () => setState(() => _showAiCard = false),
                ),
              ),
            ),

          // ── Active filters row ────────────────────────────
          if (_distanceFilter != DistanceFilter.any ||
              _ratingFilter != RatingFilter.any ||
              _availableTodayOnly)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(VSpace.base, VSpace.base, VSpace.base, 0),
                child: _ActiveFiltersRow(
                  distanceFilter: _distanceFilter,
                  ratingFilter: _ratingFilter,
                  availableTodayOnly: _availableTodayOnly,
                  onClearAll: () => setState(() {
                    _distanceFilter = DistanceFilter.any;
                    _ratingFilter = RatingFilter.any;
                    _availableTodayOnly = false;
                  }),
                ),
              ),
            ),

          // ── Results header ────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(VSpace.base, VSpace.base, VSpace.base, VSpace.sm),
              child: Text(
                '${filtered.length} doctor${filtered.length == 1 ? '' : 's'} found',
                style: const TextStyle(color: VColor.textLow, fontSize: 12.5),
              ),
            ),
          ),

          // ── Doctor cards list ─────────────────────────────
          filtered.isEmpty
              ? SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(
                    onClearFilters: () => setState(() {
                      _selectedSpecialty = null;
                      _distanceFilter = DistanceFilter.any;
                      _ratingFilter = RatingFilter.any;
                      _availableTodayOnly = false;
                      _searchController.clear();
                      _searchQuery = '';
                    }),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(VSpace.base, 0, VSpace.base, VSpace.xl),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: VSpace.sm),
                        child: _DoctorCard(
                          doctor: filtered[i],
                          onTap: () => _showDoctorDetail(filtered[i]),
                        ),
                      ),
                      childCount: filtered.length,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

// ─── Specialty Chip ───────────────────────────────────────────

class _SpecialtyChip extends StatelessWidget {
  const _SpecialtyChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: VSpace.base, vertical: VSpace.sm),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(30) : VColor.surface,
          borderRadius: BorderRadius.circular(VRadius.pill),
          border: Border.all(
            color: selected ? color : VColor.line,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? color : VColor.textLow),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: selected ? color : VColor.textMid,
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── AI Recommendation Card ───────────────────────────────────

class _AiRecommendationCard extends StatelessWidget {
  const _AiRecommendationCard({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(VSpace.base),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D1B2A), Color(0xFF0A1929)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(VRadius.lg),
        border: Border.all(color: VColor.accentGlow),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: VSpace.sm, vertical: 4),
                decoration: BoxDecoration(
                  color: VColor.accentGlow,
                  borderRadius: BorderRadius.circular(VRadius.pill),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: VColor.accent, size: 12),
                    SizedBox(width: 4),
                    Text(
                      'AI Recommendation',
                      style: TextStyle(color: VColor.accent, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onDismiss,
                child: const Icon(Icons.close_rounded, color: VColor.textLow, size: 18),
              ),
            ],
          ),
          const SizedBox(height: VSpace.sm),
          const Text(
            'See a Nutritionist',
            style: TextStyle(color: VColor.text, fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Based on your recent blood report, your serum ferritin and Vitamin D3 levels are below optimal range. '
            'We recommend consulting a Nutritionist to get a personalised diet and supplement plan.',
            style: TextStyle(color: VColor.textMid, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: VSpace.sm),
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.arrow_forward_rounded, size: 15),
            label: const Text('Show Nutritionists'),
            style: TextButton.styleFrom(
              foregroundColor: VColor.accent,
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Active Filters Row ───────────────────────────────────────

class _ActiveFiltersRow extends StatelessWidget {
  const _ActiveFiltersRow({
    required this.distanceFilter,
    required this.ratingFilter,
    required this.availableTodayOnly,
    required this.onClearAll,
  });

  final DistanceFilter distanceFilter;
  final RatingFilter ratingFilter;
  final bool availableTodayOnly;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.filter_list_rounded, color: VColor.textLow, size: 16),
        const SizedBox(width: VSpace.xs),
        if (distanceFilter != DistanceFilter.any)
          _FilterChipBadge(label: 'Within ${distanceFilter.label}'),
        if (ratingFilter != RatingFilter.any)
          _FilterChipBadge(label: ratingFilter.label),
        if (availableTodayOnly) const _FilterChipBadge(label: 'Available today'),
        const Spacer(),
        TextButton(
          onPressed: onClearAll,
          style: TextButton.styleFrom(
            foregroundColor: VColor.crit,
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(fontSize: 12),
          ),
          child: const Text('Clear all'),
        ),
      ],
    );
  }
}

class _FilterChipBadge extends StatelessWidget {
  const _FilterChipBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: VSpace.xs),
      padding: const EdgeInsets.symmetric(horizontal: VSpace.sm, vertical: 3),
      decoration: BoxDecoration(
        color: VColor.accentGlow,
        borderRadius: BorderRadius.circular(VRadius.pill),
      ),
      child: Text(label, style: const TextStyle(color: VColor.accent, fontSize: 11)),
    );
  }
}

// ─── Doctor Card ──────────────────────────────────────────────

class _DoctorCard extends StatelessWidget {
  const _DoctorCard({required this.doctor, required this.onTap});

  final Doctor doctor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final spec = doctor.specialty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(VSpace.base),
        decoration: BoxDecoration(
          color: VColor.surface,
          borderRadius: BorderRadius.circular(VRadius.lg),
          border: Border.all(color: VColor.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: avatar + name + rating ─────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar circle
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: doctor.avatarColor.withAlpha(40),
                    shape: BoxShape.circle,
                    border: Border.all(color: doctor.avatarColor.withAlpha(80), width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      doctor.avatarInitials,
                      style: TextStyle(
                        color: doctor.avatarColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: VSpace.base),
                // Name + specialty + qualifications
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doctor.name,
                        style: const TextStyle(
                          color: VColor.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(spec.icon, size: 13, color: spec.color),
                          const SizedBox(width: 4),
                          Text(
                            spec.label,
                            style: TextStyle(color: spec.color, fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        doctor.qualifications,
                        style: const TextStyle(color: VColor.textLow, fontSize: 11.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Available today badge
                if (doctor.availableToday)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: VColor.accentGreenGlow,
                      borderRadius: BorderRadius.circular(VRadius.pill),
                    ),
                    child: const Text(
                      'TODAY',
                      style: TextStyle(
                        color: VColor.accentGreen,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: VSpace.sm),
            const Divider(color: VColor.line, height: 1),
            const SizedBox(height: VSpace.sm),

            // ── Stats row ───────────────────────────────────
            Row(
              children: [
                _StatBadge(
                  icon: Icons.star_rounded,
                  iconColor: VColor.warn,
                  label: '${doctor.rating} (${doctor.reviewCount})',
                ),
                const SizedBox(width: VSpace.base),
                _StatBadge(
                  icon: Icons.location_on_rounded,
                  iconColor: VColor.accent,
                  label: '${doctor.distanceKm.toStringAsFixed(1)} km',
                ),
                const SizedBox(width: VSpace.base),
                _StatBadge(
                  icon: Icons.work_history_outlined,
                  iconColor: VColor.textLow,
                  label: '${doctor.experience} yrs exp',
                ),
              ],
            ),

            const SizedBox(height: VSpace.sm),

            // ── Clinic + next slot ──────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doctor.clinic,
                        style: const TextStyle(color: VColor.textMid, fontSize: 12.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 12, color: VColor.textLow),
                          const SizedBox(width: 3),
                          Text(
                            'Next: ${doctor.nextSlot}',
                            style: const TextStyle(color: VColor.textLow, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Fee + Book button
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${doctor.consultationFee}',
                      style: const TextStyle(color: VColor.text, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 34,
                      child: FilledButton(
                        onPressed: () => onTap(),
                        style: FilledButton.styleFrom(
                          backgroundColor: VColor.accent,
                          foregroundColor: VColor.textOnAccent,
                          padding: const EdgeInsets.symmetric(horizontal: VSpace.base),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(VRadius.pill),
                          ),
                          textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                        child: const Text('Book'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({required this.icon, required this.iconColor, required this.label});

  final IconData icon;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: iconColor),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(color: VColor.textMid, fontSize: 12)),
      ],
    );
  }
}

// ─── Doctor Detail Bottom Sheet ───────────────────────────────

class _DoctorDetailSheet extends StatelessWidget {
  const _DoctorDetailSheet({required this.doctor});

  final Doctor doctor;

  @override
  Widget build(BuildContext context) {
    final spec = doctor.specialty;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: VColor.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(VRadius.xl)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(VSpace.base, 0, VSpace.base, VSpace.xl),
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: VSpace.base),
                decoration: BoxDecoration(
                  color: VColor.line,
                  borderRadius: BorderRadius.circular(VRadius.pill),
                ),
              ),
            ),

            // ── Hero row ─────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Large avatar
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: doctor.avatarColor.withAlpha(40),
                    shape: BoxShape.circle,
                    border: Border.all(color: doctor.avatarColor.withAlpha(80), width: 2),
                  ),
                  child: Center(
                    child: Text(
                      doctor.avatarInitials,
                      style: TextStyle(
                        color: doctor.avatarColor,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: VSpace.base),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doctor.name,
                        style: const TextStyle(
                          color: VColor.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(spec.icon, size: 14, color: spec.color),
                          const SizedBox(width: 4),
                          Text(
                            spec.label,
                            style: TextStyle(color: spec.color, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        doctor.qualifications,
                        style: const TextStyle(color: VColor.textLow, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                if (doctor.availableToday)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: VColor.accentGreenGlow,
                      borderRadius: BorderRadius.circular(VRadius.pill),
                    ),
                    child: const Text(
                      'AVAILABLE TODAY',
                      style: TextStyle(
                        color: VColor.accentGreen,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: VSpace.base),

            // ── Stats row ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(vertical: VSpace.base),
              decoration: BoxDecoration(
                color: VColor.surfaceRaised,
                borderRadius: BorderRadius.circular(VRadius.md),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _DetailStat(label: 'Rating', value: '${doctor.rating}★', color: VColor.warn),
                  _VertDivider(),
                  _DetailStat(label: 'Reviews', value: '${doctor.reviewCount}', color: VColor.accent),
                  _VertDivider(),
                  _DetailStat(label: 'Experience', value: '${doctor.experience} yrs', color: VColor.accentGreen),
                  _VertDivider(),
                  _DetailStat(label: 'Distance', value: '${doctor.distanceKm.toStringAsFixed(1)}km', color: VColor.textMid),
                ],
              ),
            ),

            const SizedBox(height: VSpace.base),

            // ── Clinic info ───────────────────────────────────
            _SheetSection(title: 'Clinic Info', children: [
              _DetailRow(icon: Icons.business_rounded, label: doctor.clinic),
              _DetailRow(icon: Icons.location_on_outlined, label: doctor.address),
              _DetailRow(icon: Icons.phone_outlined, label: doctor.phone),
            ]),

            const SizedBox(height: VSpace.base),

            // ── Next slot ─────────────────────────────────────
            _SheetSection(title: 'Availability', children: [
              _DetailRow(
                icon: Icons.event_available_rounded,
                label: 'Next available: ${doctor.nextSlot}',
                labelColor: doctor.availableToday ? VColor.accentGreen : VColor.textMid,
              ),
            ]),

            const SizedBox(height: VSpace.base),

            // ── Languages ─────────────────────────────────────
            _SheetSection(title: 'Languages Spoken', children: [
              Wrap(
                spacing: VSpace.sm,
                children: doctor.languages.map((l) => Container(
                  margin: const EdgeInsets.only(top: VSpace.xs),
                  padding: const EdgeInsets.symmetric(horizontal: VSpace.sm, vertical: 4),
                  decoration: BoxDecoration(
                    color: VColor.surfaceHigh,
                    borderRadius: BorderRadius.circular(VRadius.pill),
                    border: Border.all(color: VColor.line),
                  ),
                  child: Text(l, style: const TextStyle(color: VColor.textMid, fontSize: 12)),
                )).toList(),
              ),
            ]),

            const SizedBox(height: VSpace.base),

            // ── Fee ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(VSpace.base),
              decoration: BoxDecoration(
                color: VColor.surfaceRaised,
                borderRadius: BorderRadius.circular(VRadius.md),
                border: Border.all(color: VColor.line),
              ),
              child: Row(
                children: [
                  const Text('Consultation Fee', style: TextStyle(color: VColor.textMid, fontSize: 14)),
                  const Spacer(),
                  Text(
                    '₹${doctor.consultationFee}',
                    style: const TextStyle(
                      color: VColor.text,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: VSpace.base),

            // ── Action buttons ────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final uri = Uri.parse('tel:${doctor.phone}');
                      try {
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        }
                      } catch (_) {}
                    },
                    icon: const Icon(Icons.call_rounded, size: 18),
                    label: const Text('Call'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: VColor.accentGreen,
                      side: const BorderSide(color: VColor.accentGreen),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(VRadius.pill),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: VSpace.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final uri = Uri.parse(
                          'https://maps.google.com/?q=${Uri.encodeComponent(doctor.address)}');
                      try {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      } catch (_) {}
                    },
                    icon: const Icon(Icons.directions_rounded, size: 18),
                    label: const Text('Directions'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: VColor.accent,
                      side: const BorderSide(color: VColor.accent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(VRadius.pill),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: VSpace.sm),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Appointment request sent to ${doctor.name}!'),
                    duration: const Duration(seconds: 3),
                  ),
                );
              },
              icon: const Icon(Icons.calendar_today_rounded, size: 18),
              label: const Text('Book Appointment'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(VRadius.pill),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  const _DetailStat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: VColor.textLow, fontSize: 10.5)),
      ],
    );
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 30, color: VColor.line);
  }
}

class _SheetSection extends StatelessWidget {
  const _SheetSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: VColor.textLow,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: VSpace.sm),
        Container(
          padding: const EdgeInsets.all(VSpace.base),
          decoration: BoxDecoration(
            color: VColor.surfaceRaised,
            borderRadius: BorderRadius.circular(VRadius.md),
            border: Border.all(color: VColor.line),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    this.labelColor = VColor.textMid,
  });

  final IconData icon;
  final String label;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: VSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: VColor.textLow),
          const SizedBox(width: VSpace.sm),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: labelColor, fontSize: 13.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Filter Bottom Sheet ──────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.distanceFilter,
    required this.ratingFilter,
    required this.availableTodayOnly,
    required this.onApply,
  });

  final DistanceFilter distanceFilter;
  final RatingFilter ratingFilter;
  final bool availableTodayOnly;
  final void Function(DistanceFilter, RatingFilter, bool) onApply;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late DistanceFilter _dist;
  late RatingFilter _rating;
  late bool _avail;

  @override
  void initState() {
    super.initState();
    _dist = widget.distanceFilter;
    _rating = widget.ratingFilter;
    _avail = widget.availableTodayOnly;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(VSpace.base, VSpace.base, VSpace.base, VSpace.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: VSpace.base),
              decoration: BoxDecoration(
                color: VColor.line,
                borderRadius: BorderRadius.circular(VRadius.pill),
              ),
            ),
          ),
          const Text(
            'Filter Doctors',
            style: TextStyle(color: VColor.text, fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: VSpace.base),

          // Distance
          const Text('Distance', style: TextStyle(color: VColor.textLow, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const SizedBox(height: VSpace.sm),
          Wrap(
            spacing: VSpace.sm,
            children: DistanceFilter.values.map((d) => _FilterPill(
              label: d.label,
              selected: _dist == d,
              onTap: () => setState(() => _dist = d),
            )).toList(),
          ),
          const SizedBox(height: VSpace.base),

          // Rating
          const Text('Rating', style: TextStyle(color: VColor.textLow, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const SizedBox(height: VSpace.sm),
          Wrap(
            spacing: VSpace.sm,
            children: RatingFilter.values.map((r) => _FilterPill(
              label: r.label,
              selected: _rating == r,
              onTap: () => setState(() => _rating = r),
            )).toList(),
          ),
          const SizedBox(height: VSpace.base),

          // Availability
          const Text('Availability', style: TextStyle(color: VColor.textLow, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const SizedBox(height: VSpace.sm),
          Row(
            children: [
              _FilterPill(
                label: 'Available Today',
                selected: _avail,
                onTap: () => setState(() => _avail = !_avail),
              ),
              _FilterPill(
                label: 'All',
                selected: !_avail,
                onTap: () => setState(() => _avail = false),
              ),
            ],
          ),
          const SizedBox(height: VSpace.xl),

          // Apply
          FilledButton(
            onPressed: () => widget.onApply(_dist, _rating, _avail),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(VRadius.pill),
              ),
            ),
            child: const Text('Apply Filters'),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: VSpace.sm, right: VSpace.xs),
        padding: const EdgeInsets.symmetric(horizontal: VSpace.base, vertical: VSpace.sm),
        decoration: BoxDecoration(
          color: selected ? VColor.accentGlow : VColor.surfaceHigh,
          borderRadius: BorderRadius.circular(VRadius.pill),
          border: Border.all(
            color: selected ? VColor.accent : VColor.line,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? VColor.accent : VColor.textMid,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onClearFilters});

  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.search_off_rounded, color: VColor.textLow, size: 56),
        const SizedBox(height: VSpace.base),
        const Text(
          'No doctors found',
          style: TextStyle(color: VColor.text, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: VSpace.sm),
        const Text(
          'Try adjusting your filters or search query.',
          style: TextStyle(color: VColor.textLow, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: VSpace.base),
        TextButton(
          onPressed: onClearFilters,
          style: TextButton.styleFrom(foregroundColor: VColor.accent),
          child: const Text('Clear all filters'),
        ),
      ],
    );
  }
}

// ─── Navigation helpers ───────────────────────────────────────
// Use:
// Navigator.push(context, MaterialPageRoute(builder: (_) => const NearbyDoctorsScreen()));
