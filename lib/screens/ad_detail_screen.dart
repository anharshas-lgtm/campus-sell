import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/ad_model.dart';

class AdDetailScreen extends StatefulWidget {
  final AdModel ad;
  const AdDetailScreen({super.key, required this.ad});

  @override
  State<AdDetailScreen> createState() => _AdDetailScreenState();
}

class _AdDetailScreenState extends State<AdDetailScreen> {
  int _currentImageIndex = 0;

  Future<void> _openWhatsApp(String number) async {
    String cleaned = number.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (!cleaned.startsWith('+')) cleaned = '+91$cleaned';
    final uri = Uri.parse('https://wa.me/$cleaned');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showError('WhatsApp is not installed.');
    }
  }

  Future<void> _makeCall(String number) async {
    String cleaned = number.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final uri = Uri.parse('tel:$cleaned');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showError('Could not open dialer.');
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red));
    }
  }

  Future<void> _reportAd() async {
    final ad = widget.ad;
    String? selectedReason;

    const reasons = [
      'Spam or misleading',
      'Inappropriate content',
      'Fake listing',
      'Wrong price',
      'Already sold',
      'Other',
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Report this Ad',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, color: Colors.grey),
                      ),
                    ],
                  ),
                  Text(
                    'Why are you reporting "${ad.title}"?',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  ...reasons.map((reason) => GestureDetector(
                    onTap: () => setSheetState(
                            () => selectedReason = reason),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: selectedReason == reason
                            ? const Color(0xFFF0EDFF)
                            : const Color(0xFFF8F8F8),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selectedReason == reason
                              ? Colors.deepPurple
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(reason,
                                style: TextStyle(
                                    fontSize: 14,
                                    color: selectedReason == reason
                                        ? Colors.deepPurple
                                        : Colors.black87,
                                    fontWeight: selectedReason == reason
                                        ? FontWeight.w600
                                        : FontWeight.w400)),
                          ),
                          if (selectedReason == reason)
                            const Icon(Icons.check_circle,
                                color: Colors.deepPurple, size: 18),
                        ],
                      ),
                    ),
                  )),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: selectedReason == null
                          ? null
                          : () async {
                        Navigator.pop(ctx);
                        await _submitReport(selectedReason!);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        disabledBackgroundColor: Colors.grey.shade200,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Submit Report',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitReport(String reason) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('ad_reports').add({
        'adId': widget.ad.id,
        'adTitle': widget.ad.title,
        'postedBy': widget.ad.postedBy,
        'reportedBy': user?.uid ?? '',
        'reason': reason,
        'reportedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
          Text('✅ Report submitted. We will review it shortly.'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to submit: $e'),
            backgroundColor: Colors.red));
      }
    }
  }

  void _openFullImage(int startIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullImageViewer(
          images: widget.ad.images,
          initialIndex: startIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ad = widget.ad;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        // ── No actions — flag removed from AppBar ─────────────────────
        title: Text(
          ad.title,
          style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 17),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImageViewer(ad),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + Price
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(ad.title,
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87)),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '₹${ad.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Description
                  const Text('Description',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87)),
                  const SizedBox(height: 8),
                  Text(ad.description,
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          height: 1.5)),
                  const SizedBox(height: 20),

                  // Poster card
                  _buildPosterCard(ad),
                  const SizedBox(height: 20),

                  // WhatsApp
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () => _openWhatsApp(ad.contactNumber),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.chat,
                          color: Colors.white, size: 20),
                      label: const Text('Chat on WhatsApp',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Call
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () => _makeCall(ad.contactNumber),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: Colors.deepPurple, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.call,
                          color: Colors.deepPurple, size: 20),
                      label: const Text('Call Seller',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.deepPurple)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Report — bottom only ──────────────────────────────
                  Center(
                    child: TextButton.icon(
                      onPressed: _reportAd,
                      icon: const Icon(Icons.flag_outlined,
                          color: Colors.red, size: 16),
                      label: const Text(
                        'Report this ad',
                        style: TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPosterCard(AdModel ad) {
    final List<String> parts = [];
    if (ad.postedByProgram.isNotEmpty) parts.add(ad.postedByProgram);
    if (ad.postedByDepartment.isNotEmpty)
      parts.add(ad.postedByDepartment);
    if (ad.postedByYear.isNotEmpty) parts.add(ad.postedByYear);
    final academicInfo = parts.join(' · ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5FF),
        borderRadius: BorderRadius.circular(14),
        border:
        Border.all(color: Colors.deepPurple.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Posted by',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.deepPurple.shade100,
                radius: 26,
                child: Text(
                  ad.postedByName.isNotEmpty
                      ? ad.postedByName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ad.postedByName,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    if (academicInfo.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(children: [
                        const Icon(Icons.school_outlined,
                            size: 13, color: Colors.deepPurple),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(academicInfo,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ]),
                    ],
                    const SizedBox(height: 3),
                    Row(children: [
                      const Icon(Icons.location_on_outlined,
                          size: 13, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(ad.campusName,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500)),
                      ),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImageViewer(AdModel ad) {
    if (ad.images.isEmpty) {
      return Container(
        height: 250,
        color: const Color(0xFFF0EDFF),
        child: const Center(
          child: Icon(Icons.image_outlined,
              size: 72, color: Colors.deepPurple),
        ),
      );
    }

    return Column(
      children: [
        GestureDetector(
          onTap: () => _openFullImage(_currentImageIndex),
          child: SizedBox(
            height: 280,
            width: double.infinity,
            child: PageView.builder(
              itemCount: ad.images.length,
              onPageChanged: (i) =>
                  setState(() => _currentImageIndex = i),
              itemBuilder: (_, i) => Image.network(
                ad.images[i],
                fit: BoxFit.cover,
                width: double.infinity,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : const Center(
                    child: CircularProgressIndicator()),
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFFF0EDFF),
                  child: const Icon(Icons.broken_image_outlined,
                      size: 60, color: Colors.grey),
                ),
              ),
            ),
          ),
        ),
        if (ad.images.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              ad.images.length,
                  (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _currentImageIndex == i ? 18 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: _currentImageIndex == i
                      ? Colors.deepPurple
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _FullImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  const _FullImageViewer(
      {required this.images, required this.initialIndex});

  @override
  State<_FullImageViewer> createState() => _FullImageViewerState();
}

class _FullImageViewerState extends State<_FullImageViewer> {
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('${_current + 1} / ${widget.images.length}',
            style:
            const TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: PageView.builder(
        controller: PageController(initialPage: widget.initialIndex),
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (_, i) => InteractiveViewer(
          child: Center(
            child: Image.network(
              widget.images[i],
              fit: BoxFit.contain,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : const Center(
                  child: CircularProgressIndicator(
                      color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }
}