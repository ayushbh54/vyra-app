import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Full-page club detail with request-to-join workflow.
///
/// Returns the [ClubItem.id] via `Navigator.pop` when a request is approved
/// so the list screen can mark the club as pending/joined.
class ClubDetailScreen extends StatefulWidget {
  const ClubDetailScreen({super.key, required this.club, required this.isPending});

  final ClubItem club;
  final bool isPending;

  @override
  State<ClubDetailScreen> createState() => _ClubDetailScreenState();
}

class _ClubDetailScreenState extends State<ClubDetailScreen> {
  late bool _pending = widget.isPending || widget.club.requestPending;
  late bool _member = widget.club.joined;
  bool _processing = false;

  Future<void> _requestToJoin() async {
    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VColor.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.lg)),
        title: const Text('Request to Join', style: TextStyle(color: VColor.text, fontWeight: FontWeight.w700)),
        content: Text(
          'Send a join request to "${widget.club.name}"?\nThe club manager will review your request.',
          style: const TextStyle(color: VColor.textMid, fontSize: 14, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: VColor.textLow)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: VColor.accent,
              foregroundColor: VColor.textOnAccent,
            ),
            child: const Text('Send Request'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() {
      _pending = true;
      _processing = true;
    });

    // Simulate 3-second manager approval
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    setState(() {
      _pending = false;
      _member = true;
      _processing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎉 Approved!'),
        backgroundColor: VColor.accentGreen,
      ),
    );

    // Return club id so the list screen can update its state.
    if (mounted) Navigator.pop(context, widget.club.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VColor.bg,
      appBar: AppBar(
        title: Text(widget.club.name),
        backgroundColor: VColor.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: VColor.text),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(VSpace.base),
              children: [
                // ── Club hero card ──────────────────────────────────
                VCard(
                  tone: CardTone.raised,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: VColor.accentGlow,
                              borderRadius: BorderRadius.circular(VRadius.md),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.groups, color: VColor.accent, size: 30),
                          ),
                          const SizedBox(width: VSpace.base),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.club.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                    color: VColor.text,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    VPill(widget.club.interestTag),
                                    const SizedBox(width: VSpace.sm),
                                    Text(
                                      '${widget.club.memberCount} members',
                                      style: const TextStyle(color: VColor.textLow, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: VSpace.base),
                      Text(
                        widget.club.description,
                        style: const TextStyle(color: VColor.textMid, fontSize: 14, height: 1.5),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: VSpace.base),

                // ── Manager info ────────────────────────────────────
                VCard(
                  tone: CardTone.normal,
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: VColor.surfaceHigh,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.person, color: VColor.textMid, size: 22),
                      ),
                      const SizedBox(width: VSpace.sm),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Club Manager',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: VColor.text,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Manages membership & club activities',
                              style: TextStyle(color: VColor.textLow, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.verified_rounded, color: VColor.accent, size: 20),
                    ],
                  ),
                ),

                const SizedBox(height: VSpace.base),

                // ── Club details section ────────────────────────────
                VCard(
                  tone: CardTone.normal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const VLabel('About this club'),
                      const SizedBox(height: VSpace.sm),
                      _DetailRow(
                        icon: Icons.interests_rounded,
                        label: 'Interest',
                        value: widget.club.interestTag,
                      ),
                      const SizedBox(height: VSpace.sm),
                      _DetailRow(
                        icon: Icons.people_alt_rounded,
                        label: 'Members',
                        value: '${widget.club.memberCount} active',
                      ),
                      const SizedBox(height: VSpace.sm),
                      const _DetailRow(
                        icon: Icons.lock_outline_rounded,
                        label: 'Joining',
                        value: 'Request required',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom action bar ─────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(VSpace.base, VSpace.sm, VSpace.base, VSpace.xl),
            decoration: const BoxDecoration(
              color: VColor.surface,
              border: Border(top: BorderSide(color: VColor.line)),
            ),
            child: _buildActionButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    if (_member) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.check_circle_rounded, color: VColor.accentGreen, size: 18),
          label: const Text(
            'MEMBER',
            style: TextStyle(color: VColor.accentGreen, fontSize: 14, fontWeight: FontWeight.w700),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: VColor.accentGreenGlow),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      );
    }

    if (_pending) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: null,
          icon: _processing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: VColor.accent),
                )
              : const Icon(Icons.hourglass_top_rounded, color: VColor.accent, size: 18),
          label: Text(
            _processing ? 'REVIEWING REQUEST…' : 'REQUEST PENDING',
            style: const TextStyle(color: VColor.accent, fontSize: 14, fontWeight: FontWeight.w700),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: VColor.accentGlow),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      );
    }

    return VGradientButton(
      label: 'Request to Join',
      icon: Icons.group_add_rounded,
      onPressed: _requestToJoin,
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: VColor.accent),
        const SizedBox(width: VSpace.sm),
        Text(label, style: const TextStyle(color: VColor.textLow, fontSize: 13)),
        const Spacer(),
        Text(value, style: const TextStyle(color: VColor.text, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
