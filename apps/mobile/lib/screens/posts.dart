import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/screen_scaffold.dart';

/// POSTS — free-form posts in the Social tab.
///
/// Distinct from the Activity feed in feed.dart: that feed is generated from
/// recorded Activities, this one is anything an athlete wants to say —
/// text, an optional photo, public or followers-only.
class PostsFeedScreen extends StatefulWidget {
  const PostsFeedScreen({super.key});

  @override
  State<PostsFeedScreen> createState() => _PostsFeedScreenState();
}

class _PostsFeedScreenState extends State<PostsFeedScreen> {
  List<PostItem>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await context.read<VyraApi>().postsFeed();
      if (mounted) setState(() { _items = items; _error = null; });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _toggleKudos(PostItem item) async {
    try {
      await context.read<VyraApi>().togglePostKudos(item.id);
      await _load();
    } on ApiException catch (_) {
      // A failed kudos tap is not worth interrupting the feed for.
    }
  }

  Future<void> _openComposer() async {
    final created = await pushScreen<bool>(context, 'New post', const CreatePostScreen());
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _load,
            color: VColor.accent,
            backgroundColor: VColor.surface,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(VSpace.base, VSpace.base, VSpace.base, VSpace.xxxl),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Posts', style: Theme.of(context).textTheme.headlineMedium),
                    IconButton(
                      icon: const Icon(Icons.person_outline, color: VColor.text),
                      tooltip: 'My posts',
                      onPressed: () => pushScreen(context, 'My Posts', const MyPostsScreen()),
                    ),
                  ],
                ),
                const SizedBox(height: VSpace.base),

                if (_error != null) VErrorView(message: _error!, onRetry: _load),
                if (_error == null && _items == null) const VLoading(label: 'Loading posts'),

                if (_items != null && _items!.isEmpty)
                  VEmptyState(
                    title: 'No posts yet',
                    body: 'Share how training is going — a photo, a milestone, or just how you feel.',
                    action: FilledButton(onPressed: _openComposer, child: const Text('Write a post')),
                  ),

                for (final item in _items ?? []) ...[
                  const SizedBox(height: VSpace.base),
                  _PostCard(
                    item: item,
                    onKudos: () => _toggleKudos(item),
                    onTap: () => pushScreen(context, 'Post', PostDetailScreen(post: item)),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            right: VSpace.base,
            bottom: VSpace.base,
            child: FloatingActionButton(
              backgroundColor: VColor.accent,
              foregroundColor: VColor.textOnAccent,
              onPressed: _openComposer,
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Post card — reused by the feed and the post detail screen
// -----------------------------------------------------------------------------

class _PostCard extends StatelessWidget {
  const _PostCard({required this.item, required this.onKudos, this.onTap, this.trailing});

  final PostItem item;
  final VoidCallback onKudos;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final card = VCard(
      tone: CardTone.raised,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(VSpace.base, VSpace.base, VSpace.base, VSpace.sm),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: VColor.accentGlow,
                  child: Text(
                    item.authorName.isNotEmpty ? item.authorName[0].toUpperCase() : '?',
                    style: const TextStyle(color: VColor.accent, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: VSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.authorName, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Row(
                        children: [
                          Text('@${item.authorHandle}',
                              style: const TextStyle(color: VColor.textLow, fontSize: 12)),
                          if (item.isFollowersOnly) ...[
                            const SizedBox(width: VSpace.sm),
                            const Icon(Icons.lock_outline, size: 12, color: VColor.textLow),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: VSpace.base),
            child: Text(item.body, style: const TextStyle(color: VColor.text, fontSize: 14.5, height: 1.4)),
          ),
          if (item.imageUrl != null) ...[
            const SizedBox(height: VSpace.base),
            ClipRRect(
              child: Image.network(
                item.imageUrl!,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 120,
                  color: VColor.surface,
                  alignment: Alignment.center,
                  child: const Text('Image failed to load',
                      style: TextStyle(color: VColor.textLow, fontSize: 12)),
                ),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.all(VSpace.base),
            child: Row(
              children: [
                InkWell(
                  onTap: onKudos,
                  borderRadius: BorderRadius.circular(VRadius.pill),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: VSpace.sm, vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          item.kudosGiven ? Icons.bolt : Icons.bolt_outlined,
                          size: 18,
                          color: item.kudosGiven ? VColor.accent : VColor.textMid,
                        ),
                        const SizedBox(width: 4),
                        Text('Kudos', style: TextStyle(
                            color: item.kudosGiven ? VColor.accent : VColor.textMid, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: VSpace.lg),
                const Icon(Icons.mode_comment_outlined, size: 16, color: VColor.textMid),
                const SizedBox(width: 4),
                Text('${item.commentCount}',
                    style: const TextStyle(color: VColor.textMid, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return InkWell(
      borderRadius: BorderRadius.circular(VRadius.lg),
      onTap: onTap,
      child: card,
    );
  }
}

// -----------------------------------------------------------------------------
// Create / edit post
// -----------------------------------------------------------------------------

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key, this.editing});

  /// When set, the screen edits this post (PATCH) instead of creating a new
  /// one (POST). Pushed via pushScreen, so the AppBar title is set by the
  /// caller — pass 'Edit post' when editing.
  final PostItem? editing;

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  late final _body = TextEditingController(text: widget.editing?.body ?? '');
  late final _imageUrl = TextEditingController(text: widget.editing?.imageUrl ?? '');
  late String _visibility = widget.editing?.visibility ?? 'public';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _body.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _body.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Write something first.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final api = context.read<VyraApi>();
      if (widget.editing != null) {
        await api.updatePost(widget.editing!.id, body: text, visibility: _visibility);
      } else {
        await api.createPost(
          body: text,
          imageUrl: _imageUrl.text.trim().isEmpty ? null : _imageUrl.text.trim(),
          visibility: _visibility,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.editing != null;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(VSpace.base, VSpace.base, VSpace.base, VSpace.xxxl),
        children: [
          if (_error != null) ...[
            VErrorView(message: _error!),
            const SizedBox(height: VSpace.base),
          ],
          const VLabel('What\'s on your mind'),
          const SizedBox(height: VSpace.xs),
          TextField(
            controller: _body,
            maxLines: 6,
            style: const TextStyle(color: VColor.text),
            decoration: const InputDecoration(hintText: 'Share how training is going...'),
          ),
          const SizedBox(height: VSpace.base),
          if (!isEditing) ...[
            // Image upload isn't built yet — a URL field is the stand-in until
            // real upload support lands.
            const VLabel('Image URL (optional)'),
            const SizedBox(height: VSpace.xs),
            TextField(
              controller: _imageUrl,
              style: const TextStyle(color: VColor.text),
              decoration: const InputDecoration(hintText: 'https://...'),
            ),
            const SizedBox(height: VSpace.base),
          ],
          const VLabel('Who can see this'),
          const SizedBox(height: VSpace.sm),
          Wrap(
            spacing: VSpace.sm,
            children: [
              ChoiceChip(
                label: const Text('Public'),
                selected: _visibility == 'public',
                onSelected: (_) => setState(() => _visibility = 'public'),
                selectedColor: VColor.accentGlow,
                labelStyle: TextStyle(
                    color: _visibility == 'public' ? VColor.accent : VColor.textMid, fontSize: 13),
                backgroundColor: VColor.surface,
                side: const BorderSide(color: VColor.line),
              ),
              ChoiceChip(
                label: const Text('Followers'),
                selected: _visibility == 'followers',
                onSelected: (_) => setState(() => _visibility = 'followers'),
                selectedColor: VColor.accentGlow,
                labelStyle: TextStyle(
                    color: _visibility == 'followers' ? VColor.accent : VColor.textMid, fontSize: 13),
                backgroundColor: VColor.surface,
                side: const BorderSide(color: VColor.line),
              ),
            ],
          ),
          const SizedBox(height: VSpace.xl),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: VColor.textOnAccent))
                : Text(isEditing ? 'Save changes' : 'Post'),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Post detail — comments
// -----------------------------------------------------------------------------

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key, required this.post});
  final PostItem post;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late PostItem _post = widget.post;
  List<PostComment>? _comments;
  String? _error;
  final _commentCtrl = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final comments = await context.read<VyraApi>().postComments(_post.id);
      if (mounted) setState(() { _comments = comments; _error = null; });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _toggleKudos() async {
    try {
      final given = await context.read<VyraApi>().togglePostKudos(_post.id);
      if (mounted) {
        setState(() {
          _post = PostItem(
            id: _post.id, userId: _post.userId, body: _post.body, imageUrl: _post.imageUrl,
            visibility: _post.visibility, authorHandle: _post.authorHandle, authorName: _post.authorName,
            kudosGiven: given, kudosCount: _post.kudosCount, commentCount: _post.commentCount,
            createdAt: _post.createdAt,
          );
        });
      }
    } on ApiException catch (_) {
      // Not worth interrupting the screen for.
    }
  }

  Future<void> _send() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await context.read<VyraApi>().addPostComment(_post.id, text);
      _commentCtrl.clear();
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(VSpace.base),
              children: [
                _PostCard(item: _post, onKudos: _toggleKudos),
                const SizedBox(height: VSpace.lg),
                const VSectionHeader('Comments'),
                if (_error != null) VErrorView(message: _error!, onRetry: _load),
                if (_error == null && _comments == null) const VLoading(),
                if (_comments != null && _comments!.isEmpty)
                  const VEmptyState(title: 'No comments yet', body: 'Be the first to say something.'),
                for (final c in _comments ?? [])
                  Padding(
                    padding: const EdgeInsets.only(bottom: VSpace.sm),
                    child: VCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('@${c.authorHandle}',
                              style: const TextStyle(
                                  color: VColor.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(c.body, style: const TextStyle(color: VColor.text, fontSize: 13.5)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(VSpace.base, VSpace.sm, VSpace.base, VSpace.sm),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentCtrl,
                      style: const TextStyle(color: VColor.text),
                      decoration: const InputDecoration(hintText: 'Add a comment...'),
                    ),
                  ),
                  const SizedBox(width: VSpace.sm),
                  IconButton(
                    icon: _sending
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: VColor.accent))
                        : const Icon(Icons.send, color: VColor.accent),
                    onPressed: _sending ? null : _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// My posts — edit / delete
// -----------------------------------------------------------------------------

class MyPostsScreen extends StatefulWidget {
  const MyPostsScreen({super.key});

  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen> {
  List<PostItem>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await context.read<VyraApi>().myPosts();
      if (mounted) setState(() { _items = items; _error = null; });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _edit(PostItem post) async {
    final saved = await pushScreen<bool>(context, 'Edit post', CreatePostScreen(editing: post));
    if (saved == true) _load();
  }

  Future<void> _delete(PostItem post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VColor.surface,
        title: const Text('Delete post?', style: TextStyle(color: VColor.text)),
        content: const Text('This can\'t be undone.', style: TextStyle(color: VColor.textMid)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: VColor.crit)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await context.read<VyraApi>().deletePost(post.id);
      _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        color: VColor.accent,
        backgroundColor: VColor.surface,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(VSpace.base),
          children: [
            if (_error != null) VErrorView(message: _error!, onRetry: _load),
            if (_error == null && _items == null) const VLoading(label: 'Loading your posts'),
            if (_items != null && _items!.isEmpty)
              const VEmptyState(title: 'No posts yet', body: 'Posts you write will show up here.'),
            for (final item in _items ?? []) ...[
              _PostCard(
                item: item,
                onKudos: () {},
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: VColor.textLow, size: 20),
                  color: VColor.surfaceRaised,
                  onSelected: (v) => v == 'edit' ? _edit(item) : _delete(item),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ),
              const SizedBox(height: VSpace.base),
            ],
          ],
        ),
      ),
    );
  }
}
