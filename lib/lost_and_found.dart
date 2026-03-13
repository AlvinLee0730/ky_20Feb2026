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

  // --- 替换 Stream 为手动控制的 State 以实现即时刷新 ---
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
                    child: Icon(
                        Icons.filter_list,
                        color: hasActiveFilter ? Colors.orange : Colors.teal
                    ),
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

  // --- 构建带有下拉刷新与分页的列表 ---
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
                setState(() { _selectedTab = 'Lost'; _currentPage = 0; });
                _fetchPosts(); // 切换标签时抓取数据
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
                setState(() { _selectedTab = 'Found'; _currentPage = 0; });
                _fetchPosts(); // 切换标签时抓取数据
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
        // --- 修改：从详情页返回后，执行 .then 自动刷新最新数据！---
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (ctx) => PostDetailPage(post: post, type: _selectedTab))).then((_) => _fetchPosts()),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: firstImageUrl != null
                      ? Image.network(firstImageUrl, fit: BoxFit.cover, width: double.infinity)
                      : Container(color: Colors.grey[200], child: const Icon(Icons.image_not_supported)),
                ),
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post['location'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(post['gender'] ?? 'Unknown', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
            if (isPending)
              Positioned(
                top: 10, left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.9), borderRadius: BorderRadius.circular(20)),
                  child: const Text("Pending", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagination(int total) {
    return Container(
      padding: const EdgeInsets.only(top: 10, bottom: 25),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18), onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null),
          Text("Page ${_currentPage + 1} of $total", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
          IconButton(icon: const Icon(Icons.arrow_forward_ios, size: 18), onPressed: _currentPage < total - 1 ? () => setState(() => _currentPage++) : null),
        ],
      ),
    );
  }

  void _showAddForm() {
    _newImageFiles = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Text("Report ${_selectedTab} Pet", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                const SizedBox(height: 20),

                if (_newImageFiles.isEmpty)
                  GestureDetector(
                    onTap: () => _pickImages(setModalState),
                    child: Container(
                      height: 120, width: double.infinity,
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(15)),
                      child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo, size: 40, color: Colors.teal), Text("Select Photos *")]),
                    ),
                  )
                else
                  SizedBox(
                    height: 100,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
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
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedGender,
                        decoration: const InputDecoration(labelText: "Gender"),
                        items: ['Male', 'Female'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setModalState(() => _selectedGender = v!),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _contactType,
                        decoration: const InputDecoration(labelText: "Contact Type"),
                        items: ['Phone', 'Social Media'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setModalState(() => _contactType = v!),
                      ),
                    ),
                  ],
                ),
                TextField(controller: _locationController, decoration: const InputDecoration(labelText: "Location *", hintText: "e.g. TARUMT Area")),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today, color: Colors.teal),
                  title: Text(_eventDate == null
                      ? "Select Date ${_selectedTab} *"
                      : "Date ${_selectedTab}: ${DateFormat('yyyy-MM-dd').format(_eventDate!)}"),
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2024),
                      lastDate: DateTime.now(),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(primary: Colors.teal, onPrimary: Colors.white, onSurface: Colors.black),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) setModalState(() => _eventDate = picked);
                  },
                ),
                TextField(
                    controller: _contactController,
                    decoration: InputDecoration(
                        labelText: "Enter $_contactType *",
                        hintText: _contactType == 'Phone' ? "01X-XXXXXXX" : "@username"
                    )
                ),
                TextField(
                  controller: _remarkController,
                  maxLength: 100,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: "Remark (Max 100 characters)",
                      alignLabelWithHint: true,
                      hintText: "Anything else to add?"
                  ),
                ),
                const SizedBox(height: 25),
                _isSaving
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                  onPressed: _submitPost,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                  ),
                  child: const Text("SUBMIT FOR APPROVAL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- 详情与编辑页面 ---
class PostDetailPage extends StatefulWidget {
  final Map<String, dynamic> post;
  final String type;
  const PostDetailPage({super.key, required this.post, required this.type});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final _supabase = Supabase.instance.client;
  bool _isAdmin = false;
  String _authorName = "Unknown User";
  String? _authorPhoto;
  int _currentImageIndex = 0;

  // --- 核心：将静态的 widget.post 转为可变的状态，以便在不退出的情况下刷新UI ---
  late Map<String, dynamic> _currentPost;

  @override
  void initState() {
    super.initState();
    _currentPost = Map<String, dynamic>.from(widget.post); // 拷贝数据到本地 State
    _loadData();
  }

  Future<void> _loadData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      final roleRes = await _supabase.from('users').select('role').eq('userID', user.id).maybeSingle();
      if (mounted && roleRes != null) setState(() => _isAdmin = roleRes['role'] == 'Admin');

      final userRes = await _supabase.from('users').select('userName, userPhoto').eq('userID', _currentPost['userID']).maybeSingle();
      if (mounted && userRes != null) {
        setState(() {
          _authorName = userRes['userName'] ?? _currentPost['userID'];
          _authorPhoto = userRes['userPhoto'];
        });
      }
    } catch (e) {
      debugPrint("Load error: $e");
    }
  }

  void _goToChat(String? targetId, String targetName) {
    final myId = _supabase.auth.currentUser?.id;
    if (targetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User information is missing.")));
      return;
    }
    if (targetId == myId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You cannot start a chat with yourself.")));
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(targetUserID: targetId, title: targetName)));
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Validation Failed", style: TextStyle(color: Colors.redAccent)),
        content: Text(msg),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK", style: TextStyle(color: Colors.teal)))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 所有的 widget.post 都改用 _currentPost
    final bool isOwner = _supabase.auth.currentUser?.id == _currentPost['userID'];
    final bool canModify = isOwner || _isAdmin;
    final String dateKey = widget.type == 'Lost' ? 'dateLost' : 'dateFound';

    List<String> imageUrls = [];
    if (_currentPost['photoURL'] != null && _currentPost['photoURL'].toString().isNotEmpty) {
      imageUrls = _currentPost['photoURL'].toString().split(',').where((e) => e.isNotEmpty).toList();
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(_currentPost['location']),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (canModify) ...[
            IconButton(icon: const Icon(Icons.edit, color: Colors.white), onPressed: () => _showEditForm(context)),
            IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: _confirmDelete),
          ]
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
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
                  Text(_currentPost['location'], style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),

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
                              "Uploaded by $_authorName",
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

                  _rowItem(Icons.pets, "Gender", _currentPost['gender'] ?? 'Unknown'),
                  _rowItem(Icons.calendar_today, "Date ${widget.type}", _currentPost[dateKey] ?? "N/A"),
                  _rowItem(Icons.contact_phone, "Contact Info", _currentPost['contactInfo'] ?? 'N/A'),
                  const Divider(height: 30),
                  const Text("Remarks:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(_currentPost['remark'] ?? "None", style: const TextStyle(fontSize: 15)),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, size: 20, color: Colors.teal),
        const SizedBox(width: 12),
        Text("$label: ", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold))),
      ]),
    );
  }

  void _confirmDelete() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Delete Post?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.teal))),
        TextButton(onPressed: () async {
          final table = widget.type == 'Lost' ? 'lost_post' : 'found_post';
          final idKey = widget.type == 'Lost' ? 'lostPostID' : 'foundPostID';
          await _supabase.from(table).delete().eq(idKey, _currentPost[idKey]);
          if (mounted) {
            Navigator.pop(ctx); // 关闭确认弹窗
            Navigator.pop(context); // 关闭详情页，回到列表后会自动触发刷新
          }
        }, child: const Text("Delete", style: TextStyle(color: Colors.red))),
      ],
    ));
  }

  void _showEditForm(BuildContext context) {
    final loc = TextEditingController(text: _currentPost['location']);
    final rem = TextEditingController(text: _currentPost['remark']);

    String initialType = 'Phone';
    String initialVal = _currentPost['contactInfo'] ?? "";
    if (initialVal.contains(': ')) {
      initialType = initialVal.split(': ')[0];
      initialVal = initialVal.split(': ')[1];
    }
    final con = TextEditingController(text: initialVal);

    String currentGen = _currentPost['gender'] ?? 'Male';
    String currentType = initialType;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Edit Report Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: currentGen,
                        decoration: const InputDecoration(labelText: "Gender"),
                        items: ['Male', 'Female'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setMState(() => currentGen = v!),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: currentType,
                        decoration: const InputDecoration(labelText: "Contact Type"),
                        items: ['Phone', 'Social Media'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setMState(() => currentType = v!),
                      ),
                    ),
                  ],
                ),
                TextField(controller: loc, decoration: const InputDecoration(labelText: "Location")),
                TextField(controller: con, decoration: InputDecoration(labelText: "Enter $currentType")),
                TextField(
                  controller: rem,
                  maxLength: 100,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: "Remark (Max 100 chars)", alignLabelWithHint: true),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    if (currentType == 'Phone') {
                      final val = con.text.trim();
                      final reg011 = RegExp(r'^011-\d{8}$');
                      final regNormal = RegExp(r'^01[0,2-9]-\d{7}$');
                      if (val.startsWith('011')) {
                        if (!reg011.hasMatch(val)) {
                          _showError("Format for 011 must be 011-XXXXXXXX");
                          return;
                        }
                      } else if (!regNormal.hasMatch(val)) {
                        _showError("Format must be 01X-XXXXXXX");
                        return;
                      }
                    }

                    if (rem.text.length > 100) {
                      _showError("Remark is too long (max 100).");
                      return;
                    }

                    final table = widget.type == 'Lost' ? 'lost_post' : 'found_post';
                    final idKey = widget.type == 'Lost' ? 'lostPostID' : 'foundPostID';

                    await _supabase.from(table).update({
                      'location': loc.text.trim(),
                      'remark': rem.text.trim(),
                      'contactInfo': "$currentType: ${con.text.trim()}",
                      'gender': currentGen,
                    }).eq(idKey, _currentPost[idKey]);

                    if (mounted) {
                      Navigator.pop(ctx); // --- 修改：只关闭底部表单弹窗，不退出详情页！---

                      // --- 同步更新本地UI状态，让页面立刻展现修改结果 ---
                      setState(() {
                        _currentPost['location'] = loc.text.trim();
                        _currentPost['remark'] = rem.text.trim();
                        _currentPost['contactInfo'] = "$currentType: ${con.text.trim()}";
                        _currentPost['gender'] = currentGen;
                      });

                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Post updated successfully!"), backgroundColor: Colors.green));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                  ),
                  child: const Text("SAVE CHANGES", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}