import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ForumPage extends StatefulWidget {
  const ForumPage({super.key});

  @override
  State<ForumPage> createState() => _ForumPageState();
}

class _ForumPageState extends State<ForumPage> {
  final SupabaseClient supabase = Supabase.instance.client;

  // Controllers
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagsController = TextEditingController();
  final _searchController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _filteredPosts = [];
  List<String> _myLikedPostIds = [];
  String? _currentUserId;
  String _userRole = 'User';
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  // 1. Ensure User is loaded BEFORE fetching
  Future<void> _initializeData() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      _currentUserId = user.id;
      await _fetchUserRole();
      await _fetchPosts();
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredPosts = _posts.where((post) {
        final title = (post['title'] ?? "").toString().toLowerCase();
        final tags = (post['tags'] ?? "").toString().toLowerCase();
        return title.contains(query) || tags.contains(query);
      }).toList();
    });
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
      // 1. Fetch all forum posts
      final postData = await supabase
          .from('forum_post')
          .select()
          .order('uploadDate', ascending: false);

      // 2. Fetch IDs of posts liked by the current user
      List<String> myLikes = [];
      if (_currentUserId != null) {
        final likedRows = await supabase
            .from('forum_likes')
            .select('postID')
            .eq('userID', _currentUserId!);

        // Convert the database rows into a simple list of strings
        myLikes = (likedRows as List).map((row) => row['postID'].toString()).toList();
      }

      if (mounted) {
        setState(() {
          _posts = List<Map<String, dynamic>>.from(postData);
          _filteredPosts = _posts;
          _myLikedPostIds = myLikes; // This tells the UI which hearts to color red
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Fetch error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deletePost(String postId) async {
    try {
      await supabase.from('forum_post').delete().eq('forumPostID', postId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Post deleted")));
        _fetchPosts();
      }
    } catch (e) { debugPrint("Delete error: $e"); }
  }

  void _showOptionsMenu(Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit, color: Colors.teal),
            title: const Text("Edit Post"),
            onTap: () {
              Navigator.pop(context);
              _showPostForm(post: post);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text("Delete Post"),
            onTap: () {
              Navigator.pop(context);
              _confirmDelete(post['forumPostID']);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _confirmDelete(String postId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Post?"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deletePost(postId);
              },
              child: const Text("DELETE", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
  }

  Future<void> _handleLike(String postId) async {
    if (_currentUserId == null) {
      debugPrint("Like failed: No user logged in");
      return;
    }

    try {
      await supabase.rpc('toggle_post_like', params: {
        'p_post_id': postId,
        'p_user_id': _currentUserId,
      });

      // Refresh the local data to show the red heart and new count
      await _fetchPosts();

    } catch (e) {
      debugPrint("Detailed Like Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  String _generatePostID() {
    return "FP${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";
  }

  Future<void> _pickImage(StateSetter setModalState) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setModalState(() => _imageFile = File(picked.path));
  }

  void _showPostForm({Map<String, dynamic>? post}) {
    final bool isEdit = post != null;
    if (isEdit) {
      _titleController.text = post['title'] ?? "";
      _contentController.text = post['content'] ?? "";
      _tagsController.text = post['tags'] ?? "";
    } else {
      _titleController.clear(); _contentController.clear(); _tagsController.clear(); _imageFile = null;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(isEdit ? "Edit Post" : "New Post", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => _pickImage(setModalState),
                  child: Container(
                    height: 180, width: double.infinity,
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(15)),
                    child: _imageFile != null
                        ? ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.file(_imageFile!, fit: BoxFit.cover))
                        : (isEdit && post['attachedFileURL'] != null)
                        ? ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.network(post['attachedFileURL'], fit: BoxFit.cover))
                        : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo, size: 40, color: Colors.teal), Text("Select Media")]),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(controller: _titleController, decoration: const InputDecoration(labelText: "Title", border: OutlineInputBorder())),
                const SizedBox(height: 15),
                TextField(controller: _contentController, maxLines: 3, decoration: const InputDecoration(labelText: "Content", border: OutlineInputBorder())),
                const SizedBox(height: 15),
                TextField(controller: _tagsController, decoration: const InputDecoration(labelText: "Hashtags", border: OutlineInputBorder())),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, minimumSize: const Size(double.infinity, 55)),
                  onPressed: _isSaving ? null : () async {
                    if (_titleController.text.isEmpty) return;
                    setModalState(() => _isSaving = true);
                    try {
                      String? imageUrl = isEdit ? post['attachedFileURL'] : null;
                      if (_imageFile != null) {
                        final fileName = 'forum_${DateTime.now().millisecondsSinceEpoch}.png';
                        await supabase.storage.from('forum_photos').upload(fileName, _imageFile!);
                        imageUrl = supabase.storage.from('forum_photos').getPublicUrl(fileName);
                      }

                      final Map<String, dynamic> data = {
                        'title': _titleController.text.trim(),
                        'content': _contentController.text.trim(),
                        'tags': _tagsController.text.trim(),
                        'attachedFileURL': imageUrl,
                        'isApproved': _userRole == 'Admin',
                      };

                      if (isEdit) {
                        await supabase.from('forum_post').update(data).eq('forumPostID', post['forumPostID']);
                      } else {
                        data['forumPostID'] = _generatePostID();
                        data['userID'] = _currentUserId;
                        data['uploadDate'] = DateFormat('yyyy-MM-dd').format(DateTime.now());
                        data['likeCount'] = 0;
                        data['replyCount'] = 0;
                        await supabase.from('forum_post').insert(data);
                      }
                      if (mounted) { Navigator.pop(context); _fetchPosts(); }
                    } finally { setModalState(() => _isSaving = false); }
                  },
                  child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text("SUBMIT POST", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Pet Forum"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search titles or #hashtags...",
                prefixIcon: const Icon(Icons.search, color: Colors.teal),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
        onRefresh: _fetchPosts,
        child: _filteredPosts.isEmpty
            ? const Center(child: Text("No posts found"))
            : ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: _filteredPosts.length,
          itemBuilder: (context, index) {
            final post = _filteredPosts[index];
            final bool isApproved = post['isApproved'] == true;
            final bool canModify = post['userID'] == _currentUserId || _userRole == 'Admin';
            final bool isLikedByMe = _myLikedPostIds.contains(post['forumPostID'].toString());

            return Card(
              margin: const EdgeInsets.only(bottom: 15),
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailPage(post: post))).then((_) => _fetchPosts()),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (post['attachedFileURL'] != null)
                          Image.network(post['attachedFileURL'], height: 200, width: double.infinity, fit: BoxFit.cover),
                        ListTile(
                          title: Text(post['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          subtitle: Text(post['tags'] ?? "", style: const TextStyle(color: Colors.teal)),
                          trailing: canModify ? IconButton(icon: const Icon(Icons.more_vert), onPressed: () => _showOptionsMenu(post)) : null,
                        ),
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(post['content'], maxLines: 2, overflow: TextOverflow.ellipsis)),
                        const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Divider()),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Row(
                            children: [
                              InkWell(
                                onTap: () => _handleLike(post['forumPostID']),
                                child: Row(children: [
                                  Icon(isLikedByMe ? Icons.favorite : Icons.favorite_border, color: isLikedByMe ? Colors.red : Colors.grey, size: 20),
                                  const SizedBox(width: 5),
                                  Text("${post['likeCount']}"),
                                ]),
                              ),
                              const SizedBox(width: 20),
                              const Icon(Icons.chat_bubble_outline, size: 20, color: Colors.grey),
                              const SizedBox(width: 5),
                              Text("${post['replyCount']}"),
                            ],
                          ),
                        )
                      ],
                    ),

                    if (!isApproved)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black45,
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.hourglass_empty, color: Colors.white, size: 30),
                                SizedBox(height: 8),
                                Text(
                                  "PENDING APPROVAL",
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2),
                                ),
                                Text("Only visible to you", style: TextStyle(color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => _showPostForm(), backgroundColor: Colors.teal, child: const Icon(Icons.add, color: Colors.white)),
    );
  }
}

class PostDetailPage extends StatefulWidget {
  final Map<String, dynamic> post;
  const PostDetailPage({super.key, required this.post});
  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final _commentController = TextEditingController();
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  Future<void> _fetchComments() async {
    try {
      final data = await supabase
          .from('forum_comments')
          .select()
          .eq('postID', widget.post['forumPostID']) // Using postID column
          .order('commentDate', ascending: true);

      if (mounted) {
        setState(() {
          _comments = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Fetch error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.isEmpty) return;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final cid = "CM${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";

    try {
      // Changed key to 'postID' to match your database
      await supabase.from('forum_comments').insert({
        'commentID': cid,
        'postID': widget.post['forumPostID'], // Sending post ID to the postID column
        'userID': user.id,                    // Required for RLS policy
        'text': _commentController.text.trim(),
        'commentDate': DateFormat('yyyy-MM-dd').format(DateTime.now())
      });

      // Update the reply count on the main forum post
      await supabase.from('forum_post')
          .update({'replyCount': (widget.post['replyCount'] ?? 0) + 1})
          .eq('forumPostID', widget.post['forumPostID']);

      _commentController.clear();
      _fetchComments();

    } catch (e) {
      debugPrint("Add Comment error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Discussion"), backgroundColor: Colors.teal, foregroundColor: Colors.white),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (widget.post['attachedFileURL'] != null)
                    Image.network(widget.post['attachedFileURL']),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.post['title'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(widget.post['content'], style: const TextStyle(fontSize: 16, height: 1.4)),
                        const Divider(height: 40),
                        const Text("Comments", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 10),
                        _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _comments.length,
                          itemBuilder: (context, i) {
                            final rawDate = _comments[i]['commentDate'];
                            String formattedDate = rawDate ?? "";

                            if (rawDate != null) {
                              try {
                                // Parses the ISO 8601 string and formats it
                                DateTime parsedDate = DateTime.parse(rawDate);
                                formattedDate = DateFormat('dd MMM yyyy').format(parsedDate);
                              } catch (e) {
                                formattedDate = rawDate; // Fallback to raw string if parsing fails
                              }
                            }

                            return ListTile(
                              leading: const CircleAvatar(child: Icon(Icons.person)),
                              title: Text(_comments[i]['text'] ?? ""),
                              subtitle: Text(formattedDate),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(15, 10, 15, MediaQuery.of(context).padding.bottom + 10),
            decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200))
            ),
            child: Row(
              children: [
                Expanded(
                    child: TextField(
                        controller: _commentController,
                        decoration: const InputDecoration(hintText: "Add a comment...", border: InputBorder.none)
                    )
                ),
                IconButton(
                    icon: const Icon(Icons.send, color: Colors.teal),
                    onPressed: _addComment
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}