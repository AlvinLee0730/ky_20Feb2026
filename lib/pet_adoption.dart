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
  String _userRole = 'User';
  final Set<String> _locallyDeletedIds = {};

  final _petNameController = TextEditingController();
  final _breedController = TextEditingController();
  final _dobController = TextEditingController();
  final _remarkController = TextEditingController();

  // --- 疫苗详细资料控制器 ---
  final _vaccineBrandController = TextEditingController();
  final _vaccineDateController = TextEditingController();
  final _nextDoseController = TextEditingController();
  final _vaccineRemarkController = TextEditingController();
  bool _vaccinated = false;

  // --- 多图上传状态 ---
  List<File> _newImageFiles = [];

  // --- 搜索与过滤状态 ---
  final _searchController = TextEditingController();
  String _searchQuery = "";
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

  @override
  void dispose() {
    _petNameController.dispose();
    _breedController.dispose();
    _dobController.dispose();
    _remarkController.dispose();
    _vaccineBrandController.dispose();
    _vaccineDateController.dispose();
    _nextDoseController.dispose();
    _vaccineRemarkController.dispose();
    _searchController.dispose();
    super.dispose();
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

  Future<String> _generateAdoptionID() async {
    final response = await _supabase.from('adoption_posts').select('adoptionPostID');
    final List data = response as List;
    if (data.isEmpty) return "AP00001";
    List<int> nums = data.map((i) => int.tryParse(i['adoptionPostID'].toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0).toList();
    nums.sort();
    return "AP${(nums.last + 1).toString().padLeft(5, '0')}";
  }

  // --- 多图选择逻辑 ---
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

  Future<void> _deletePost(String id) async {
    setState(() => _locallyDeletedIds.add(id));
    try {
      await _supabase.from('adoption_posts').delete().eq('adoptionPostID', id);
    } catch (e) {
      setState(() => _locallyDeletedIds.remove(id));
    }
  }

  Future<void> _submitPost({String? editId, String? existingImageUrl}) async {
    if (_petNameController.text.isEmpty) {
      _showError("Please enter the pet's name."); return;
    }
    if (_newImageFiles.isEmpty && existingImageUrl == null) {
      _showError("Please select at least one photo."); return;
    }

    // 🌟 修改：自动计算年龄，如果是 Unknown 则默认为 0，防止报错
    int calculatedAge = 0;
    if (_dobController.text.isNotEmpty && _dobController.text != 'Unknown') {
      try {
        DateTime dob = DateTime.parse(_dobController.text);
        DateTime now = DateTime.now();
        calculatedAge = now.year - dob.year;
        if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
          calculatedAge--;
        }
        if (calculatedAge < 0) calculatedAge = 0;
      } catch (e) {
        debugPrint("DOB Parse error: $e");
      }
    }

    setState(() => _isSaving = true);
    try {
      final user = _supabase.auth.currentUser;
      String? imageUrlsStr = existingImageUrl;

      // 上传所有新图片
      if (_newImageFiles.isNotEmpty) {
        List<String> finalUrls = existingImageUrl != null && existingImageUrl.isNotEmpty
            ? existingImageUrl.split(',').where((e) => e.isNotEmpty).toList()
            : [];

        for (int i = 0; i < _newImageFiles.length; i++) {
          final file = _newImageFiles[i];
          final fileName = 'pa_${DateTime.now().millisecondsSinceEpoch}_$i.png';
          await _supabase.storage.from('pet_photos').upload(fileName, file);
          finalUrls.add(_supabase.storage.from('pet_photos').getPublicUrl(fileName));
        }
        imageUrlsStr = finalUrls.join(',');
      }

      final postData = {
        'petName': _petNameController.text.trim(),
        'breed': _breedController.text.trim(),
        'dateOfBirth': _dobController.text.trim(),
        'age': calculatedAge,
        'vaccinated': _vaccinated,
        'remark': _remarkController.text.trim(),
        'photoURL': imageUrlsStr,
        'isApproved': _userRole == 'Admin',
        'vaccineBrand': _vaccinated ? _vaccineBrandController.text.trim() : null,
        'lastVaccinationDate': _vaccinated ? _vaccineDateController.text : null,
        'nextDoseDate': _vaccinated ? _nextDoseController.text : null,
        'vaccineRemark': _vaccinated ? _vaccineRemarkController.text.trim() : null,
      };

      if (editId != null) {
        if (_userRole != 'Admin') postData['isApproved'] = false;
        await _supabase.from('adoption_posts').update(postData).eq('adoptionPostID', editId);
      } else {
        postData['adoptionPostID'] = await _generateAdoptionID();
        postData['userID'] = user!.id;
        await _supabase.from('adoption_posts').insert(postData);
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Submitted successfully!"), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- 筛选弹窗 ---
  void _showFilterModal() {
    String tempAge = _ageFilter;
    bool? tempVaccinated = _vaccinatedFilter;

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
                        tempAge = 'All';
                        tempVaccinated = null;
                      });
                    },
                    child: const Text("Reset", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
              const SizedBox(height: 15),

              DropdownButtonFormField<String>(
                value: tempAge,
                decoration: InputDecoration(
                  labelText: "Age Range",
                  prefixIcon: const Icon(Icons.hourglass_bottom, color: Colors.teal),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
                items: ['All', 'Young (0-2)', 'Adult (3-7)', 'Senior (8+)'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setModalState(() => tempAge = v!),
              ),
              const SizedBox(height: 15),

              DropdownButtonFormField<bool?>(
                value: tempVaccinated,
                decoration: InputDecoration(
                  labelText: "Vaccinated",
                  prefixIcon: const Icon(Icons.health_and_safety, color: Colors.teal),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All')),
                  DropdownMenuItem(value: true, child: Text('Yes')),
                  DropdownMenuItem(value: false, child: Text('No')),
                ],
                onChanged: (v) => setModalState(() => tempVaccinated = v),
              ),
              const SizedBox(height: 25),

              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _ageFilter = tempAge;
                    _vaccinatedFilter = tempVaccinated;
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
    final currentUser = _supabase.auth.currentUser;
    final bool hasActiveFilter = _ageFilter != 'All' || _vaccinatedFilter != null;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Pet Adoption", style: TextStyle(fontWeight: FontWeight.bold)),
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
                      hintText: "Search name or breed...",
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
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _supabase.from('adoption_posts').stream(primaryKey: ['adoptionPostID']).order('uploadDate', ascending: false),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final filteredPosts = snapshot.data!.where((post) {
            final id = post['adoptionPostID'].toString();
            if (_locallyDeletedIds.contains(id)) return false;

            bool isApproved = post['isApproved'] == true;
            bool isOwner = post['userID'] == currentUser?.id;
            bool isAdmin = _userRole == 'Admin';
            if (!isApproved && !isOwner && !isAdmin) return false;

            // Search logic
            final String name = (post['petName'] ?? "").toString().toLowerCase();
            final String breed = (post['breed'] ?? "").toString().toLowerCase();
            if (_searchQuery.isNotEmpty && !name.contains(_searchQuery) && !breed.contains(_searchQuery)) {
              return false;
            }

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
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: pagedPosts.length,
                  itemBuilder: (ctx, i) {
                    final post = pagedPosts[i];
                    return _buildGridItem(post, currentUser?.id);
                  },
                ),
              ),
              _buildPagination(totalPages == 0 ? 1 : totalPages),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: () => _showForm(),
          backgroundColor: Colors.teal,
          child: const Icon(Icons.add, color: Colors.white, size: 30)
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

  Widget _buildGridItem(Map<String, dynamic> post, String? currentUserId) {
    bool isPending = post['isApproved'] == false;

    String? firstImageUrl;
    if (post['photoURL'] != null && post['photoURL'].toString().isNotEmpty) {
      firstImageUrl = post['photoURL'].toString().split(',').first;
    }

    // 🌟 修改：动态判断如果 Date of Birth 是 Unknown，则列表页显示 Unknown age
    String ageDisplay = post['dateOfBirth'] == 'Unknown' ? 'Unknown age' : '${post['age']}y';

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => PetDetailPage(post: post)));
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  firstImageUrl != null
                      ? Image.network(firstImageUrl, width: double.infinity, height: double.infinity, fit: BoxFit.cover)
                      : Container(color: Colors.grey[200], child: const Center(child: Icon(Icons.pets, color: Colors.grey))),

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
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post['petName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text("${post['breed']} • $ageDisplay", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(Icons.health_and_safety, color: post['vaccinated'] == true ? Colors.teal : Colors.grey, size: 16),
                      if (post['userID'] == currentUserId || _userRole == 'Admin')
                        Row(
                          children: [
                            GestureDetector(onTap: () => _showForm(editPost: post), child: const Icon(Icons.edit, size: 16, color: Colors.teal)),
                            const SizedBox(width: 8),
                            GestureDetector(onTap: () => _deletePost(post['adoptionPostID']), child: const Icon(Icons.delete, size: 16, color: Colors.redAccent)),
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
      _petNameController.text = editPost['petName'] ?? "";
      _breedController.text = editPost['breed'] ?? "";
      _dobController.text = editPost['dateOfBirth'] ?? "";
      _remarkController.text = editPost['remark'] ?? "";
      _vaccinated = editPost['vaccinated'] ?? false;
      _vaccineBrandController.text = editPost['vaccineBrand'] ?? "";
      _vaccineDateController.text = editPost['lastVaccinationDate'] ?? "";
      _nextDoseController.text = editPost['nextDoseDate'] ?? "";
      _vaccineRemarkController.text = editPost['vaccineRemark'] ?? "";
    } else {
      _petNameController.clear(); _breedController.clear(); _dobController.clear(); _remarkController.clear();
      _vaccineBrandController.clear(); _vaccineDateController.clear(); _nextDoseController.clear(); _vaccineRemarkController.clear();
      _vaccinated = false;
    }
    _newImageFiles = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          // 🌟 追踪 DOB 是否为 Unknown
          bool isDobUnknown = _dobController.text == 'Unknown';

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(child: Text("Pet Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                  const SizedBox(height: 20),

                  if (_newImageFiles.isEmpty && (editPost == null || editPost['photoURL'] == null || editPost['photoURL'].toString().isEmpty))
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
                          if (editPost != null && editPost['photoURL'] != null && editPost['photoURL'].toString().isNotEmpty && _newImageFiles.isEmpty)
                            ...editPost['photoURL'].toString().split(',').where((e) => e.isNotEmpty).map((url) => Container(
                              margin: const EdgeInsets.only(right: 10),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(url, width: 100, height: 100, fit: BoxFit.cover),
                              ),
                            )),
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

                  TextField(controller: _petNameController, decoration: const InputDecoration(labelText: "Pet Name")),
                  TextField(controller: _breedController, decoration: const InputDecoration(labelText: "Breed")),

                  // 🌟 修改：支持输入 Date of Birth 或者 选择 Unknown
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _dobController,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: "Date of Birth",
                            prefixIcon: const Icon(Icons.calendar_today),
                            filled: isDobUnknown,
                            fillColor: isDobUnknown ? Colors.grey.shade200 : null,
                          ),
                          onTap: () async {
                            if (isDobUnknown) return; // 勾选 Unknown 后不可选择日期
                            DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                              builder: (context, child) => Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(primary: Colors.teal, onPrimary: Colors.white, onSurface: Colors.black),
                                ),
                                child: child!,
                              ),
                            );
                            if (picked != null) {
                              setModalState(() => _dobController.text = DateFormat('yyyy-MM-dd').format(picked));
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: isDobUnknown,
                            activeColor: Colors.teal,
                            onChanged: (val) {
                              setModalState(() {
                                isDobUnknown = val ?? false;
                                if (isDobUnknown) {
                                  _dobController.text = 'Unknown';
                                } else {
                                  _dobController.clear();
                                }
                              });
                            },
                          ),
                          const Text("Unknown", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),

                  TextField(controller: _remarkController, decoration: const InputDecoration(labelText: "Remarks")),
                  CheckboxListTile(
                      title: const Text("Vaccinated?", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                      value: _vaccinated,
                      activeColor: Colors.teal,
                      onChanged: (v) => setModalState(() => _vaccinated = v!)
                  ),

                  if (_vaccinated) ...[
                    const Divider(),
                    TextField(
                        controller: _vaccineBrandController,
                        decoration: const InputDecoration(labelText: "Vaccine Brand", prefixIcon: Icon(Icons.medication, color: Colors.teal))
                    ),
                    TextField(
                      controller: _vaccineDateController,
                      readOnly: true,
                      decoration: const InputDecoration(labelText: "Last Vaccination Date", prefixIcon: Icon(Icons.calendar_today, color: Colors.teal)),
                      onTap: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Colors.teal)), child: child!),
                        );
                        if (picked != null) setModalState(() => _vaccineDateController.text = DateFormat('yyyy-MM-dd').format(picked));
                      },
                    ),
                    TextField(
                      controller: _nextDoseController,
                      readOnly: true,
                      decoration: const InputDecoration(labelText: "Next Dose Due Date", prefixIcon: Icon(Icons.event_repeat, color: Colors.teal)),
                      onTap: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2030),
                          builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Colors.teal)), child: child!),
                        );
                        if (picked != null) setModalState(() => _nextDoseController.text = DateFormat('yyyy-MM-dd').format(picked));
                      },
                    ),
                    TextField(
                      controller: _vaccineRemarkController,
                      decoration: const InputDecoration(labelText: "Vaccination Remarks (Optional)", prefixIcon: Icon(Icons.note_alt_outlined, color: Colors.teal)),
                    ),
                  ],

                  const SizedBox(height: 25),
                  _isSaving ? const Center(child: CircularProgressIndicator(color: Colors.teal)) : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _submitPost(editId: editPost?['adoptionPostID'], existingImageUrl: editPost?['photoURL']),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                      ),
                      child: const Text("SUBMIT POST", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class PetDetailPage extends StatefulWidget {
  final Map<String, dynamic> post;
  const PetDetailPage({super.key, required this.post});

  @override
  State<PetDetailPage> createState() => _PetDetailPageState();
}

class _PetDetailPageState extends State<PetDetailPage> {
  final _supabase = Supabase.instance.client;
  String _authorName = "Unknown User";
  String? _authorPhoto;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadAuthorData();
  }

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

  void _goToChat(String? targetId, String targetName) {
    final myId = _supabase.auth.currentUser?.id;
    if (targetId == null) return;
    if (targetId == myId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You cannot start a chat with yourself.")));
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(targetUserID: targetId, title: targetName)));
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = widget.post['uploadDate'] ?? DateTime.now().toString();
    final formattedDate = DateFormat('dd MMM yyyy').format(DateTime.parse(dateStr));

    List<String> imageUrls = [];
    if (widget.post['photoURL'] != null && widget.post['photoURL'].toString().isNotEmpty) {
      imageUrls = widget.post['photoURL'].toString().split(',').where((e) => e.isNotEmpty).toList();
    }

    // 🌟 详情页动态判断 Age
    String ageDisplay = widget.post['dateOfBirth'] == 'Unknown' ? 'Unknown' : "${widget.post['age']} years";

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(widget.post['petName']),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
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
              )
            else
              Container(height: 300, color: Colors.grey[300], child: const Center(child: Icon(Icons.pets, size: 100, color: Colors.grey))),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.post['petName'], style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),

                  // Clickable Uploaded By
                  InkWell(
                    onTap: () {
                      final targetId = widget.post['userID'];
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

                  const SizedBox(height: 4),
                  Text("Posted on: $formattedDate", style: const TextStyle(color: Colors.grey)),

                  const Divider(height: 30),
                  _rowItem(Icons.pets, "Breed", widget.post['breed'] ?? "Unknown"),
                  if (widget.post['dateOfBirth'] != null)
                    _rowItem(Icons.calendar_today, "Date of Birth", widget.post['dateOfBirth']),

                  // 🌟 替换掉原本直接写死的 age
                  _rowItem(Icons.hourglass_bottom, "Age", ageDisplay),
                  _rowItem(Icons.health_and_safety, "Vaccinated", widget.post['vaccinated'] == true ? "Yes" : "No"),

                  if (widget.post['vaccinated'] == true) ...[
                    if (widget.post['vaccineBrand'] != null && widget.post['vaccineBrand'].toString().isNotEmpty)
                      _rowItem(Icons.medication, "Brand", widget.post['vaccineBrand']),
                    if (widget.post['lastVaccinationDate'] != null)
                      _rowItem(Icons.calendar_month, "Last Dose", widget.post['lastVaccinationDate']),
                    if (widget.post['nextDoseDate'] != null)
                      _rowItem(Icons.event_repeat, "Next Due", widget.post['nextDoseDate']),
                    if (widget.post['vaccineRemark'] != null && widget.post['vaccineRemark'].toString().isNotEmpty)
                      _rowItem(Icons.note_alt, "Vaccine Remarks", widget.post['vaccineRemark']),
                  ],

                  const SizedBox(height: 20),
                  const Text("Remarks:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
                  const SizedBox(height: 5),
                  Text(widget.post['remark'] ?? "No remarks.", style: const TextStyle(fontSize: 16)),
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
      child: Row(
        children: [
          Icon(icon, color: Colors.teal, size: 20),
          const SizedBox(width: 12),
          Text("$label: ", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}