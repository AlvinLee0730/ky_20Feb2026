import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// 确保您的项目中存在这些本地文件
import 'chat.dart';

class LostAndFoundPage extends StatefulWidget {
  const LostAndFoundPage({super.key});

  @override
  State<LostAndFoundPage> createState() => _LostAndFoundPageState();
}

class _LostAndFoundPageState extends State<LostAndFoundPage> {
  final _supabase = Supabase.instance.client;

  // 状态管理
  String _selectedTab = 'Lost';
  int _currentPage = 0;
  final int _itemsPerPage = 6;

  // --- 手动控制的 State 以实现即时刷新 ---
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;

  // --- 搜索与过滤相关状态 ---
  final _searchController = TextEditingController();
  String _searchQuery = "";
  String _filterGender = 'All';
  DateTime? _filterDate;

  // 表单相关控制器
  final _locationController = TextEditingController();
  final _contactController = TextEditingController();
  final _remarkController = TextEditingController();
  DateTime? _eventDate;
  String _selectedGender = 'Male';
  String _contactType = 'Phone';
  bool _isSaving = false;

  // --- 多图上传状态 ---
  List<File> _newImageFiles = [];

  @override
  void initState() {
    super.initState();
    _fetchPosts(); // 初始抓取数据
  }

  @override
  void dispose() {
    _searchController.dispose();
    _locationController.dispose();
    _contactController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  // --- 核心：抓取数据函数 (支持刷新) ---
  Future<void> _fetchPosts() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final String table = _selectedTab == 'Lost' ? 'lost_post' : 'found_post';
      final data = await _supabase.from(table).select().order('uploadDate', ascending: false);

      if (mounted) {
        setState(() {
          _posts = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Fetch error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
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

  Future<void> _pickImages(StateSetter setModalState) async {
    final pickedFiles = await ImagePicker().pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setModalState(() {
        _newImageFiles.addAll(pickedFiles.map((e) => File(e.path)));
      });
    }
  }

  Widget _buildImageThumbnail({required File file, required VoidCallback onRemove}) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      width: 100,
      height: 100,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(file, width: 100, height: 100, fit: BoxFit.cover),
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

  Future<void> _submitPost() async {
    if (_newImageFiles.isEmpty) {
      _showError("Please select at least one photo.");
      return;
    }
    if (_locationController.text.trim().isEmpty) {
      _showError("Please enter the location.");
      return;
    }
    if (_eventDate == null) {
      _showError("Please select a date.");
      return;
    }

    if (_contactType == 'Phone') {
      String phone = _contactController.text.trim();
      final reg011 = RegExp(r'^011-\d{8}$');
      final regNormal = RegExp(r'^01[0,2-9]-\d{7}$');

      if (phone.startsWith('011')) {
        if (!reg011.hasMatch(phone)) {
          _showError("Format Error!\n011 numbers must follow: 011-XXXXXXXX (11 digits)");
          return;
        }
      } else {
        if (!regNormal.hasMatch(phone)) {
          _showError("Format Error!\nNormal mobile must follow: 01X-XXXXXXX (10 digits)");
          return;
        }
      }
    } else if (_contactController.text.trim().isEmpty) {
      _showError("Please enter your social media handle.");
      return;
    }

    if (_remarkController.text.length > 100) {
      _showError("Remark cannot exceed 100 characters.");
      return;
    }

    setState(() => _isSaving = true);
    try {
      final String table = _selectedTab == 'Lost' ? 'lost_post' : 'found_post';
      final String idKey = _selectedTab == 'Lost' ? 'lostPostID' : 'foundPostID';
      final String dateKey = _selectedTab == 'Lost' ? 'dateLost' : 'dateFound';

      List<String> finalUrls = [];
      for (int i = 0; i < _newImageFiles.length; i++) {
        final file = _newImageFiles[i];
        final fileName = 'lf_${DateTime.now().millisecondsSinceEpoch}_$i.png';
        await _supabase.storage.from('lost_found_photos').upload(fileName, file);
        finalUrls.add(_supabase.storage.from('lost_found_photos').getPublicUrl(fileName));
      }

      final prefix = _selectedTab == 'Lost' ? 'LPP' : 'FPP';
      final newID = "$prefix${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}";
      final String formattedContact = "$_contactType: ${_contactController.text.trim()}";

      await _supabase.from(table).insert({
        idKey: newID,
        'userID': _supabase.auth.currentUser!.id,
        'gender': _selectedGender,
        'location': _locationController.text.trim(),
        dateKey: DateFormat('yyyy-MM-dd').format(_eventDate!),
        'photoURL': finalUrls.join(','),
        'contactInfo': formattedContact,
        'uploadDate': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'remark': _remarkController.text.trim(),
        'isApproved': false,
        'status': 'Active', // 默认状态为 Active
      });

      if (mounted) {
        Navigator.pop(context);
        _fetchPosts(); // 发布后立即刷新列表
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Submitted successfully! Waiting for approval."), backgroundColor: Colors.green)
        );
      }
      _clearForm();
    } catch (e) {
      _showError("Upload failed: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _clearForm() {
    _locationController.clear();
    _contactController.clear();
    _remarkController.clear();
    _newImageFiles = [];
    _eventDate = null;
    _selectedGender = 'Male';
    _contactType = 'Phone';
  }

  void _showAddForm() {
    _clearForm();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_selectedTab == 'Lost' ? "Report Lost Pet" : "Report Found Pet", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                // Location
                TextField(controller: _locationController, decoration: const InputDecoration(labelText: "Location", border: OutlineInputBorder())),
                const SizedBox(height: 15),
                // Date
                ListTile(
                  shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)),
                  title: Text(_eventDate == null ? "Select Date" : DateFormat('yyyy-MM-dd').format(_eventDate!)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
                    if (picked != null) setModalState(() => _eventDate = picked);
                  },
                ),
                const SizedBox(height: 15),
                // Gender
                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  items: ['Male', 'Female'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setModalState(() => _selectedGender = v!),
                  decoration: const InputDecoration(labelText: "Gender", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 15),

                // 🌟 Contact (修复了文字溢出的问题)
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _contactType,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 15),
                        ),
                        items: ['Phone', 'Email', 'Facebook', 'Instagram'].map((e) => DropdownMenuItem(
                            value: e,
                            child: Text(
                              e,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            )
                        )).toList(),
                        onChanged: (v) => setModalState(() => _contactType = v!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: TextField(
                          controller: _contactController,
                          decoration: const InputDecoration(
                            labelText: "Contact Info",
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                          )
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // Remark
                TextField(controller: _remarkController, decoration: const InputDecoration(labelText: "Remark (Max 100 chars)", border: OutlineInputBorder()), maxLength: 100),
                const SizedBox(height: 15),
                // Photos
                ElevatedButton.icon(
                  onPressed: () => _pickImages(setModalState),
                  icon: const Icon(Icons.photo),
                  label: const Text("Select Photos"),
                ),
                const SizedBox(height: 10),
                if (_newImageFiles.isNotEmpty)
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _newImageFiles.length,
                      itemBuilder: (ctx, i) => _buildImageThumbnail(file: _newImageFiles[i], onRemove: () => setModalState(() => _newImageFiles.removeAt(i))),
                    ),
                  ),
                const SizedBox(height: 25),
                _isSaving ? const Center(child: CircularProgressIndicator()) : ElevatedButton(
                  onPressed: _submitPost,
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.teal),
                  child: const Text("SUBMIT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFilterModal() {
    String tempGender = _filterGender;
    DateTime? tempDate = _filterDate;
    TextEditingController tempLocController = TextEditingController(text: _searchController.text);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Filter Options", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () {
                      setModalState(() {
                        tempGender = 'All';
                        tempDate = null;
                        tempLocController.clear();
                      });
                    },
                    child: const Text("Reset", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
              const SizedBox(height: 15),
              TextField(
                controller: tempLocController,
                decoration: InputDecoration(
                  labelText: "Location",
                  prefixIcon: const Icon(Icons.location_on, color: Colors.teal),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: tempGender,
                decoration: InputDecoration(
                  labelText: "Gender",
                  prefixIcon: const Icon(Icons.pets, color: Colors.teal),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
                items: ['All', 'Male', 'Female'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setModalState(() => tempGender = v!),
              ),
              const SizedBox(height: 15),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(15),
                ),
                leading: const Icon(Icons.calendar_today, color: Colors.teal),
                title: Text(tempDate == null ? "Select Date" : DateFormat('yyyy-MM-dd').format(tempDate!)),
                trailing: tempDate != null
                    ? IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => setModalState(() => tempDate = null))
                    : const Icon(Icons.arrow_drop_down),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: tempDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(primary: Colors.teal, onPrimary: Colors.white, onSurface: Colors.black),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) setModalState(() => tempDate = picked);
                },
              ),
              const SizedBox(height: 25),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _filterGender = tempGender;
                    _filterDate = tempDate;
                    _searchController.text = tempLocController.text;
                    _searchQuery = tempLocController.text.toLowerCase();
                    _currentPage = 0;
                  });
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                ),
                child: const Text("APPLY FILTERS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = _supabase.auth.currentUser?.id;
    final dateKey = _selectedTab == 'Lost' ? 'dateLost' : 'dateFound';
    final bool hasActiveFilter = _filterGender != 'All' || _filterDate != null;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Lost & Found", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() {
                      _searchQuery = val.toLowerCase();
                      _currentPage = 0;
                    }),
                    decoration: InputDecoration(
                      hintText: "Search location...",
                      prefixIcon: const Icon(Icons.search, color: Colors.teal),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _showFilterModal,
                  child: Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: hasActiveFilter ? Border.all(color: Colors.orange, width: 2) : null,
                    ),
                    child: Icon(Icons.filter_list, color: hasActiveFilter ? Colors.orange : Colors.teal),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildHubSelector(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildFilteredList(currentUid, dateKey),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddForm,
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
    );
  }

  Widget _buildFilteredList(String? currentUid, String dateKey) {
    var data = _posts.where((post) {
      final bool isVisible = (post['isApproved'] == true) || (post['userID'] == currentUid);
      final bool matchesLocation = post['location'].toString().toLowerCase().contains(_searchQuery);
      final bool matchesGender = _filterGender == 'All' || post['gender'] == _filterGender;
      bool matchesDate = true;
      if (_filterDate != null) {
        final String? postDateStr = post[dateKey];
        if (postDateStr != null) {
          matchesDate = postDateStr == DateFormat('yyyy-MM-dd').format(_filterDate!);
        } else {
          matchesDate = false;
        }
      }
      return isVisible && matchesLocation && matchesGender && matchesDate;
    }).toList();

    if (data.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchPosts,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: const Center(child: Text("No records match your filters.")),
            ),
          ],
        ),
      );
    }

    int totalPages = (data.length / _itemsPerPage).ceil();
    if (_currentPage >= totalPages && totalPages > 0) {
      _currentPage = totalPages - 1;
    }

    int start = _currentPage * _itemsPerPage;
    int end = (start + _itemsPerPage) > data.length ? data.length : (start + _itemsPerPage);
    final paged = data.sublist(start, end);

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchPosts,
            child: GridView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, childAspectRatio: 0.75, crossAxisSpacing: 12, mainAxisSpacing: 12),
              itemCount: paged.length,
              itemBuilder: (ctx, i) => _buildPetCard(paged[i]),
            ),
          ),
        ),
        _buildPagination(totalPages == 0 ? 1 : totalPages),
      ],
    );
  }

  Widget _buildHubSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTab = 'Lost';
                  _currentPage = 0;
                });
                _fetchPosts();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedTab == 'Lost' ? Colors.teal : Colors.white,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
                  border: Border.all(color: Colors.teal),
                ),
                child: Center(
                  child: Text(
                    "LOST",
                    style: TextStyle(
                      color: _selectedTab == 'Lost' ? Colors.white : Colors.teal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTab = 'Found';
                  _currentPage = 0;
                });
                _fetchPosts();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedTab == 'Found' ? Colors.teal : Colors.white,
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
                  border: Border.all(color: Colors.teal),
                ),
                child: Center(
                  child: Text(
                    "FOUND",
                    style: TextStyle(
                      color: _selectedTab == 'Found' ? Colors.white : Colors.teal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPetCard(Map<String, dynamic> post) {
    final bool isPending = post['isApproved'] == false;
    final bool isResolved = post['status'] == 'Resolved';

    String? firstImageUrl;
    if (post['photoURL'] != null && post['photoURL'].toString().isNotEmpty) {
      firstImageUrl = post['photoURL'].toString().split(',').first;
    }

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (ctx) => PostDetailPage(post: post, type: _selectedTab))
        ).then((_) => _fetchPosts()), // 从详情页返回后自动刷新
        child: Stack(
            children: [
              // Image
              Positioned.fill(
                child: firstImageUrl != null
                    ? Image.network(firstImageUrl, fit: BoxFit.cover)
                    : Container(color: Colors.grey[200], child: const Icon(Icons.pets, size: 50, color: Colors.grey)),
              ),

              // Status Tags (Resolved 或 Pending)
              if (isResolved)
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(12)),
                    child: const Text("RESOLVED", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                )
              else if (isPending)
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(12)),
                    child: const Text("PENDING", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),

              // Info gradient bar
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.black87, Colors.transparent], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post['location'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(post[_selectedTab == 'Lost' ? 'dateLost' : 'dateFound'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ]
        ),
      ),
    );
  }

  Widget _buildPagination(int totalPages) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 16),
            onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
          ),
          Text("Page ${_currentPage + 1} of $totalPages", style: const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 16),
            onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 🌟 独立详情页面 (PostDetailPage)
// ==========================================
class PostDetailPage extends StatefulWidget {
  final Map<String, dynamic> post;
  final String type;

  const PostDetailPage({super.key, required this.post, required this.type});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final _supabase = Supabase.instance.client;
  late Map<String, dynamic> _currentPost;
  bool _isLoading = false;

  // 获取发帖人信息
  String _authorName = "Unknown User";
  String? _authorPhoto;

  @override
  void initState() {
    super.initState();
    _currentPost = Map<String, dynamic>.from(widget.post);
    _loadAuthorData(); // 加载发帖人信息
  }

  // 从 users 表抓取头像和名字
  Future<void> _loadAuthorData() async {
    try {
      final userRes = await _supabase.from('users').select('userName, userPhoto').eq('userID', widget.post['userID']).maybeSingle();
      if (mounted && userRes != null) {
        setState(() {
          _authorName = userRes['userName'] ?? widget.post['userID'];
          _authorPhoto = userRes['userPhoto'];
        });
      }
    } catch (e) {
      debugPrint("Load author error: $e");
    }
  }

  // 跳转去私聊
  void _goToChat(String? targetId, String targetName) {
    final myId = _supabase.auth.currentUser?.id;
    if (targetId == null) return;
    if (targetId == myId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You cannot start a chat with yourself.")));
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(targetUserID: targetId, title: targetName)));
  }

  // 标记帖子为已解决
  Future<void> _markAsResolved() async {
    bool confirm = await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Mark as Resolved?", style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text("Are you sure you want to mark this post as resolved? This means the pet has successfully found its owner! \n\n(This action cannot be undone)"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Confirm", style: TextStyle(color: Colors.white)),
            ),
          ],
        )
    ) ?? false;

    if (!confirm) return;

    final isLost = widget.type == 'Lost';
    final table = isLost ? 'lost_post' : 'found_post';
    final idKey = isLost ? 'lostPostID' : 'foundPostID';

    try {
      await _supabase.from(table).update({'status': 'Resolved'}).eq(idKey, _currentPost[idKey]);

      if (mounted) {
        setState(() {
          _currentPost['status'] = 'Resolved';
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🎉 Wonderful! Post marked as resolved!"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // 删除帖子
  Future<void> _deletePost() async {
    bool confirm = await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Delete Post?"),
          content: const Text("This action cannot be undone."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.white))),
          ],
        )
    ) ?? false;

    if (!confirm) return;

    final isLost = widget.type == 'Lost';
    final table = isLost ? 'lost_post' : 'found_post';
    final idKey = isLost ? 'lostPostID' : 'foundPostID';

    setState(() => _isLoading = true);
    try {
      await _supabase.from(table).delete().eq(idKey, _currentPost[idKey]);
      if (mounted) {
        Navigator.pop(context, true); // 成功后返回上一页
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 编辑帖子
  void _editPost() {
    final locCtrl = TextEditingController(text: _currentPost['location']);
    final remCtrl = TextEditingController(text: _currentPost['remark']);
    String currentGen = _currentPost['gender'] ?? 'Male';

    // 解析联系方式
    String rawContact = _currentPost['contactInfo'] ?? '';
    String cType = 'Phone';
    String cInfo = rawContact;
    if (rawContact.contains(': ')) {
      final parts = rawContact.split(': ');
      cType = parts[0];
      cInfo = parts[1];
    }
    final conCtrl = TextEditingController(text: cInfo);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Edit Post", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                TextField(controller: locCtrl, decoration: const InputDecoration(labelText: "Location", border: OutlineInputBorder())),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: currentGen,
                  items: ['Male', 'Female'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setModalState(() => currentGen = v!),
                  decoration: const InputDecoration(labelText: "Gender", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: ['Phone', 'Email', 'Facebook', 'Instagram'].contains(cType) ? cType : 'Phone',
                        items: ['Phone', 'Email', 'Facebook', 'Instagram'].map((e) => DropdownMenuItem(
                            value: e,
                            child: Text(e, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))
                        )).toList(),
                        onChanged: (v) => setModalState(() => cType = v!),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 15),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: TextField(
                          controller: conCtrl,
                          decoration: const InputDecoration(
                            labelText: "Contact Info",
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                          )
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                TextField(controller: remCtrl, decoration: const InputDecoration(labelText: "Remark", border: OutlineInputBorder())),
                const SizedBox(height: 25),
                ElevatedButton(
                  onPressed: () async {
                    final isLost = widget.type == 'Lost';
                    final table = isLost ? 'lost_post' : 'found_post';
                    final idKey = isLost ? 'lostPostID' : 'foundPostID';
                    final newContact = "$cType: ${conCtrl.text.trim()}";

                    try {
                      await Supabase.instance.client.from(table).update({
                        'location': locCtrl.text.trim(),
                        'remark': remCtrl.text.trim(),
                        'contactInfo': newContact,
                        'gender': currentGen,
                      }).eq(idKey, _currentPost[idKey]);

                      if (mounted) {
                        Navigator.pop(ctx);
                        setState(() {
                          _currentPost['location'] = locCtrl.text.trim();
                          _currentPost['remark'] = remCtrl.text.trim();
                          _currentPost['contactInfo'] = newContact;
                          _currentPost['gender'] = currentGen;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Updated!"), backgroundColor: Colors.green));
                      }
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                    }
                  },
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.teal),
                  child: const Text("SAVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 提取大图链接
    String? imageUrl;
    if (_currentPost['mediaURLs'] != null && (_currentPost['mediaURLs'] as List).isNotEmpty) {
      imageUrl = _currentPost['mediaURLs'][0];
    } else if (_currentPost['photoURL'] != null && _currentPost['photoURL'].toString().isNotEmpty) {
      imageUrl = _currentPost['photoURL'].toString().split(',').first;
    }

    final isMe = _currentPost['userID'] == Supabase.instance.client.auth.currentUser?.id;
    final isLost = widget.type == 'Lost';
    final String status = _currentPost['status'] ?? 'Active';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Post Details", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.network(imageUrl, width: double.infinity, height: 250, fit: BoxFit.cover),
              ),
            const SizedBox(height: 20),

            // Status Badge (Resolved/Lost/Found)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: status == 'Resolved' ? Colors.green : (isLost ? Colors.red : Colors.teal),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status == 'Resolved' ? "RESOLVED" : (isLost ? "LOST PET" : "FOUND PET"),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const SizedBox(height: 15),

            Text("Location: ${_currentPost['location'] ?? 'Unknown'}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            // ==========================================
            // 🌟 Clickable 聊天头像栏
            // ==========================================
            InkWell(
              onTap: () {
                final targetId = _currentPost['userID'];
                _goToChat(targetId, _authorName);
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
                      backgroundImage: _authorPhoto != null ? NetworkImage(_authorPhoto!) : null,
                      child: _authorPhoto == null ? const Icon(Icons.person, size: 18, color: Colors.grey) : null,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        "Posted by $_authorName",
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
            const SizedBox(height: 10),
            // ==========================================

            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text("Date: ${_currentPost[isLost ? 'dateLost' : 'dateFound'] ?? 'Unknown'}", style: const TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(_currentPost['gender'] == 'Male' ? Icons.male : Icons.female, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text("Gender: ${_currentPost['gender'] ?? 'Unknown'}", style: const TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 20),

            const Text("Description:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text(_currentPost['remark'] ?? "No description provided.", style: const TextStyle(fontSize: 15, height: 1.4)),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.blueGrey[50], borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.contact_phone, color: Colors.teal),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Contact Info", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                        Text(_currentPost['contactInfo'] ?? "Not provided", style: TextStyle(color: Colors.grey[700])),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // ==========================================
            // 🌟 权限控制按钮区域 (仅自己可见)
            // ==========================================
            if (isMe) ...[
              const Divider(),
              const SizedBox(height: 10),

              // 未解决的帖子，显示绿色大按钮
              if (status != 'Resolved') ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _markAsResolved,
                    icon: const Icon(Icons.verified, color: Colors.white),
                    label: const Text("MARK AS RESOLVED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _deletePost,
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text("Delete", style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _editPost,
                      icon: const Icon(Icons.edit, color: Colors.white),
                      label: const Text("Edit", style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}