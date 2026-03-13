import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// --- 请确保这里正确引入了您的 chat.dart 文件 ---
import 'chat.dart';

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

  // 多图和多标签的状态
  List<File> _newImageFiles = [];
  List<String> _existingImageUrls = [];
  List<String> _addedTags = [];

  // --- 分页相关状态 ---
  int _currentPage = 0;
  final int _itemsPerPage = 5; // 论坛帖子较高，每页显示5条刚刚好

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

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.redAccent),
            SizedBox(width: 10),
            Text("Attention", style: TextStyle(color: Colors.redAccent)),
          ],
        ),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

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
      _currentPage = 0; // 搜索时重置回第一页
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
      final postData = await supabase.from('forum_post').select().order('uploadDate', ascending: false);
      List<String> myLikes = [];
      if (_currentUserId != null) {
        final likedRows = await supabase.from('forum_likes').select('postID').eq('userID', _currentUserId!);
        myLikes = (likedRows as List).map((row) => row['postID'].toString()).toList();
      }
      if (mounted) {
        setState(() {
          _posts = List<Map<String, dynamic>>.from(postData);
          _filteredPosts = _posts;
          _myLikedPostIds = myLikes;
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
    if (_currentUserId == null) return;
    try {
      await supabase.rpc('toggle_post_like', params: {'p_post_id': postId, 'p_user_id': _currentUserId});
      await _fetchPosts();
    } catch (e) {
      if (mounted) _showError("Failed to like post: $e");
    }
  }

  String _generatePostID() {
    return "FP${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";
  }

  Future<void> _pickImages(StateSetter setModalState) async {
    final pickedFiles = await ImagePicker().pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setModalState(() {
        _newImageFiles.addAll(pickedFiles.map((e) => File(e.path)));
      });
    }
  }

  Widget _buildImageThumbnail({File? file, String? url, required VoidCallback onRemove}) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      width: 100,
      height: 100,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: file != null
                ? Image.file(file, width: 100, height: 100, fit: BoxFit.cover)
                : Image.network(url!, width: 100, height: 100, fit: BoxFit.cover),
          ),
          Positioned(
            top: 0, right: 0,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.cancel, color: Colors.red, size: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPostForm({Map<String, dynamic>? post}) {
    final bool isEdit = post != null;

    if (isEdit) {
      _titleController.text = post['title'] ?? "";
      _contentController.text = post['content'] ?? "";

      String tagsRaw = post['tags'] ?? "";
      _addedTags = tagsRaw.isEmpty ? [] : tagsRaw.split(' ').where((e) => e.isNotEmpty).toList();

      String urlsRaw = post['attachedFileURL'] ?? "";
      _existingImageUrls = urlsRaw.isEmpty ? [] : urlsRaw.split(',').where((e) => e.isNotEmpty).toList();
      _newImageFiles = [];
    } else {
      _titleController.clear();
      _contentController.clear();
      _tagsController.clear();
      _addedTags = [];
      _existingImageUrls = [];
      _newImageFiles = [];
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Text(isEdit ? "Edit Post" : "New Post", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                const SizedBox(height: 20),

                if (_existingImageUrls.isEmpty && _newImageFiles.isEmpty)
                  GestureDetector(
                    onTap: () => _pickImages(setModalState),
                    child: Container(
                      height: 120, width: double.infinity,
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(15)),
                      child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo, size: 40, color: Colors.teal), Text("Select Photos")]),
                    ),
                  )
                else
                  SizedBox(
                    height: 100,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        ..._existingImageUrls.map((url) => _buildImageThumbnail(
                            url: url, onRemove: () => setModalState(() => _existingImageUrls.remove(url)))),
                        ..._newImageFiles.map((file) => _buildImageThumbnail(
                            file: file, onRemove: () => setModalState(() => _newImageFiles.remove(file)))),
                        GestureDetector(
                          onTap: () => _pickImages(setModalState),
                          child: Container(
                            width: 100, height: 100,
                            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.add, size: 40, color: Colors.teal),
                          ),
                        )
                      ],
                    ),
                  ),

                const SizedBox(height: 15),
                TextField(controller: _titleController, decoration: const InputDecoration(labelText: "Title", border: OutlineInputBorder())),
                const SizedBox(height: 15),
                TextField(controller: _contentController, maxLines: 3, decoration: const InputDecoration(labelText: "Content", border: OutlineInputBorder())),
                const SizedBox(height: 15),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tagsController,
                        decoration: const InputDecoration(
                            labelText: "Add Hashtag",
                            prefixText: "# ",
                            border: OutlineInputBorder()
                        ),
                        onSubmitted: (value) {
                          if (value.trim().isNotEmpty) {
                            setModalState(() {
                              _addedTags.add("#${value.trim()}");
                              _tagsController.clear();
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      decoration: BoxDecoration(color: Colors.teal, borderRadius: BorderRadius.circular(10)),
                      child: IconButton(
                        icon: const Icon(Icons.check, color: Colors.white),
                        onPressed: () {
                          if (_tagsController.text.trim().isNotEmpty) {
                            setModalState(() {
                              _addedTags.add("#${_tagsController.text.trim()}");
                              _tagsController.clear();
                            });
                          }
                        },
                      ),
                    )
                  ],
                ),

                if (_addedTags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0,
                      children: _addedTags.map((tag) => Chip(
                        label: Text(tag, style: const TextStyle(color: Colors.teal)),
                        backgroundColor: Colors.teal.shade50,
                        deleteIcon: const Icon(Icons.close, size: 18),
                        onDeleted: () {
                          setModalState(() => _addedTags.remove(tag));
                        },
                      )).toList(),
                    ),
                  ),

                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, minimumSize: const Size(double.infinity, 55)),
                  onPressed: _isSaving ? null : () async {
                    final title = _titleController.text.trim();
                    final content = _contentController.text.trim();

                    if (!isEdit && _newImageFiles.isEmpty) {
                      _showError("Please select at least one image."); return;
                    }
                    if (title.isEmpty) { _showError("Please enter a title."); return; }
                    if (content.isEmpty) { _showError("Please enter some content."); return; }

                    setModalState(() => _isSaving = true);
                    try {
                      List<String> finalUrls = List.from(_existingImageUrls);
                      for (int i = 0; i < _newImageFiles.length; i++) {
                        final file = _newImageFiles[i];
                        final fileName = 'forum_${DateTime.now().millisecondsSinceEpoch}_$i.png';
                        await supabase.storage.from('forum_photos').upload(fileName, file);
                        finalUrls.add(supabase.storage.from('forum_photos').getPublicUrl(fileName));
                      }

                      final Map<String, dynamic> data = {
                        'title': title,
                        'content': content,
                        'tags': _addedTags.join(' '),
                        'attachedFileURL': finalUrls.join(','),
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

                      if (mounted) {
                        Navigator.pop(context);
                        _fetchPosts();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Post submitted!"), backgroundColor: Colors.green));
                      }
                    } catch (e) {
                      _showError("Failed to save post: $e");
                    } finally {
                      setModalState(() => _isSaving = false);
                    }
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

  // --- 分页控件 UI ---
  Widget _buildPagination(int total) {
    return Container(
      padding: const EdgeInsets.only(top: 10, bottom: 25),
      decoration: BoxDecoration(color: Colors.grey[50]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null
          ),
          Text("Page ${_currentPage + 1} of $total", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
          IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 18),
              onPressed: _currentPage < total - 1 ? () => setState(() => _currentPage++) : null
          ),
        ],
      ),
    );
  }

  // --- 包含分页逻辑的 body 渲染 ---
  Widget _buildForumBody() {
    if (_filteredPosts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchPosts,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: const Center(child: Text("No posts found")),
            ),
          ],
        ),
      );
    }

    // 分页计算
    int totalPages = (_filteredPosts.length / _itemsPerPage).ceil();
    if (totalPages == 0) totalPages = 1;

    // 如果当前页码超出了实际页数（比如删除了帖子或者搜索后变少了），重置页码
    if (_currentPage >= totalPages) {
      _currentPage = totalPages - 1;
    }

    int start = _currentPage * _itemsPerPage;
    int end = (start + _itemsPerPage) > _filteredPosts.length ? _filteredPosts.length : (start + _itemsPerPage);
    final pagedPosts = _filteredPosts.sublist(start, end);

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchPosts,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(), // 确保即使帖子很少也可以下拉刷新
              padding: const EdgeInsets.all(10),
              itemCount: pagedPosts.length,
              itemBuilder: (context, index) {
                final post = pagedPosts[index];
                final bool isApproved = post['isApproved'] == true;
                final bool canModify = post['userID'] == _currentUserId || _userRole == 'Admin';
                final bool isLikedByMe = _myLikedPostIds.contains(post['forumPostID'].toString());

                String? firstImageUrl;
                if (post['attachedFileURL'] != null && post['attachedFileURL'].toString().isNotEmpty) {
                  firstImageUrl = post['attachedFileURL'].toString().split(',').first;
                }

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
                            if (firstImageUrl != null)
                              Image.network(firstImageUrl, height: 200, width: double.infinity, fit: BoxFit.cover),
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
        ),
        // 分页指示器
        _buildPagination(totalPages),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Pet Forum", style: TextStyle(fontWeight: FontWeight.bold)),
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
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : _buildForumBody(),
      floatingActionButton: FloatingActionButton(onPressed: () => _showPostForm(), backgroundColor: Colors.teal, child: const Icon(Icons.add, color: Colors.white)),
    );
  }
}

// -------------------------------------------------------------
// POST DETAIL PAGE
// -------------------------------------------------------------
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
  Map<String, dynamic>? _postAuthor;
  bool _isLoading = true;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchPostAuthor();
    _fetchComments();
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.redAccent),
            SizedBox(width: 10),
            Text("Attention", style: TextStyle(color: Colors.redAccent)),
          ],
        ),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  // --- 跳转到聊天界面的核心方法 ---
  void _goToChat(String? targetId, String targetName) {
    final myId = supabase.auth.currentUser?.id;

    if (targetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User information is missing."))
      );
      return;
    }

    // 防止自己和自己聊天
    if (targetId == myId) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You cannot start a chat with yourself."))
      );
      return;
    }

    // 导航到 ChatPage
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(targetUserID: targetId, title: targetName),
      ),
    );
  }

  Future<void> _fetchPostAuthor() async {
    try {
      if (widget.post['userID'] != null) {
        final data = await supabase
            .from('users')
            .select('userName, userPhoto')
            .eq('userID', widget.post['userID'])
            .maybeSingle();

        if (mounted && data != null) {
          setState(() => _postAuthor = data);
        }
      }
    } catch (e) {
      debugPrint("Fetch post author error: $e");
    }
  }

  Future<void> _fetchComments() async {
    try {
      final commentsData = await supabase
          .from('forum_comments')
          .select()
          .eq('postID', widget.post['forumPostID'])
          .order('commentDate', ascending: true);

      if (commentsData.isNotEmpty) {
        final userIds = commentsData
            .map((c) => c['userID'])
            .where((id) => id != null)
            .toSet()
            .toList();

        if (userIds.isNotEmpty) {
          final usersData = await supabase
              .from('users')
              .select('userID, userName, userPhoto')
              .inFilter('userID', userIds);

          final userMap = {for (var u in usersData) u['userID']: u};

          for (var c in commentsData) {
            c['userInfo'] = userMap[c['userID']];
          }
        }
      }

      if (mounted) {
        setState(() {
          _comments = List<Map<String, dynamic>>.from(commentsData);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Fetch comments error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) {
      _showError("Please enter a comment before sending."); return;
    }
    final user = supabase.auth.currentUser;
    if (user == null) {
      _showError("You must be logged in to comment."); return;
    }

    final cid = "CM${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";

    try {
      await supabase.from('forum_comments').insert({
        'commentID': cid,
        'postID': widget.post['forumPostID'],
        'userID': user.id,
        'text': _commentController.text.trim(),
        'commentDate': DateFormat('yyyy-MM-dd').format(DateTime.now())
      });

      await supabase.from('forum_post')
          .update({'replyCount': (widget.post['replyCount'] ?? 0) + 1})
          .eq('forumPostID', widget.post['forumPostID']);

      _commentController.clear();
      _fetchComments();

    } catch (e) {
      if (mounted) _showError("Failed to add comment: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    List<String> imageUrls = [];
    if (widget.post['attachedFileURL'] != null && widget.post['attachedFileURL'].toString().isNotEmpty) {
      imageUrls = widget.post['attachedFileURL'].toString().split(',').where((e) => e.isNotEmpty).toList();
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Discussion"), backgroundColor: Colors.teal, foregroundColor: Colors.white),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imageUrls.isNotEmpty)
                    Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        SizedBox(
                          height: 300,
                          child: PageView.builder(
                            itemCount: imageUrls.length,
                            onPageChanged: (index) {
                              setState(() { _currentImageIndex = index; });
                            },
                            itemBuilder: (context, index) {
                              return Image.network(imageUrls[index], fit: BoxFit.cover, width: double.infinity);
                            },
                          ),
                        ),
                        if (imageUrls.length > 1)
                          Positioned(
                            bottom: 10,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(imageUrls.length, (index) {
                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 3),
                                  width: _currentImageIndex == index ? 10 : 6,
                                  height: _currentImageIndex == index ? 10 : 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _currentImageIndex == index ? Colors.teal : Colors.white70,
                                  ),
                                );
                              }),
                            ),
                          )
                      ],
                    ),

                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.post['title'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),

                        InkWell(
                          onTap: () {
                            final targetId = widget.post['userID'];
                            final targetName = _postAuthor?['userName'] ?? widget.post['userID'] ?? 'Unknown User';
                            _goToChat(targetId, targetName);
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Colors.grey.shade200,
                                  backgroundImage: _postAuthor?['userPhoto'] != null
                                      ? NetworkImage(_postAuthor!['userPhoto'])
                                      : null,
                                  child: _postAuthor?['userPhoto'] == null
                                      ? const Icon(Icons.person, size: 18, color: Colors.grey)
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    "Uploaded by ${_postAuthor?['userName'] ?? widget.post['userID'] ?? 'Unknown User'}",
                                    style: const TextStyle(
                                      color: Colors.teal,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.chat, size: 14, color: Colors.teal),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),

                        if (widget.post['tags'] != null && widget.post['tags'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Text(widget.post['tags'], style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.w600)),
                          ),

                        Text(widget.post['content'], style: const TextStyle(fontSize: 16, height: 1.5)),
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
                                DateTime parsedDate = DateTime.parse(rawDate);
                                formattedDate = DateFormat('dd MMM yyyy').format(parsedDate);
                              } catch (e) { formattedDate = rawDate; }
                            }

                            final userInfo = _comments[i]['userInfo'];
                            final commenterId = _comments[i]['userID'];
                            final commenterName = userInfo?['userName'] ?? commenterId ?? "Unknown User";
                            final commenterPhoto = userInfo?['userPhoto'];

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: GestureDetector(
                                onTap: () => _goToChat(commenterId, commenterName),
                                child: CircleAvatar(
                                  backgroundColor: Colors.teal.shade50,
                                  backgroundImage: commenterPhoto != null ? NetworkImage(commenterPhoto) : null,
                                  child: commenterPhoto == null ? const Icon(Icons.person, color: Colors.teal) : null,
                                ),
                              ),
                              title: GestureDetector(
                                onTap: () => _goToChat(commenterId, commenterName),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Flexible(
                                      child: Text(
                                          commenterName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal)
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(formattedDate, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(_comments[i]['text'] ?? "", style: const TextStyle(fontSize: 15, color: Colors.black87)),
                              ),
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
                IconButton(icon: const Icon(Icons.send, color: Colors.teal), onPressed: _addComment),
              ],
            ),
          )
        ],
      ),
    );
  }
}