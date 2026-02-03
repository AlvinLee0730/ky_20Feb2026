import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- MAIN FORUM FEED PAGE ---
class ForumPage extends StatefulWidget {
  const ForumPage({super.key});

  @override
  State<ForumPage> createState() => _ForumPageState();
}

class _ForumPageState extends State<ForumPage> {
  final SupabaseClient supabase = Supabase.instance.client;

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagsController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  List<Map<String, dynamic>> _posts = [];
  String? _currentUserId;
  String _userRole = 'User';
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _currentUserId = supabase.auth.currentUser?.id;
    _fetchUserRole();
    _fetchPosts();
  }

  Future<void> _fetchUserRole() async {
    if (_currentUserId == null) return;
    try {
      final data = await supabase.from('users').select('role').eq('userID', _currentUserId!).maybeSingle();
      if (mounted && data != null) setState(() => _userRole = data['role'] ?? 'User');
    } catch (e) { debugPrint("Role error: $e"); }
  }

  Future<void> _fetchPosts() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final data = await supabase.from('forumPost').select().order('uploadDate', ascending: false);
      setState(() {
        _posts = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) { if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _handleLike(dynamic postId) async {
    try {
      await supabase.rpc('increment_like', params: {'post_id': postId.toString()});
      _fetchPosts();
    } catch (e) { debugPrint("Like error: $e"); }
  }

  Future<void> _deletePost(dynamic postId) async {
    final confirm = await _confirmAction("Delete Post", "This will permanently remove the post.");
    if (confirm) {
      await supabase.from('forumPost').delete().eq('forumPostID', postId);
      _fetchPosts();
    }
  }

  Future<bool> _confirmAction(String title, String desc) async {
    return await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(desc),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Confirm", style: TextStyle(color: Colors.red))),
          ],
        )
    ) ?? false;
  }

  void _showPostDialog({Map<String, dynamic>? post}) {
    final bool isEdit = post != null;
    if (isEdit) {
      _titleController.text = post['title'] ?? "";
      _contentController.text = post['content'] ?? "";
    } else {
      _titleController.clear(); _contentController.clear(); _imageFile = null;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? "Edit Post" : "New Post"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_imageFile != null) Image.file(_imageFile!, height: 100),
                if (!isEdit) TextButton.icon(onPressed: () => _pickImage(setDialogState), icon: const Icon(Icons.photo), label: const Text("Add Photo")),
                TextField(controller: _titleController, decoration: const InputDecoration(labelText: "Title")),
                TextField(controller: _contentController, decoration: const InputDecoration(labelText: "Content"), maxLines: 3),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: _isSaving ? null : () async {
                setState(() => _isSaving = true);
                if (isEdit) {
                  await supabase.from('forumPost').update({'title': _titleController.text, 'content': _contentController.text}).eq('forumPostID', post['forumPostID']);
                } else {
                  await supabase.from('forumPost').insert({'userID': _currentUserId, 'title': _titleController.text, 'content': _contentController.text});
                }
                _fetchPosts(); Navigator.pop(context); setState(() => _isSaving = false);
              },
              child: const Text("Save"),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(StateSetter setDialogState) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setDialogState(() => _imageFile = File(picked.path));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pet Forum"), backgroundColor: Colors.teal, foregroundColor: Colors.white),
      body: RefreshIndicator(
        onRefresh: _fetchPosts,
        child: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
          itemCount: _posts.length,
          itemBuilder: (context, index) {
            final post = _posts[index];
            final bool isOwner = post['userID'] == _currentUserId;
            final bool isAdmin = _userRole == 'Admin';

            return Card(
              margin: const EdgeInsets.all(10),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailPage(post: post, userRole: _userRole))).then((_) => _fetchPosts()),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (post['attachedFileURL'] != null) Image.network(post['attachedFileURL'], height: 180, width: double.infinity, fit: BoxFit.cover),
                    ListTile(
                      title: Text(post['title'] ?? "", style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(post['content'] ?? "", maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: (isOwner || isAdmin) ? PopupMenuButton<String>(
                        onSelected: (v) => v == 'e' ? _showPostDialog(post: post) : _deletePost(post['forumPostID']),
                        itemBuilder: (c) => [
                          if (isOwner) const PopupMenuItem(value: 'e', child: Text("Edit")),
                          const PopupMenuItem(value: 'd', child: Text("Delete", style: TextStyle(color: Colors.red))),
                        ],
                      ) : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.favorite, color: Colors.redAccent, size: 20),
                          const SizedBox(width: 5),
                          Text("${post['likeCount'] ?? 0}"),
                          const SizedBox(width: 20),
                          const Icon(Icons.mode_comment_outlined, size: 20),
                          const SizedBox(width: 5),
                          Text("${post['replyCount'] ?? 0}"),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => _showPostDialog(), backgroundColor: Colors.teal, child: const Icon(Icons.add, color: Colors.white)),
    );
  }
}

// --- POST DETAIL PAGE ---
class PostDetailPage extends StatefulWidget {
  final Map<String, dynamic> post;
  final String userRole;
  const PostDetailPage({super.key, required this.post, required this.userRole});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final SupabaseClient supabase = Supabase.instance.client;
  final _commentController = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  Future<void> _fetchComments() async {
    final data = await supabase.from('comment').select().eq('forumPostID', widget.post['forumPostID'].toString()).order('commentDate', ascending: true);
    setState(() {
      _comments = List<Map<String, dynamic>>.from(data);
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Post Details"), backgroundColor: Colors.teal, foregroundColor: Colors.white),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.post['attachedFileURL'] != null) Image.network(widget.post['attachedFileURL'], width: double.infinity, fit: BoxFit.fitWidth),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.post['title'] ?? "", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Text(widget.post['content'] ?? "", style: const TextStyle(fontSize: 16, height: 1.5)),
                        const Divider(height: 40),
                        const Text("Comments", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _comments.length,
                          itemBuilder: (c, i) => ListTile(
                            leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.person, color: Colors.white)),
                            title: Text(_comments[i]['text']),
                            subtitle: Text(_comments[i]['commentDate'] ?? ""),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 10, left: 15, right: 15, top: 10),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _commentController, decoration: const InputDecoration(hintText: "Write a comment...", border: InputBorder.none))),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.teal),
                  onPressed: () async {
                    if (_commentController.text.isEmpty) return;
                    await supabase.from('comment').insert({'forumPostID': widget.post['forumPostID'].toString(), 'userID': supabase.auth.currentUser?.id, 'text': _commentController.text});
                    await supabase.rpc('increment_reply', params: {'post_id': widget.post['forumPostID'].toString()});
                    _commentController.clear();
                    _fetchComments();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}