import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/board_constants.dart';
import '../models/board_post_model.dart';
import '../services/board_service.dart';
import '../services/admin_service.dart';
import '../utils/cloudinary_url.dart';
import 'create_board_post_screen.dart';

class BoardPostDetailScreen extends StatefulWidget {
  final BoardPostModel post;
  const BoardPostDetailScreen({super.key, required this.post});

  @override
  State<BoardPostDetailScreen> createState() =>
      _BoardPostDetailScreenState();
}

class _BoardPostDetailScreenState extends State<BoardPostDetailScreen> {
  late BoardPostModel _post;
  final _boardService = BoardService();
  final _currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  final Map<String, bool> _downloadingFile = {};

  bool get _isOwner => _post.postedBy == _currentUid;
  bool get _isAdmin => AdminService.isAdmin(_currentUid);
  bool get _canEdit => _isOwner || _isAdmin;
  bool get _canDelete => _isAdmin;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
  }

  // ── URL launchers ──────────────────────────────────────────────────────────

  Future<void> _launch(String url) async {
    var target = url.trim();
    if (!target.startsWith('http://') && !target.startsWith('https://')) {
      target = 'https://$target';
    }
    final uri = Uri.parse(target);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _snack('Could not open: $url');
    }
  }

  Future<void> _call(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final uri = Uri.parse('tel:$cleaned');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _snack('Could not open dialer');
    }
  }

  Future<void> _whatsapp(String phone) async {
    String cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (!cleaned.startsWith('+')) cleaned = '+91$cleaned';
    final uri = Uri.parse('https://wa.me/$cleaned');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _snack('WhatsApp not installed');
    }
  }

  Future<void> _mail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (!await launchUrl(uri)) {
      _snack('Could not open email app');
    }
  }

  Future<void> _downloadAndOpen(BoardAttachment att) async {
    setState(() => _downloadingFile[att.name] = true);
    try {
      final res = await http.get(Uri.parse(att.url));
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${att.name}');
      await file.writeAsBytes(res.bodyBytes);
      await OpenFilex.open(file.path);
    } catch (e) {
      _snack('Could not open file: $e');
    } finally {
      if (mounted) setState(() => _downloadingFile[att.name] = false);
    }
  }

  // ── Admin / owner actions ─────────────────────────────────────────────────

  Future<void> _editPost() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateBoardPostScreen(
          campusId: _post.campusId,
          existingPost: _post,
        ),
      ),
    );
    if (result == true && mounted) Navigator.pop(context);
  }

  Future<void> _deletePost() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Post'),
        content:
            const Text('This will permanently delete the post. Are you sure?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _boardService.deletePost(_post.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack('Delete failed: $e');
    }
  }

  Future<void> _reportPost() async {
    final reasons = [
      'Spam',
      'Misinformation',
      'Inappropriate content',
      'Duplicate post',
      'Other',
    ];
    String? selected;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setS) {
        return AlertDialog(
          title: const Text('Report Post'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: reasons
                .map((r) => RadioListTile<String>(
                      title: Text(r),
                      value: r,
                      groupValue: selected,
                      onChanged: (v) => setS(() => selected = v),
                    ))
                .toList(),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            TextButton(
              onPressed: selected == null ? null : () => Navigator.pop(ctx, true),
              child: const Text('Report'),
            ),
          ],
        );
      }),
    );
    if (confirm != true || selected == null || !mounted) return;
    try {
      await _boardService.reportPost(
        postId: _post.id,
        reportedBy: _currentUid,
        reason: selected!,
      );
      _snack('Post reported. Thank you.');
    } catch (e) {
      _snack('Report failed: $e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3)),
    );
  }

  String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _deadlineRemaining(DateTime dl) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dlDay = DateTime(dl.year, dl.month, dl.day);
    final days = dlDay.difference(today).inDays;
    if (days < 0) return 'Overdue (${days.abs()}d ago)';
    if (days == 0) return 'Due Today';
    if (days == 1) return '1 day left';
    return '$days days left';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final (_, catLabel) =
        kBoardCategories[_post.category] ?? ('📋', 'General');
    final catIcon =
        kBoardCategoryIcons[_post.category] ?? Icons.article_outlined;
    final (urgencyColor, urgencyLabel) =
        kUrgencyLevels[_post.urgencyLevel] ?? (Colors.grey, 'Low');
    final nonImageAttachments =
        _post.attachments.where((a) => a.type != 'image').toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: CustomScrollView(
        slivers: [
          // ── App bar with lower-res thumbnail (tap to load HD) ────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            actions: [
              if (_canEdit)
                IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: _editPost),
              IconButton(
                  icon: const Icon(Icons.flag_outlined),
                  onPressed: _reportPost),
              if (_canDelete)
                IconButton(
                    icon: const Icon(Icons.delete_outlined,
                        color: Colors.redAccent),
                    onPressed: _deletePost),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _PostHeroImage(post: _post),
            ),
          ),

          // ── Separate tiles for every field ───────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Title tile
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _post.title,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 2 & 3. Category tile + Urgency tile
                  Row(
                    children: [
                      Expanded(
                        child: _FieldTile(
                          icon: catIcon,
                          title: 'Category',
                          color: kCategoryIconColor,
                          child: Text(
                            catLabel,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _FieldTile(
                          icon: Icons.priority_high_rounded,
                          title: 'Urgency',
                          color: urgencyColor,
                          child: Text(
                            urgencyLabel,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: urgencyColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // 4. Event Date (separate tile)
                  if (_post.eventDate != null) ...[
                    const SizedBox(height: 8),
                    _FieldTile(
                      icon: Icons.event_outlined,
                      title: 'Event Date',
                      color: kEventColor,
                      borderColor: kEventColor.withOpacity(0.25),
                      child: Text(
                        _fmtDate(_post.eventDate!),
                        style: const TextStyle(
                          color: kEventColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],

                  // 5. Deadline (separate tile)
                  if (_post.deadlineAt != null) ...[
                    const SizedBox(height: 8),
                    _FieldTile(
                      icon: Icons.alarm_outlined,
                      title: 'Deadline',
                      color: kDeadlineColor,
                      borderColor: kDeadlineColor.withOpacity(0.3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _fmtDate(_post.deadlineAt!),
                            style: const TextStyle(
                              color: kDeadlineColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: kDeadlineColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _deadlineRemaining(_post.deadlineAt!),
                              style: const TextStyle(
                                color: kDeadlineColor,
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // 6. Venue (separate tile)
                  if (_post.venue != null && _post.venue!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _FieldTile(
                      icon: Icons.place_outlined,
                      title: 'Venue',
                      color: kVenueColor,
                      borderColor: kVenueColor.withOpacity(0.25),
                      child: Text(
                        _post.venue!,
                        style: const TextStyle(
                          color: kVenueColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],

                  // 7. Summary (separate tile)
                  if (_post.summary.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _FieldTile(
                      icon: Icons.summarize_outlined,
                      title: 'Summary',
                      color: Colors.indigo,
                      child: Text(
                        _post.summary,
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ),
                  ],

                  // 8. Details (separate tile)
                  if (_post.details.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _FieldTile(
                      icon: Icons.info_outline,
                      title: 'Details',
                      color: Colors.blueGrey,
                      child: Text(
                        _post.details,
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ),
                  ],

                  // Fallback rawContent if both summary & details empty
                  if (_post.summary.isEmpty &&
                      _post.details.isEmpty &&
                      _post.rawContent.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _FieldTile(
                      icon: Icons.article_outlined,
                      title: 'Details',
                      color: Colors.blueGrey,
                      child: Text(
                        _post.rawContent,
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ),
                  ],

                  // 9. Contact (separate tile)
                  if (_post.contactName != null &&
                      _post.contactName!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _FieldTile(
                      icon: Icons.person_outline,
                      title: 'Contact',
                      color: kOrgColor,
                      child: Text(
                        _post.contactName!,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],

                  // 10. Phone & WhatsApp (separate tile)
                  if (_post.contactPhone != null &&
                      _post.contactPhone!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _PhoneTile(
                      phone: _post.contactPhone!,
                      onCall: _call,
                      onWhatsApp: _whatsapp,
                    ),
                  ],

                  // 11. Email (separate tile)
                  if (_post.contactEmail != null &&
                      _post.contactEmail!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _EmailTile(email: _post.contactEmail!, onMail: _mail),
                  ],

                  // 12. Links (separate tile)
                  if (_post.links.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _LinksTile(links: _post.links, onLaunch: _launch),
                  ],

                  // 13. Non-image Attachments (PDF / Word download only)
                  if (nonImageAttachments.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _AttachmentsTile(
                      attachments: nonImageAttachments,
                      downloadingFile: _downloadingFile,
                      onDownload: _downloadAndOpen,
                    ),
                  ],

                  // 14. Poster info card
                  const SizedBox(height: 10),
                  _PosterCard(post: _post),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero image (shows lower-res Cloudinary thumb, asks to load high-res on tap) ─

class _PostHeroImage extends StatelessWidget {
  final BoardPostModel post;
  const _PostHeroImage({required this.post});

  @override
  Widget build(BuildContext context) {
    final catIcon =
        kBoardCategoryIcons[post.category] ?? Icons.article_outlined;

    if (post.imageUrl != null && post.imageUrl!.isNotEmpty) {
      return GestureDetector(
        onTap: () => _askAndOpenHighRes(context, post.imageUrl!),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: CloudinaryUrl.thumb(post.imageUrl!),
              fit: BoxFit.cover,
              width: double.infinity,
              placeholder: (_, __) => Container(color: const Color(0xFFEDE7F6)),
              errorWidget: (_, __, ___) => _fallback(catIcon),
            ),
            Positioned(
              bottom: 10,
              right: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.zoom_out_map, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Tap for full image',
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final assetPath = pickCategoryThumbnail(post.category, seed: post.id);
    if (assetPath != null) {
      return Image.asset(
        assetPath,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, __, ___) => _fallback(catIcon),
      );
    }

    return _fallback(catIcon);
  }

  Widget _fallback(IconData icon) => Container(
        color: const Color(0xFFEDE7F6),
        child: Center(
          child: Icon(icon, size: 64, color: kCategoryIconColor),
        ),
      );

  Future<void> _askAndOpenHighRes(
      BuildContext context, String imageUrl) async {
    final loadHd = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Load Full Image?'),
        content: const Text(
          'Currently showing the compressed thumbnail. Load the higher resolution version?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Load High-Res'),
          ),
        ],
      ),
    );

    if (loadHd != true || !context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _FullScreenImage(imageUrl: CloudinaryUrl.large(imageUrl)),
      ),
    );
  }
}

// ── Full screen image viewer (no download button) ─────────────────────────────

class _FullScreenImage extends StatelessWidget {
  final String imageUrl;
  const _FullScreenImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (_, __) =>
                const Center(child: CircularProgressIndicator()),
            errorWidget: (_, __, ___) => const Icon(
              Icons.broken_image,
              color: Colors.white,
              size: 60,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Poster card ───────────────────────────────────────────────────────────────

class _PosterCard extends StatelessWidget {
  final BoardPostModel post;
  const _PosterCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final sub = [
      post.postedByProgram,
      post.postedByDepartment,
      post.postedByYear,
    ].where((s) => s != null && s.isNotEmpty).join(' • ');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'POSTED BY',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.deepPurple.shade100,
                child: Text(
                  post.postedByName.isNotEmpty
                      ? post.postedByName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.postedByName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    if (sub.isNotEmpty)
                      Text(
                        sub,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54),
                      ),
                    if (post.postedAt != null)
                      Text(
                        timeago.format(post.postedAt!),
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black38),
                      ),
                  ],
                ),
              ),
              if (post.editedAt != null)
                Text('edited',
                    style:
                        TextStyle(fontSize: 10, color: Colors.grey.shade400)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Generic field tile ────────────────────────────────────────────────────────

class _FieldTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final Color? borderColor;
  final Widget child;

  const _FieldTile({
    required this.icon,
    required this.title,
    required this.color,
    this.borderColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: borderColor != null ? Border.all(color: borderColor!) : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ]),
        const SizedBox(height: 6),
        child,
      ]),
    );
  }
}

// ── Phone & WhatsApp tile ─────────────────────────────────────────────────────

class _PhoneTile extends StatelessWidget {
  final String phone;
  final Future<void> Function(String) onCall;
  final Future<void> Function(String) onWhatsApp;

  const _PhoneTile({
    required this.phone,
    required this.onCall,
    required this.onWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kPhoneColor.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.phone_outlined, color: kPhoneColor, size: 15),
            SizedBox(width: 6),
            Text(
              'PHONE & WHATSAPP',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: kPhoneColor,
                letterSpacing: 0.5,
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: Text(
                phone,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14.5,
                  color: kPhoneColor,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => onCall(phone),
              icon: const Icon(Icons.call, size: 16, color: kPhoneColor),
              label: const Text('Call',
                  style: TextStyle(color: kPhoneColor, fontSize: 13)),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
            ),
            const SizedBox(width: 4),
            TextButton.icon(
              onPressed: () => onWhatsApp(phone),
              icon: const Icon(Icons.chat_outlined,
                  size: 16, color: Color(0xFF25D366)),
              label: const Text('WhatsApp',
                  style: TextStyle(color: Color(0xFF25D366), fontSize: 13)),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
            ),
          ]),
        ],
      ),
    );
  }
}

// ── Email tile ────────────────────────────────────────────────────────────────

class _EmailTile extends StatelessWidget {
  final String email;
  final Future<void> Function(String) onMail;
  const _EmailTile({required this.email, required this.onMail});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onMail(email),
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: email));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email copied'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: _FieldTile(
        icon: Icons.email_outlined,
        title: 'Email',
        color: kEmailColor,
        borderColor: kEmailColor.withOpacity(0.25),
        child: Text(
          email,
          style: const TextStyle(
            color: kEmailColor,
            fontWeight: FontWeight.w600,
            fontSize: 14,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}

// ── Links tile ────────────────────────────────────────────────────────────────

class _LinksTile extends StatelessWidget {
  final List<BoardLink> links;
  final Future<void> Function(String) onLaunch;
  const _LinksTile({required this.links, required this.onLaunch});

  @override
  Widget build(BuildContext context) {
    return _FieldTile(
      icon: Icons.link,
      title: 'Links',
      color: kLinkColor,
      borderColor: kLinkColor.withOpacity(0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: links
            .map((l) => GestureDetector(
                  onTap: () => onLaunch(l.url),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      const Icon(Icons.open_in_new,
                          size: 14, color: kLinkColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          (l.label != null && l.label!.isNotEmpty)
                              ? l.label!
                              : l.url,
                          style: const TextStyle(
                            color: kLinkColor,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ]),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

// ── Attachments tile (non-image documents only) ───────────────────────────────

class _AttachmentsTile extends StatelessWidget {
  final List<BoardAttachment> attachments;
  final Map<String, bool> downloadingFile;
  final Future<void> Function(BoardAttachment) onDownload;

  const _AttachmentsTile({
    required this.attachments,
    required this.downloadingFile,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return _FieldTile(
      icon: Icons.attach_file,
      title: 'Attachments',
      color: kFileColor,
      child: Column(
        children: attachments.map((att) {
          final loading = downloadingFile[att.name] ?? false;
          final isPdf = att.type == 'pdf';
          final icon = isPdf ? Icons.picture_as_pdf : Icons.description;
          final iconColor =
              isPdf ? Colors.red.shade700 : Colors.blue.shade700;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(icon, color: iconColor),
            title: Text(att.name, style: const TextStyle(fontSize: 13)),
            subtitle: Text('${att.sizeKb} KB',
                style: const TextStyle(fontSize: 11)),
            trailing: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : IconButton(
                    icon: const Icon(Icons.download_outlined,
                        color: Colors.deepPurple),
                    onPressed: () => onDownload(att),
                  ),
          );
        }).toList(),
      ),
    );
  }
}
