import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'chat.dart'; // Ensure this is imported to access ChatPage

class PetAdoptionPage extends StatefulWidget {
  const PetAdoptionPage({super.key});

  @override
  State<PetAdoptionPage> createState() => _PetAdoptionPageState();
}

class _PetAdoptionPageState extends State<PetAdoptionPage> {
  final _supabase = Supabase.instance.client;
  bool _isSaving = false;
  File? _imageFile;
  String _userRole = 'User';
  final Set<String> _locallyDeletedIds = {};

  final _petNameController = TextEditingController();
  final _breedController = TextEditingController();
  final _ageController = TextEditingController();
  final _remarkController = TextEditingController();
  // --- 新增：疫苗详细资料控制器 ---
  final _vaccineBrandController = TextEditingController();
  final _vaccineDateController = TextEditingController();
  final _nextDoseController = TextEditingController();
  bool _vaccinated = false;

  // --- Filter State ---
  String _ageFilter = 'All';
  bool? _vaccinatedFilter;

  // --- Pagination State ---
  int _currentPage = 0;
  final int _itemsPerPage = 6;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        final data = await _supabase.from('users').select('role').eq('userID', user.id).single();
        if (mounted) setState(() => _userRole = data['role'] ?? 'User');
      } catch (e) {
        debugPrint("Role check error: $e");
      }
    }
  }

  void _resetFilters() {
    setState(() {
      _ageFilter = 'All';
      _vaccinatedFilter = null;
      _currentPage = 0;
    });
  }

  Future<String> _generateAdoptionID() async {
    final response = await _supabase.from('adoption_posts').select('adoptionPostID');
    final List data = response as List;
    if (data.isEmpty) return "AP00001";
    List<int> nums = data.map((i) => int.tryParse(i['adoptionPostID'].toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0).toList();
    nums.sort();
    return "AP${(nums.last + 1).toString().padLeft(5, '0')}";
  }

  Future<void> _pickImage(StateSetter setModalState) async {
    final XFile? pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile != null) {
      setModalState(() => _imageFile = File(pickedFile.path));
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  Future<void> _deletePost(String id) async {
    setState(() => _locallyDeletedIds.add(id));
    try {
      await _supabase.from('adoption_posts').delete().eq('adoptionPostID', id);
    } catch (e) {
      setState(() => _locallyDeletedIds.remove(id));
    }
  }

  Future<void> _submitPost({String? editId, String? existingImageUrl}) async {
    if (_petNameController.text.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final user = _supabase.auth.currentUser;
      String? imageUrl = existingImageUrl;
      if (_imageFile != null) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.png';
        await _supabase.storage.from('pet_photos').upload(fileName, _imageFile!);
        imageUrl = _supabase.storage.from('pet_photos').getPublicUrl(fileName);
      }

      final postData = {
        'petName': _petNameController.text.trim(),
        'breed': _breedController.text.trim(),
        'age': int.tryParse(_ageController.text) ?? 0,
        'vaccinated': _vaccinated,
        'remark': _remarkController.text.trim(),
        'photoURL': imageUrl,
        'isApproved': _userRole == 'Admin',
        // --- 新增：保存疫苗资料 ---
        'vaccineBrand': _vaccinated ? _vaccineBrandController.text.trim() : null,
        'lastVaccinationDate': _vaccinated ? _vaccineDateController.text : null,
        'nextDoseDate': _vaccinated ? _nextDoseController.text : null,
      };

      if (editId != null) {
        if (_userRole != 'Admin') postData['isApproved'] = false;
        await _supabase.from('adoption_posts').update(postData).eq('adoptionPostID', editId);
      } else {
        postData['adoptionPostID'] = await _generateAdoptionID();
        postData['userID'] = user!.id;
        await _supabase.from('adoption_posts').insert(postData);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _supabase.auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text("Adoption Hub")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _ageFilter,
                    decoration: const InputDecoration(labelText: 'Age Range', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                    items: ['All', 'Young (0-2)', 'Adult (3-7)', 'Senior (8+)']
                        .map((label) => DropdownMenuItem(value: label, child: Text(label, style: const TextStyle(fontSize: 12))))
                        .toList(),
                    onChanged: (val) => setState(() { _ageFilter = val!; _currentPage = 0; }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<bool?>(
                    value: _vaccinatedFilter,
                    decoration: const InputDecoration(labelText: 'Vaccinated', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: true, child: Text('Yes', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: false, child: Text('No', style: TextStyle(fontSize: 12))),
                    ],
                    onChanged: (val) => setState(() { _vaccinatedFilter = val; _currentPage = 0; }),
                  ),
                ),
                const SizedBox(width: 4),
                TextButton(
                    onPressed: _resetFilters,
                    child: const Text("Reset", style: TextStyle(color: Colors.teal))
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _supabase.from('adoption_posts').stream(primaryKey: ['adoptionPostID']),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final filteredPosts = snapshot.data!.where((post) {
                  final id = post['adoptionPostID'].toString();
                  if (_locallyDeletedIds.contains(id)) return false;

                  bool isApproved = post['isApproved'] == true;
                  bool isOwner = post['userID'] == currentUser?.id;
                  bool isAdmin = _userRole == 'Admin';
                  if (!isApproved && !isOwner && !isAdmin) return false;

                  final int age = post['age'] ?? 0;
                  bool matchesAge = true;
                  if (_ageFilter == 'Young (0-2)') matchesAge = age <= 2;
                  else if (_ageFilter == 'Adult (3-7)') matchesAge = age >= 3 && age <= 7;
                  else if (_ageFilter == 'Senior (8+)') matchesAge = age >= 8;

                  bool matchesVaccinated = _vaccinatedFilter == null || (post['vaccinated'] ?? false) == _vaccinatedFilter;

                  return matchesAge && matchesVaccinated;
                }).toList();

                int totalPosts = filteredPosts.length;
                int totalPages = (totalPosts / _itemsPerPage).ceil();
                if (_currentPage >= totalPages && totalPages > 0) _currentPage = totalPages - 1;

                int start = _currentPage * _itemsPerPage;
                int end = (start + _itemsPerPage > totalPosts) ? totalPosts : start + _itemsPerPage;

                final pagedPosts = totalPosts > 0 ? filteredPosts.sublist(start, end) : [];

                if (pagedPosts.isEmpty) return const Center(child: Text("No pets found."));

                return Column(
                  children: [
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(10),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: pagedPosts.length,
                        itemBuilder: (ctx, i) {
                          final post = pagedPosts[i];
                          return _buildGridItem(post, currentUser?.id);
                        },
                      ),
                    ),
                    if (totalPages > 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 15),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios),
                              onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                            ),
                            Text("Page ${_currentPage + 1} of $totalPages"),
                            IconButton(
                              icon: const Icon(Icons.arrow_forward_ios),
                              onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => _showForm(), child: const Icon(Icons.add)),
    );
  }

  Widget _buildGridItem(Map<String, dynamic> post, String? currentUserId) {
    bool isPending = post['isApproved'] == false;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: () async {
          try {
            final Map<String, dynamic> postData = Map<String, dynamic>.from(post);
            final userData = await _supabase.from('users').select('userName').eq('userID', post['userID']).single();
            postData['authorName'] = userData['userName'];
            postData['authorID'] = post['userID'];

            if (mounted) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => PetDetailPage(post: postData)));
            }
          } catch (e) {
            if (mounted) Navigator.push(context, MaterialPageRoute(builder: (context) => PetDetailPage(post: post)));
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  post['photoURL'] != null
                      ? Image.network(post['photoURL'], width: double.infinity, height: double.infinity, fit: BoxFit.cover)
                      : Container(color: Colors.grey[300], child: const Center(child: Icon(Icons.pets))),

                  // Pending Status Hint Overlay
                  if (isPending)
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: Colors.black45,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            "PENDING APPROVAL",
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post['petName'], style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text("${post['breed']} • ${post['age']}y", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(Icons.health_and_safety, color: post['vaccinated'] == true ? Colors.teal : Colors.grey, size: 16),
                      if (post['userID'] == currentUserId || _userRole == 'Admin')
                        Row(
                          children: [
                            GestureDetector(onTap: () => _showForm(editPost: post), child: const Icon(Icons.edit, size: 16, color: Colors.blue)),
                            const SizedBox(width: 6),
                            GestureDetector(onTap: () => _deletePost(post['adoptionPostID']), child: const Icon(Icons.delete, size: 16, color: Colors.red)),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showForm({Map<String, dynamic>? editPost}) {
    if (editPost != null) {
      _petNameController.text = editPost['petName'];
      _breedController.text = editPost['breed'] ?? "";
      _ageController.text = editPost['age'].toString();
      _remarkController.text = editPost['remark'] ?? "";
      _vaccinated = editPost['vaccinated'] ?? false;
      // --- 初始化疫苗字段 ---
      _vaccineBrandController.text = editPost['vaccineBrand'] ?? "";
      _vaccineDateController.text = editPost['lastVaccinationDate'] ?? "";
      _nextDoseController.text = editPost['nextDoseDate'] ?? "";
    } else {
      _petNameController.clear(); _breedController.clear(); _ageController.clear(); _remarkController.clear();
      _vaccineBrandController.clear(); _vaccineDateController.clear(); _nextDoseController.clear();
      _vaccinated = false; _imageFile = null;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Add Pet Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                GestureDetector(
                  onTap: () => _pickImage(setModalState),
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)),
                    child: _imageFile != null
                        ? Image.file(_imageFile!, fit: BoxFit.cover)
                        : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [Icon(Icons.camera_alt, size: 40), Text("Upload Pet Photo")],
                    ),
                  ),
                ),
                TextField(controller: _petNameController, decoration: const InputDecoration(labelText: "Pet Name")),
                TextField(controller: _breedController, decoration: const InputDecoration(labelText: "Breed")),
                TextField(controller: _ageController, decoration: const InputDecoration(labelText: "Age"), keyboardType: TextInputType.number),
                TextField(controller: _remarkController, decoration: const InputDecoration(labelText: "Remarks")),
                CheckboxListTile(
                    title: const Text("Vaccinated?"),
                    value: _vaccinated,
                    onChanged: (v) => setModalState(() => _vaccinated = v!)
                ),

                // --- 动态显示疫苗详情 ---
                if (_vaccinated) ...[
                  const Divider(),
                  TextField(
                      controller: _vaccineBrandController,
                      decoration: const InputDecoration(labelText: "Vaccine Brand", prefixIcon: Icon(Icons.medication))
                  ),
                  TextField(
                    controller: _vaccineDateController,
                    readOnly: true,
                    decoration: const InputDecoration(labelText: "Last Vaccination Date", prefixIcon: Icon(Icons.calendar_today)),
                    onTap: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setModalState(() => _vaccineDateController.text = DateFormat('yyyy-MM-dd').format(picked));
                    },
                  ),
                  TextField(
                    controller: _nextDoseController,
                    readOnly: true,
                    decoration: const InputDecoration(labelText: "Next Dose Due Date", prefixIcon: Icon(Icons.event_repeat)),
                    onTap: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setModalState(() => _nextDoseController.text = DateFormat('yyyy-MM-dd').format(picked));
                    },
                  ),
                ],

                const SizedBox(height: 20),
                _isSaving ? const CircularProgressIndicator() : SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _submitPost(editId: editPost?['adoptionPostID'], existingImageUrl: editPost?['photoURL']),
                    child: const Text("Submit Post"),
                  ),
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

class PetDetailPage extends StatelessWidget {
  final Map<String, dynamic> post;
  const PetDetailPage({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final dateStr = post['uploadDate'] ?? DateTime.now().toString();
    final formattedDate = DateFormat('dd MMM yyyy').format(DateTime.parse(dateStr));
    final authorName = post['authorName'] ?? "Unknown User";
    final authorID = post['authorID'];
    final currentUserID = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(title: Text(post['petName'])),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post['photoURL'] != null)
              Hero(tag: post['adoptionPostID'], child: Image.network(post['photoURL'], width: double.infinity, height: 300, fit: BoxFit.cover))
            else
              Container(height: 300, color: Colors.grey[300], child: const Icon(Icons.pets, size: 100)),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post['petName'], style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),

                  GestureDetector(
                    onTap: () {
                      if (authorID == null || authorID == currentUserID) return;
                      Navigator.push(context, MaterialPageRoute(builder: (context) => ChatPage(targetUserID: authorID, title: authorName)));
                    },
                    child: Text(
                        "Posted by: $authorName",
                        style: const TextStyle(fontSize: 16, color: Colors.teal, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)
                    ),
                  ),

                  Text("Posted on: $formattedDate", style: const TextStyle(color: Colors.grey)),
                  const Divider(height: 30),
                  _rowItem(Icons.pets, "Breed", post['breed'] ?? "Unknown"),
                  _rowItem(Icons.cake, "Age", "${post['age']} years"),
                  _rowItem(Icons.verified_user, "Vaccinated", post['vaccinated'] == true ? "Yes" : "No"),

                  // --- 新增：展示详细疫苗信息 ---
                  if (post['vaccinated'] == true) ...[
                    if (post['vaccineBrand'] != null && post['vaccineBrand'].toString().isNotEmpty)
                      _rowItem(Icons.medication, "Brand", post['vaccineBrand']),
                    if (post['lastVaccinationDate'] != null)
                      _rowItem(Icons.calendar_today, "Last Dose", post['lastVaccinationDate']),
                    if (post['nextDoseDate'] != null)
                      _rowItem(Icons.event_repeat, "Next Due", post['nextDoseDate']),
                  ],

                  const SizedBox(height: 20),
                  const Text("Remarks:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text(post['remark'] ?? "No remarks.", style: const TextStyle(fontSize: 16)),
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
}