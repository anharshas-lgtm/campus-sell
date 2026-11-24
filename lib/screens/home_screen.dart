import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/ad_model.dart';
import '../services/ad_service.dart';
import '../utils/cloudinary_url.dart';
import 'ad_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _searchOpen = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openSearch() => setState(() => _searchOpen = true);

  void _closeSearch() {
    _searchController.clear();
    setState(() {
      _searchOpen = false;
      _searchQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        titleSpacing: 16,
        title: _searchOpen
            ? TextField(
          controller: _searchController,
          autofocus: true,
          onChanged: (val) => setState(
                  () => _searchQuery = val.toLowerCase().trim()),
          style: const TextStyle(
              fontSize: 15, color: Colors.black87),
          decoration: InputDecoration(
            hintText: 'Search ads...',
            hintStyle: TextStyle(
                color: Colors.grey.shade400, fontSize: 15),
            border: InputBorder.none,
          ),
        )
            : StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user?.uid)
              .snapshots(),
          builder: (context, snapshot) {
            final data =
            snapshot.data?.data() as Map<String, dynamic>?;
            final campus = data?['campus'] ?? '';
            final district = data?['district'] ?? '';
            final label = district.isNotEmpty
                ? '$campus, $district'
                : campus;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'CampusSell',
                  style: TextStyle(
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                if (label.isNotEmpty)
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            );
          },
        ),
        toolbarHeight: 58,
        actions: [
          _searchOpen
              ? IconButton(
            onPressed: _closeSearch,
            icon: const Icon(Icons.close,
                color: Colors.black87),
          )
              : IconButton(
            onPressed: _openSearch,
            icon: const Icon(Icons.search,
                color: Colors.black87),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final userData =
          userSnapshot.data?.data() as Map<String, dynamic>?;
          final campusId = userData?['campusId'] ?? '';

          if (campusId.isEmpty) {
            return const Center(child: Text('No campus found.'));
          }

          return _AdsList(
            campusId: campusId,
            searchQuery: _searchQuery,
          );
        },
      ),
    );
  }
}

class _AdsList extends StatelessWidget {
  final String campusId;
  final String searchQuery;
  const _AdsList(
      {required this.campusId, required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdModel>>(
      stream: AdService().fetchCampusAds(campusId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final allAds = snapshot.data ?? [];
        final ads = searchQuery.isEmpty
            ? allAds
            : allAds.where((ad) {
          return ad.title
              .toLowerCase()
              .contains(searchQuery) ||
              ad.description
                  .toLowerCase()
                  .contains(searchQuery) ||
              ad.price.toString().contains(searchQuery);
        }).toList();

        if (allAds.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.storefront_outlined,
                    size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 14),
                Text('No ads yet',
                    style: TextStyle(
                        fontSize: 17,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                Text('Be the first to post something!',
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade400)),
              ],
            ),
          );
        }

        if (ads.isEmpty && searchQuery.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off,
                    size: 56, color: Colors.grey.shade300),
                const SizedBox(height: 14),
                Text('No results for "$searchQuery"',
                    style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade500)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: Colors.deepPurple,
          onRefresh: () async {},
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 0.78,
            ),
            itemCount: ads.length,
            itemBuilder: (context, index) =>
                _AdCard(ad: ads[index]),
          ),
        );
      },
    );
  }
}

class _AdCard extends StatelessWidget {
  final AdModel ad;
  const _AdCard({required this.ad});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AdDetailScreen(ad: ad)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: Colors.deepPurple.withOpacity(0.25),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalHeight = constraints.maxHeight;
              // ── 65% image, 35% text ──────────────────────────────
              final imageHeight = totalHeight * 0.65;
              final textHeight = totalHeight * 0.35;

              return Column(
                children: [
                  // ── Image section with price badge overlay ────────
                  SizedBox(
                    height: imageHeight,
                    width: double.infinity,
                    child: Stack(
                      children: [
                        // Image fills full area (small Cloudinary thumbnail,
                        // cached on disk + memory)
                        Positioned.fill(
                          child: ad.images.isNotEmpty
                              ? CachedNetworkImage(
                            imageUrl: CloudinaryUrl.thumb(
                                ad.images.first),
                            fit: BoxFit.cover,
                            memCacheWidth: 500,
                            fadeInDuration:
                            const Duration(milliseconds: 150),
                            placeholder: (_, __) => Container(
                                color: const Color(0xFFF0EDFF)),
                            errorWidget: (_, __, ___) =>
                                _placeholder(),
                          )
                              : _placeholder(),
                        ),

                        // ── Price badge — top left corner ─────────
                        Positioned(
                          top: 7,
                          left: 7,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple,
                              borderRadius:
                              BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              '₹${ad.price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Text section — full 35% for title + time ─────
                  SizedBox(
                    height: textHeight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [
                          // Title — takes all available space
                          Expanded(
                            child: Text(
                              ad.title,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.1,
                                color: Colors.black87,
                                height: 1.3,
                              ),
                            ),
                          ),

                          // Time — bottom
                          Text(
                            ad.postedAt != null
                                ? timeago.format(ad.postedAt!,
                                locale: 'en_short')
                                : '',
                            style: TextStyle(
                              fontSize: 9.5,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFFF0EDFF),
      child: const Center(
        child: Icon(Icons.image_outlined,
            size: 34, color: Colors.deepPurple),
      ),
    );
  }
}