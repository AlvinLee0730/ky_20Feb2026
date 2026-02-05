import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// Your existing local files
import 'chat.dart';

class LostAndFoundPage extends StatefulWidget {
  const LostAndFoundPage({super.key});

  @override
  State<LostAndFoundPage> createState() => _LostAndFoundPageState();
}

class _LostAndFoundPageState extends State<LostAndFoundPage> {
  final _supabase = Supabase.instance.client;

  // Hub & Pagination State
  String _selectedTab = 'Lost';
  int _currentPage = 0;
  final int _itemsPerPage = 6;

  // Search State
  final _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = "";

  // Form State
  final _locationController = TextEditingController();
  final _contactController = TextEditingController();
  final _remarkController = TextEditingController();
  File? _imageFile;
  String _selectedGender = 'Male';
  bool _isSaving = false;

  @override
  void dispose() {
    _searchController.dispose();
    _locationController.dispose();
    _contactController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _submitPost() async {
    if (_locationController.text.isEmpty || _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please add an image and location")));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final String table = _selectedTab == 'Lost' ? 'lost_post' : 'found_post';
      final String idKey = _selectedTab == 'Lost' ? 'lostPostID' : 'foundPostID';

      final fileName = '${DateTime.now().millisecondsSinceEpoch}.png';
      await _supabase.storage.from('lost_found_photos').upload(fileName, _imageFile!);
      final imageUrl = _supabase.storage.from('lost_found_photos').getPublicUrl(fileName);

      final prefix = _selectedTab == 'Lost' ? 'LPP' : 'FPP';
      final newID = "$prefix${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}";

      await _supabase.from(table).insert({
        idKey: newID,
        'userID': _supabase.auth.currentUser!.id,
        'gender': _selectedGender,
        'location': _locationController.text.trim(),
        _selectedTab == 'Lost' ? 'dateLost' : 'dateFound': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'photoURL': imageUrl,
        'contactInfo': _contactController.text.trim(),
        'uploadDate': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'remark': _remarkController.text.trim(),
        'isApproved': false,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Submitted! Waiting for Admin approval.")));
      }
      _clearForm();
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _clearForm() {
    _locationController.clear();
    _contactController.clear();
    _remarkController.clear();
    _imageFile = null;
    _selectedGender = 'Male';
  }

  @override
  Widget build(BuildContext context) {
    final table = _selectedTab == 'Lost' ? 'lost_post' : 'found_post';
    final idKey = _selectedTab == 'Lost' ? 'lostPostID' : 'foundPostID';
    final currentUid = _supabase.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: _isSearching
            ? TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "Search area...",
            border: InputBorder.none,
          ),
          onChanged: (val) {
            setState(() {
              _searchQuery = val.toLowerCase();
              _currentPage = 0;
            });
          },
        )
            : const Text(
            "Lost and Found Hub",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _searchQuery = "";
                }
              });
            },
          )
        ],
      ),
      body: Column(
        children: [
          _buildHubSelector(),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _supabase.from(table).stream(primaryKey: [idKey]).order('uploadDate', ascending: false),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                // FILTER: Visibility (Approved or Owner) AND Search Query (Area)
                var data = snapshot.data!.where((post) {
                  final bool isVisible = (post['isApproved'] == true) || (post['userID'] == currentUid);
                  final bool matchesSearch = post['location'].toString().toLowerCase().contains(_searchQuery);
                  return isVisible && matchesSearch;
                }).toList();

                if (data.isEmpty) return const Center(child: Text("No reports found."));

                int totalPages = (data.length / _itemsPerPage).ceil();
                if (totalPages == 0) totalPages = 1;
                int start = _currentPage * _itemsPerPage;
                int end = (start + _itemsPerPage) > data.length ? data.length : (start + _itemsPerPage);
                final paged = data.sublist(start, end);

                return Column(
                  children: [
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2, childAspectRatio: 0.75, crossAxisSpacing: 12, mainAxisSpacing: 12),
                        itemCount: paged.length,
                        itemBuilder: (ctx, i) => _buildPetCard(paged[i]),
                      ),
                    ),
                    _buildPagination(totalPages),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 60),
        child: FloatingActionButton(
          onPressed: _showAddForm,
          backgroundColor: Colors.teal,
          child: const Icon(Icons.add, color: Colors.white, size: 30),
        ),
      ),
    );
  }

  Widget _buildHubSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        height: 65,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(color: const Color(0xFFF1F1F1), borderRadius: BorderRadius.circular(35)),
        child: Row(
          children: [
            _buildBigTab("Lost", Colors.redAccent),
            _buildBigTab("Found", Colors.teal),
          ],
        ),
      ),
    );
  }

  Widget _buildBigTab(String type, Color activeColor) {
    bool isSel = _selectedTab == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() { _selectedTab = type; _currentPage = 0; }),
        child: Container(
          decoration: BoxDecoration(color: isSel ? activeColor : Colors.transparent, borderRadius: BorderRadius.circular(30)),
          child: Center(
            child: Text("${type.toUpperCase()} HUB",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isSel ? Colors.white : Colors.grey[500])),
          ),
        ),
      ),
    );
  }

  Widget _buildPetCard(Map<String, dynamic> post) {
    final bool isPending = post['isApproved'] == false;

    return Card(
      color: const Color(0xFFF8F7FF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (ctx) => PostDetailPage(post: post, type: _selectedTab))),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    child: Image.network(
                      post['photoURL'] ?? '',
                      fit: BoxFit.cover,
                      width: double.infinity,
                      color: isPending ? Colors.black.withOpacity(0.4) : null,
                      colorBlendMode: isPending ? BlendMode.darken : null,
                    )
                ),
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post['location'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1),
                      Text(post['gender'] ?? 'Male', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
            if (isPending)
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.9), borderRadius: BorderRadius.circular(20)),
                  child: const Row(
                    children: [
                      Icon(Icons.access_time, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text("Pending", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
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
          Text("Page ${_currentPage + 1} of $total"),
          IconButton(icon: const Icon(Icons.arrow_forward_ios, size: 18), onPressed: _currentPage < total - 1 ? () => setState(() => _currentPage++) : null),
        ],
      ),
    );
  }

  void _showAddForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Report Pet", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () async {
                    final p = await ImagePicker().pickImage(source: ImageSource.gallery);
                    if (p != null) setModalState(() => _imageFile = File(p.path));
                  },
                  child: Container(
                    height: 140, width: double.infinity,
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(20)),
                    child: _imageFile != null ? ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.file(_imageFile!, fit: BoxFit.cover)) : const Icon(Icons.add_a_photo, color: Colors.teal),
                  ),
                ),
                TextField(controller: _locationController, decoration: const InputDecoration(labelText: "Location")),
                TextField(controller: _contactController, decoration: const InputDecoration(labelText: "Contact Info")),
                TextField(controller: _remarkController, decoration: const InputDecoration(labelText: "Remark")),
                const SizedBox(height: 20),
                _isSaving ? const CircularProgressIndicator() : ElevatedButton(
                  onPressed: _submitPost,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
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
  String _authorName = "Reporter";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      final roleRes = await _supabase.from('users').select('role').eq('userID', user.id).maybeSingle();
      if (mounted && roleRes != null) setState(() => _isAdmin = roleRes['role'] == 'Admin');

      final userRes = await _supabase.from('users').select('userName').eq('userID', widget.post['userID']).single();
      if (mounted) setState(() => _authorName = userRes['userName']);
    } catch (e) {
      debugPrint("Data load error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isOwner = _supabase.auth.currentUser?.id == widget.post['userID'];
    final bool canModify = isOwner || _isAdmin;
    final bool isPending = widget.post['isApproved'] == false;
    final String dateStr = widget.post['uploadDate'] ?? DateTime.now().toString();
    final formattedDate = DateFormat('dd MMM yyyy').format(DateTime.parse(dateStr));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.post['location']),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (canModify) ...[
            IconButton(icon: const Icon(Icons.edit, color: Colors.teal), onPressed: () => _showEditForm(context)),
            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: _confirmDelete),
          ]
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Image.network(widget.post['photoURL'] ?? '', height: 300, width: double.infinity, fit: BoxFit.cover),
                if (isPending)
                  Container(
                    height: 300, width: double.infinity, color: Colors.black26,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(20)),
                        child: const Text("PENDING APPROVAL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.post['location'], style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () {
                      if (isOwner) return;
                      Navigator.push(context, MaterialPageRoute(
                          builder: (ctx) => ChatPage(targetUserID: widget.post['userID'], title: _authorName)
                      ));
                    },
                    child: Text(
                        "Posted by: ${isOwner ? "You" : _authorName}",
                        style: const TextStyle(fontSize: 16, color: Colors.teal, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)
                    ),
                  ),
                  Text("Posted on: $formattedDate", style: const TextStyle(color: Colors.grey)),
                  const Divider(height: 30),
                  _rowItem(Icons.location_on, "Area", widget.post['location']),
                  _rowItem(Icons.transgender, "Gender", widget.post['gender'] ?? 'Male'),
                  _rowItem(Icons.phone, "Contact", widget.post['contactInfo']),
                  const SizedBox(height: 20),
                  const Text("Remarks:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text(widget.post['remark'] ?? "No remarks.", style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 40),
                  if (!isOwner && !isPending)
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(
                          builder: (ctx) => ChatPage(targetUserID: widget.post['userID'], title: _authorName)
                      )),
                      icon: const Icon(Icons.message),
                      label: const Text("Message Reporter"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal, foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                      ),
                    ),
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
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, color: Colors.teal),
          const SizedBox(width: 10),
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  void _confirmDelete() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Delete Post"),
      content: const Text("Are you sure? This cannot be undone."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
        TextButton(onPressed: () async {
          final table = widget.type == 'Lost' ? 'lost_post' : 'found_post';
          final idKey = widget.type == 'Lost' ? 'lostPostID' : 'foundPostID';
          await _supabase.from(table).delete().eq(idKey, widget.post[idKey]);
          if (mounted) { Navigator.pop(ctx); Navigator.pop(context); }
        }, child: const Text("Delete", style: TextStyle(color: Colors.red))),
      ],
    ));
  }

  void _showEditForm(BuildContext context) {
    final loc = TextEditingController(text: widget.post['location']);
    final rem = TextEditingController(text: widget.post['remark']);
    final con = TextEditingController(text: widget.post['contactInfo']);
    String gen = widget.post['gender'] ?? 'Male';

    showModalBottomSheet(context: context, isScrollControlled: true, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setMState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("Edit Report", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          DropdownButtonFormField<String>(
              value: gen,
              items: ['Male', 'Female'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setMState(() => gen = v!)
          ),
          TextField(controller: loc, decoration: const InputDecoration(labelText: "Location")),
          TextField(controller: con, decoration: const InputDecoration(labelText: "Contact")),
          TextField(controller: rem, decoration: const InputDecoration(labelText: "Remark")),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: () async {
            final table = widget.type == 'Lost' ? 'lost_post' : 'found_post';
            final idKey = widget.type == 'Lost' ? 'lostPostID' : 'foundPostID';
            await _supabase.from(table).update({'location': loc.text, 'remark': rem.text, 'contactInfo': con.text, 'gender': gen}).eq(idKey, widget.post[idKey]);
            if (mounted) { Navigator.pop(ctx); Navigator.pop(context); }
          }, child: const Text("SAVE CHANGES")),
          const SizedBox(height: 30),
        ]),
      ),
    ));
  }
}