import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';

class MyCampusScreen extends StatelessWidget {
  final UserModel profile;
  const MyCampusScreen({super.key, required this.profile});

  // ── Only ad count remains ─────────────────────────────────────────────────
  Future<int> _fetchAdCount() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('ads')
          .where('campusId', isEqualTo: profile.campusId)
          .where('isActive', isEqualTo: true)
          .get();
      return snap.docs.length;
    } catch (e) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('My Campus'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── Campus info card ──────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.deepPurple.shade600,
                    Colors.deepPurple.shade400,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.school,
                      color: Colors.white70, size: 32),
                  const SizedBox(height: 12),
                  Text(
                    profile.campus,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  if (profile.district.isNotEmpty)
                    _infoRow(Icons.location_city_outlined,
                        profile.district),
                  if (profile.state.isNotEmpty)
                    _infoRow(Icons.map_outlined, profile.state),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Only Active Ads stat ──────────────────────────────────
            _StatCard(
              icon: Icons.sell_outlined,
              label: 'Active Ads on Campus',
              color: Colors.deepPurple,
              future: _fetchAdCount(),
            ),
            const SizedBox(height: 20),

            // Info note
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'To change your campus, contact support or '
                          'submit a new campus request. '
                          'Campus changes require admin verification.',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange.shade900,
                          height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(children: [
        Icon(icon, size: 14, color: Colors.white60),
        const SizedBox(width: 6),
        Text(text,
            style: const TextStyle(
                fontSize: 14, color: Colors.white70)),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Future<int> future;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.future,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: color.withOpacity(0.2), width: 0.8),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FutureBuilder<int>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return SizedBox(
                        height: 28,
                        width: 28,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: color));
                  }
                  return Text(
                    '${snapshot.data ?? 0}',
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: color),
                  );
                },
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}