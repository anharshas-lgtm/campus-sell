import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/ad_model.dart';
import '../../services/ad_service.dart';
import '../ad_detail_screen.dart';
import '../post_ad_screen.dart';

class MyAdsScreen extends StatelessWidget {
  const MyAdsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final adService = AdService();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: const Text('My Ads',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Colors.black87)),
      ),
      body: StreamBuilder<List<AdModel>>(
        stream: adService.fetchUserAds(user!.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red)),
            );
          }

          final ads = snapshot.data ?? [];

          if (ads.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.post_add_outlined,
                      size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text("You haven't posted anything yet",
                      style: TextStyle(
                          color: Colors.grey.shade400, fontSize: 15)),
                  const SizedBox(height: 8),
                  Text('Tap the Post tab to create an ad',
                      style: TextStyle(
                          color: Colors.grey.shade400, fontSize: 13)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: ads.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _MyAdCard(ad: ads[i]),
          );
        },
      ),
    );
  }
}

class _MyAdCard extends StatelessWidget {
  final AdModel ad;
  const _MyAdCard({required this.ad});

  Future<void> _deleteAd(BuildContext context, AdModel ad) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Ad'),
        content: Text('Delete "${ad.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style:
            ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await AdService().deleteAd(ad);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Ad deleted.'),
              backgroundColor: Colors.red));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => AdDetailScreen(ad: ad))),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: Colors.deepPurple.withOpacity(0.2), width: 0.8),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12)),
              child: SizedBox(
                width: 90,
                height: 90,
                child: ad.images.isNotEmpty
                    ? Image.network(ad.images.first, fit: BoxFit.cover)
                    : Container(
                    color: const Color(0xFFF0EDFF),
                    child: const Icon(Icons.image_outlined,
                        color: Colors.deepPurple, size: 28)),
              ),
            ),

            // Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ad.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87)),
                    const SizedBox(height: 6),
                    Text('₹${ad.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple)),
                    if (ad.postedAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Posted ${_formatDate(ad.postedAt!)}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade400),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Actions
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      color: Colors.blue, size: 20),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => PostAdScreen(editAd: ad))),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 20),
                  onPressed: () => _deleteAd(context, ad),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}