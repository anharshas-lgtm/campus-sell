import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/board_constants.dart';
import '../models/board_post_model.dart';
import '../services/board_service.dart';
import '../utils/cloudinary_url.dart';
import 'board_post_detail_screen.dart';

// ── Sort options ───────────────────────────────────────────────────────────────
enum _SortMode { time, deadline, priority }

class CampusBoardScreen extends StatefulWidget {
  const CampusBoardScreen({super.key});

  @override
  State<CampusBoardScreen> createState() => _CampusBoardScreenState();
}

class _CampusBoardScreenState extends State<CampusBoardScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _boardService = BoardService();
  String? _selectedCategory;
  _SortMode _sortMode = _SortMode.time;
  final _user = FirebaseAuth.instance.currentUser;

  // Cache campusId & stream so navigating tabs/filtering never triggers reload
  String? _cachedCampusId;
  String? _cachedCampusName;
  Stream<List<BoardPostModel>>? _postsStream;
  bool _loadingCampus = true;

  @override
  void initState() {
    super.initState();
    _loadCampusId();
  }

  Future<void> _loadCampusId() async {
    final user = _user;
    if (user == null) {
      if (mounted) setState(() => _loadingCampus = false);
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final d = snap.data();
      final cid = d?['campusId'] as String? ?? '';
      if (mounted) {
        setState(() {
          _cachedCampusId = cid;
          _cachedCampusName = d?['campus'] as String? ?? '';
          if (cid.isNotEmpty) {
            _postsStream = _boardService.fetchBoardPosts(cid);
          }
          _loadingCampus = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCampus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: _buildAppBar(),
      body: _loadingCampus
          ? const Center(child: CircularProgressIndicator())
          : (_cachedCampusId == null ||
                  _cachedCampusId!.isEmpty ||
                  _postsStream == null)
              ? const Center(child: Text('No campus found.'))
              : _BoardBody(
                  postsStream: _postsStream!,
                  selectedCategory: _selectedCategory,
                  sortMode: _sortMode,
                  onCategoryChanged: (cat) =>
                      setState(() => _selectedCategory = cat),
                  onSortChanged: (s) => setState(() => _sortMode = s),
                ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      titleSpacing: 16,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Campus Board',
            style: TextStyle(
              color: Colors.deepPurple,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          if (_cachedCampusName != null && _cachedCampusName!.isNotEmpty)
            Text(
              _cachedCampusName!,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Board body ─────────────────────────────────────────────────────────────────

class _BoardBody extends StatelessWidget {
  final Stream<List<BoardPostModel>> postsStream;
  final String? selectedCategory;
  final _SortMode sortMode;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<_SortMode> onSortChanged;

  const _BoardBody({
    required this.postsStream,
    required this.selectedCategory,
    required this.sortMode,
    required this.onCategoryChanged,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BoardPostModel>>(
      stream: postsStream,
      builder: (context, snapshot) {
        final allPosts = snapshot.data ?? [];

        // Count per category
        final counts = <String, int>{};
        for (final p in allPosts) {
          counts[p.category] = (counts[p.category] ?? 0) + 1;
        }

        // Filter
        final filtered = selectedCategory == null
            ? allPosts
            : allPosts
                .where((p) => p.category == selectedCategory)
                .toList();

        // Sort
        final sorted = List<BoardPostModel>.from(filtered);
        switch (sortMode) {
          case _SortMode.time:
            sorted.sort((a, b) {
              final at = a.postedAt ?? DateTime(2000);
              final bt = b.postedAt ?? DateTime(2000);
              return bt.compareTo(at);
            });
            break;
          case _SortMode.deadline:
            sorted.sort((a, b) {
              final ad = a.deadlineAt ?? a.eventDate;
              final bd = b.deadlineAt ?? b.eventDate;
              if (ad == null && bd == null) return 0;
              if (ad == null) return 1;
              if (bd == null) return -1;
              return ad.compareTo(bd);
            });
            break;
          case _SortMode.priority:
            const order = {'critical': 0, 'high': 1, 'medium': 2, 'low': 3};
            sorted.sort((a, b) => (order[a.urgencyLevel] ?? 3)
                .compareTo(order[b.urgencyLevel] ?? 3));
            break;
        }

        return Column(
          children: [
            _CategoryChipRow(
              counts: counts,
              selected: selectedCategory,
              onChanged: onCategoryChanged,
              sortMode: sortMode,
              onSortChanged: onSortChanged,
            ),
            Expanded(
              child: snapshot.connectionState == ConnectionState.waiting &&
                      allPosts.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : sorted.isEmpty
                      ? _EmptyState(category: selectedCategory)
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            // Scale tiles so 3 fit comfortably on screen at once
                            final tileHeight =
                                ((constraints.maxHeight - 38) / 3)
                                    .clamp(168.0, 240.0);
                            return ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                              itemCount: sorted.length,
                              itemBuilder: (_, i) => _PostTile(
                                post: sorted[i],
                                tileHeight: tileHeight,
                              ),
                            );
                          },
                        ),
            ),
          ],
        );
      },
    );
  }
}

// ── Category chip row + sort in the same line ─────────────────────────────────

class _CategoryChipRow extends StatelessWidget {
  final Map<String, int> counts;
  final String? selected;
  final ValueChanged<String?> onChanged;
  final _SortMode sortMode;
  final ValueChanged<_SortMode> onSortChanged;

  const _CategoryChipRow({
    required this.counts,
    required this.selected,
    required this.onChanged,
    required this.sortMode,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold(0, (a, b) => a + b);
    // Highest count to lowest
    final entries = kBoardCategories.entries.toList()
      ..sort((a, b) => (counts[b.key] ?? 0).compareTo(counts[a.key] ?? 0));

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 12, right: 6),
              child: Row(
                children: [
                  _Chip(
                    icon: Icons.apps_rounded,
                    label: 'All',
                    count: total,
                    selected: selected == null,
                    onTap: () => onChanged(null),
                  ),
                  const SizedBox(width: 6),
                  ...entries.map((e) {
                    final key = e.key;
                    final (_, label) = e.value;
                    final icon =
                        kBoardCategoryIcons[key] ?? Icons.label_outline;
                    final cnt = counts[key] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _Chip(
                        icon: icon,
                        label: label,
                        count: cnt,
                        selected: selected == key,
                        onTap: () => onChanged(selected == key ? null : key),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          // Sort button on the same line
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 10),
            child: PopupMenuButton<_SortMode>(
              onSelected: onSortChanged,
              initialValue: sortMode,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: Colors.deepPurple.withOpacity(0.25)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.sort_rounded,
                      size: 16, color: Colors.deepPurple),
                  const SizedBox(width: 4),
                  Text(
                    _sortLabel(sortMode),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.deepPurple,
                    ),
                  ),
                ]),
              ),
              itemBuilder: (_) => [
                _sortItem(_SortMode.time, 'Time'),
                _sortItem(_SortMode.deadline, 'Deadline'),
                _sortItem(_SortMode.priority, 'Priority'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _sortLabel(_SortMode m) {
    switch (m) {
      case _SortMode.time:
        return 'Time';
      case _SortMode.deadline:
        return 'Deadline';
      case _SortMode.priority:
        return 'Priority';
    }
  }

  PopupMenuItem<_SortMode> _sortItem(_SortMode m, String label) {
    return PopupMenuItem(
      value: m,
      child: Row(children: [
        if (sortMode == m)
          const Icon(Icons.check, size: 16, color: Colors.deepPurple)
        else
          const SizedBox(width: 16),
        const SizedBox(width: 8),
        Text(label),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.icon,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.deepPurple : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.deepPurple : Colors.grey.shade200,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.deepPurple.withOpacity(0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            icon,
            size: 15,
            color: selected ? Colors.white : kCategoryIconColor,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : Colors.black87,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withOpacity(0.3)
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : Colors.black54,
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

// ── Home screen tile (3-per-screen scale, summary, lower-left pills, lower-right time) ─

class _PostTile extends StatelessWidget {
  final BoardPostModel post;
  final double tileHeight;

  const _PostTile({
    required this.post,
    required this.tileHeight,
  });

  @override
  Widget build(BuildContext context) {
    final (_, catLabel) =
        kBoardCategories[post.category] ?? ('📋', 'General');
    final catColor =
        kBoardCategoryColors[post.category] ?? const Color(0xFF3949AB);
    final (urgencyColor, urgencyLabel) =
        kUrgencyLevels[post.urgencyLevel] ?? (Colors.grey, 'Low');
    final summaryText =
        post.summary.isNotEmpty ? post.summary : post.rawContent;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BoardPostDetailScreen(post: post)),
      ),
      child: Container(
        height: tileHeight,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Left enlarged thumbnail filling full side height ────────
              SizedBox(
                width: 122,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _Thumbnail(post: post),

                    // Category badge — top left corner over image, unique colour per category
                    Positioned(
                      top: 7,
                      left: 7,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: catColor.withOpacity(0.94),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.24),
                              blurRadius: 4,
                              offset: const Offset(0, 1.5),
                            ),
                          ],
                        ),
                        child: Text(
                          catLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Right majority portion for content ────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: Title + days-to-deadline in top-right corner
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              post.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                                height: 1.22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _DaysToDeadlineBadge(post: post),
                        ],
                      ),

                      const SizedBox(height: 5),

                      // Middle: Summary fitted dynamically to available space
                      Expanded(
                        child: summaryText.isEmpty
                            ? const SizedBox.shrink()
                            : LayoutBuilder(
                                builder: (context, c) {
                                  const fontSize = 12.5;
                                  const lineHeight = 1.35;
                                  final maxLines =
                                      (c.maxHeight / (fontSize * lineHeight))
                                          .floor();
                                  if (maxLines < 1) {
                                    return const SizedBox.shrink();
                                  }
                                  return Text(
                                    summaryText,
                                    maxLines: maxLines,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: fontSize,
                                      height: lineHeight,
                                      color: Colors.grey.shade600,
                                    ),
                                  );
                                },
                              ),
                      ),

                      const SizedBox(height: 6),

                      // Bottom row: Lower-left pills, Lower-right time
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: _MetaPills(
                              post: post,
                              urgencyColor: urgencyColor,
                              urgencyLabel: urgencyLabel,
                            ),
                          ),
                          if (post.postedAt != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Text(
                                timeago.format(
                                  post.postedAt!,
                                  locale: 'en_short',
                                ),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: Colors.grey.shade400,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Days-to-deadline badge (top-right corner of tile) ─────────────────────────

class _DaysToDeadlineBadge extends StatelessWidget {
  final BoardPostModel post;
  const _DaysToDeadlineBadge({required this.post});

  @override
  Widget build(BuildContext context) {
    final dl = post.deadlineAt;
    if (dl == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dlDay = DateTime(dl.year, dl.month, dl.day);
    final days = dlDay.difference(today).inDays;

    String text;
    Color color;
    if (days < 0) {
      text = 'Overdue';
      color = Colors.red.shade700;
    } else if (days == 0) {
      text = 'Today';
      color = Colors.deepOrange.shade600;
    } else if (days == 1) {
      text = '1d left';
      color = Colors.orange.shade700;
    } else {
      text = '${days}d left';
      color = kDeadlineColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ── Thumbnail ─────────────────────────────────────────────────────────────────

class _Thumbnail extends StatelessWidget {
  final BoardPostModel post;
  const _Thumbnail({required this.post});

  @override
  Widget build(BuildContext context) {
    final catIcon =
        kBoardCategoryIcons[post.category] ?? Icons.article_outlined;

    // 1. User-uploaded image (lower-res Cloudinary version)
    if (post.imageUrl != null && post.imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: CloudinaryUrl.thumb(post.imageUrl!),
        fit: BoxFit.cover,
        memCacheWidth: 450,
        fadeInDuration: const Duration(milliseconds: 150),
        placeholder: (_, __) => Container(color: const Color(0xFFF0EDFF)),
        errorWidget: (_, __, ___) => _iconThumb(catIcon),
      );
    }

    // 2. PDF / Word attachment icon
    final pdfAttach =
        post.attachments.where((a) => a.type == 'pdf').firstOrNull;
    final wordAttach =
        post.attachments.where((a) => a.type == 'word').firstOrNull;

    if (pdfAttach != null) {
      return _iconThumb(Icons.picture_as_pdf, iconColor: Colors.red.shade700);
    }
    if (wordAttach != null) {
      return _iconThumb(Icons.description, iconColor: Colors.blue.shade700);
    }

    // 3. Random category thumbnail (seeded by post.id so it stays consistent)
    final assetPath = pickCategoryThumbnail(post.category, seed: post.id);
    if (assetPath != null) {
      return Image.asset(
        assetPath,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _iconThumb(catIcon),
      );
    }

    return _iconThumb(catIcon);
  }

  Widget _iconThumb(IconData icon, {Color? iconColor}) {
    return Container(
      color: const Color(0xFFF0EDFF),
      child: Center(
        child: Icon(
          icon,
          size: 40,
          color: iconColor ?? kCategoryIconColor,
        ),
      ),
    );
  }
}

// ── Meta pills (essential fields only, consistent fixed colours) ──────────────

class _MetaPills extends StatelessWidget {
  final BoardPostModel post;
  final Color urgencyColor;
  final String urgencyLabel;

  const _MetaPills({
    required this.post,
    required this.urgencyColor,
    required this.urgencyLabel,
  });

  @override
  Widget build(BuildContext context) {
    final pills = <Widget>[];

    // Urgency pill
    pills.add(_pill(
      icon: Icons.priority_high_rounded,
      label: urgencyLabel,
      color: urgencyColor,
    ));

    // Venue pill (consistent teal)
    if (post.venue != null && post.venue!.isNotEmpty) {
      pills.add(_pill(
        icon: Icons.place_outlined,
        label: post.venue!,
        color: kVenueColor,
      ));
    }

    // Event Date pill (consistent blue)
    if (post.eventDate != null) {
      pills.add(_pill(
        icon: Icons.event_outlined,
        label: _fmtDate(post.eventDate!),
        color: kEventColor,
      ));
    }

    // Deadline pill (consistent amber)
    if (post.deadlineAt != null) {
      pills.add(_pill(
        icon: Icons.alarm_outlined,
        label: 'Due ${_fmtDate(post.deadlineAt!)}',
        color: kDeadlineColor,
      ));
    }

    return Wrap(
      spacing: 5,
      runSpacing: 4,
      children: pills,
    );
  }

  Widget _pill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 155),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10.5, color: color),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String? category;
  const _EmptyState({this.category});

  @override
  Widget build(BuildContext context) {
    final (_, label) = category != null
        ? kBoardCategories[category] ?? ('📋', 'this category')
        : ('📋', 'campus');
    final icon = category != null
        ? kBoardCategoryIcons[category] ?? Icons.campaign_outlined
        : Icons.campaign_outlined;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: kCategoryIconColor.withOpacity(0.45)),
          const SizedBox(height: 16),
          Text(
            'No posts in $label yet',
            style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 6),
          Text(
            'Be the first to post!',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}
