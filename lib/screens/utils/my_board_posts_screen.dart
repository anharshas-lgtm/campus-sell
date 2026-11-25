import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../constants/board_constants.dart';
import '../../models/board_post_model.dart';
import '../../services/admin_service.dart';
import '../../services/board_service.dart';
import '../../utils/cloudinary_url.dart';
import '../board_post_detail_screen.dart';
import '../create_board_post_screen.dart';

class MyBoardPostsScreen extends StatelessWidget {
  const MyBoardPostsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in')),
      );
    }

    final boardService = BoardService();
    final isAdmin = AdminService.isAdmin(user.uid);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: const Text(
          'My Board Posts',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ),
      body: StreamBuilder<List<BoardPostModel>>(
        stream: boardService.fetchUserPosts(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final posts = snapshot.data ?? [];
          if (posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.campaign_outlined,
                      size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    "You haven't posted on the board yet",
                    style:
                        TextStyle(color: Colors.grey.shade400, fontSize: 15),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: posts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _MyBoardPostCard(
              post: posts[i],
              isAdmin: isAdmin,
              boardService: boardService,
            ),
          );
        },
      ),
    );
  }
}

class _MyBoardPostCard extends StatelessWidget {
  final BoardPostModel post;
  final bool isAdmin;
  final BoardService boardService;

  const _MyBoardPostCard({
    required this.post,
    required this.isAdmin,
    required this.boardService,
  });

  Future<void> _confirmRemove(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isAdmin ? 'Delete Post' : 'Remove Post'),
        content: Text('Remove "${post.title}" from Campus Board?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              isAdmin ? 'Delete' : 'Remove',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      if (isAdmin) {
        await boardService.deletePost(post.id);
      } else {
        await boardService.deactivatePost(post.id);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post removed.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final (catEmoji, catLabel) =
        kBoardCategories[post.category] ?? ('🌐', 'General');

    return Dismissible(
      key: Key('my_board_post_${post.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _confirmRemove(context);
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BoardPostDetailScreen(post: post),
          ),
        ),
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
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(12)),
                child: SizedBox(
                  width: 84,
                  height: 92,
                  child: post.imageUrl != null && post.imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: CloudinaryUrl.thumb(post.imageUrl!),
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: const Color(0xFFF0EDFF)),
                          errorWidget: (_, __, ___) =>
                              _thumbFallback(),
                        )
                      : _thumbFallback(),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$catEmoji $catLabel',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        post.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      if (post.postedAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          timeago.format(post.postedAt!),
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade400),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        color: Colors.blue, size: 20),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateBoardPostScreen(
                          campusId: post.campusId,
                          existingPost: post,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.red, size: 20),
                    onPressed: () => _confirmRemove(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbFallback() {
    final asset = pickCategoryThumbnail(post.category, seed: post.id);
    if (asset != null) {
      return Image.asset(
        asset,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _iconBox(),
      );
    }
    return _iconBox();
  }

  Widget _iconBox() {
    final icon = kBoardCategoryIcons[post.category] ?? Icons.article_outlined;
    return Container(
      color: const Color(0xFFF0EDFF),
      child: Center(
        child: Icon(icon, size: 28, color: kCategoryIconColor),
      ),
    );
  }
}
